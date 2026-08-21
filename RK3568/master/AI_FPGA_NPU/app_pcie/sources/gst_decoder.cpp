/**
 * @file gst_decoder.cpp
 * @brief GStreamer 硬解桥接 — RK3568 MPP (mppvideodec) H.264 硬件解码
 *
 * SD 卡视频播放路径: 取代 OpenCV 后端 (FFmpeg 软解 + GStreamer 封装) 的
 * 逐帧解码/转换开销, 用 GStreamer appsink pull 模型直接输出 NV12 裸帧,
 * 再由 RGA 硬件完成 NV12→BGR 转换与缩放 (板端实测 appsink pull ≈ 344 fps)。
 *
 * 管线: filesrc ! qtdemux ! h264parse ! mppvideodec ! appsink
 *
 * Python (ctypes) 调用接口:
 *   gst_dec_open(path, &w, &h, &fps, &total, &stride) → 句柄 (>0 成功, 0 失败)
 *   gst_dec_pull_dmabuf(handle, &fd, &size, timeout_ms)
 *       → 0 帧就绪 (fd 为 MPP 输出 dma-buf, 供 RGA 零拷贝转换,
 *          fd 有效至下一次 pull/close); -1 超时无帧; -2 EOS;
 *         -3 错误; -4 非 dma-buf (罕见, 帧留在 pending, 改走 gst_dec_pull)
 *   gst_dec_pull(handle, dst, max_bytes, timeout_ms)   → memcpy 兜底路径
 *       → >0 已拷贝帧字节数; -1 超时无帧; -2 EOS; -3 错误
 *   gst_dec_close(handle)
 *
 * 注意: MPP 输出 dma-buf 为无缓存 DRM 内存, CPU 直接 memcpy 仅 ~160MB/s
 *       (1080p 单帧约 19ms, 全管线 ~45fps); 正确路径是 RGA 硬件经 fd 直接
 *       读取 dma-buf 转换 (板端实测 5.7ms/帧, ~176fps), 勿在热路径 memcpy。
 *       MPP 输出 stride 可能 16 字节对齐 (如宽度 1080 → stride 1088),
 *       由 gst_dec_open 通过 GstVideoMeta 读出并返回。
 */

#include <gst/gst.h>
#include <gst/app/gstappsink.h>
#include <gst/video/video.h>
#include <gst/allocators/gstdmabuf.h>

#include <cstdio>
#include <cstring>
#include <cstdint>

#define GST_DEC_MAX 8

struct GstDecCtx {
    GstElement* pipeline = nullptr;
    GstElement* appsink  = nullptr;
    int width   = 0;
    int height  = 0;
    int stride  = 0;
    double fps  = 0.0;
    int total_frames = 0;
    GstSample* pending = nullptr;   // open 时 preroll 出的第一帧, 留给首次 pull
    GstSample* current = nullptr;   // 当前已交付帧 (持有其 dma-buf fd 生命周期)
};

static GstDecCtx g_ctx[GST_DEC_MAX];
static bool g_gst_ready = false;

/* qtdemux 动态 pad: 只链接视频流 (跳过音频流) */
static void on_pad_added(GstElement* demux, GstPad* pad, gpointer user_data) {
    (void)demux;
    GstElement* parse = (GstElement*)user_data;
    GstCaps* caps = gst_pad_get_current_caps(pad);
    if (!caps) caps = gst_pad_query_caps(pad, nullptr);
    if (!caps) return;
    GstStructure* st = gst_caps_get_structure(caps, 0);
    const gchar* name = gst_structure_get_name(st);
    if (name && g_str_has_prefix(name, "video/")) {
        GstPad* sinkpad = gst_element_get_static_pad(parse, "sink");
        if (sinkpad) {
            if (!gst_pad_is_linked(sinkpad)) gst_pad_link(pad, sinkpad);
            gst_object_unref(sinkpad);
        }
    }
    gst_caps_unref(caps);
}

/* 巡检总线: 返回 0 正常, -1 致命错误 (EOS 消息只消费, 由 appsink is_eos 判定) */
static int drain_bus(GstDecCtx* ctx) {
    GstBus* bus = gst_element_get_bus(ctx->pipeline);
    if (!bus) return 0;
    GstMessage* msg;
    while ((msg = gst_bus_pop_filtered(bus,
            (GstMessageType)(GST_MESSAGE_ERROR | GST_MESSAGE_EOS)))) {
        int is_err = (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR);
        if (is_err) {
            gst_message_unref(msg);
            gst_object_unref(bus);
            return -1;
        }
        gst_message_unref(msg);
    }
    gst_object_unref(bus);
    return 0;
}

extern "C" int gst_dec_open(const char* path, int* width, int* height,
                            double* fps, int* total_frames, int* stride) {
    if (!path || !path[0]) return 0;

    if (!g_gst_ready) {
        GError* err = nullptr;
        if (!gst_init_check(nullptr, nullptr, &err)) {
            if (err) g_error_free(err);
            return 0;
        }
        g_gst_ready = true;
    }

    int slot = -1;
    for (int i = 0; i < GST_DEC_MAX; i++) {
        if (g_ctx[i].pipeline == nullptr) { slot = i; break; }
    }
    if (slot < 0) return 0;
    GstDecCtx* ctx = &g_ctx[slot];

    GstElement* src   = gst_element_factory_make("filesrc", "src");
    GstElement* demux = gst_element_factory_make("qtdemux", "demux");
    GstElement* parse = gst_element_factory_make("h264parse", "parse");
    GstElement* dec   = gst_element_factory_make("mppvideodec", "dec");
    GstElement* sink  = gst_element_factory_make("appsink", "sink");
    if (!src || !demux || !parse || !dec || !sink) {
        if (src)   gst_object_unref(src);
        if (demux) gst_object_unref(demux);
        if (parse) gst_object_unref(parse);
        if (dec)   gst_object_unref(dec);
        if (sink)  gst_object_unref(sink);
        return 0;
    }

    ctx->pipeline = gst_pipeline_new("gst-dec-pipeline");
    if (!ctx->pipeline) {
        gst_object_unref(src); gst_object_unref(demux); gst_object_unref(parse);
        gst_object_unref(dec); gst_object_unref(sink);
        return 0;
    }

    g_object_set(G_OBJECT(src), "location", path, nullptr);
    GstCaps* caps = gst_caps_from_string("video/x-raw,format=NV12");
    g_object_set(G_OBJECT(sink), "sync", FALSE, "max-buffers", 2, "caps", caps, nullptr);
    gst_caps_unref(caps);

    gst_bin_add_many(GST_BIN(ctx->pipeline), src, demux, parse, dec, sink, nullptr);
    if (!gst_element_link(src, demux) ||
        !gst_element_link_many(parse, dec, sink, nullptr)) {
        gst_element_set_state(ctx->pipeline, GST_STATE_NULL);
        gst_object_unref(ctx->pipeline);
        memset(ctx, 0, sizeof(GstDecCtx));
        return 0;
    }
    g_signal_connect(demux, "pad-added", G_CALLBACK(on_pad_added), parse);
    ctx->appsink = sink;

    if (gst_element_set_state(ctx->pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        gst_element_set_state(ctx->pipeline, GST_STATE_NULL);
        gst_object_unref(ctx->pipeline);
        memset(ctx, 0, sizeof(GstDecCtx));
        return 0;
    }

    /* 阻塞等待 preroll 首帧 (3s), 期间解析宽高/帧率/stride 与总帧数 */
    GstSample* sample = gst_app_sink_try_pull_sample(GST_APP_SINK(sink), 3 * GST_SECOND);
    if (!sample) {
        gst_element_set_state(ctx->pipeline, GST_STATE_NULL);
        gst_object_unref(ctx->pipeline);
        memset(ctx, 0, sizeof(GstDecCtx));
        return 0;
    }

    GstCaps* scaps = gst_sample_get_caps(sample);
    if (scaps) {
        GstStructure* st = gst_caps_get_structure(scaps, 0);
        int w = 0, h = 0, fnum = 0, fden = 1;
        gst_structure_get_int(st, "width", &w);
        gst_structure_get_int(st, "height", &h);
        gst_structure_get_fraction(st, "framerate", &fnum, &fden);
        ctx->width  = w;
        ctx->height = h;
        ctx->fps    = (fden > 0) ? (double)fnum / (double)fden : 0.0;
    }
    if (ctx->width <= 0 || ctx->height <= 0) {
        gst_sample_unref(sample);
        gst_element_set_state(ctx->pipeline, GST_STATE_NULL);
        gst_object_unref(ctx->pipeline);
        memset(ctx, 0, sizeof(GstDecCtx));
        return 0;
    }

    /* MPP NV12 输出 stride 可能 16 对齐 (如 1080→1088), 从 VideoMeta 读取 */
    ctx->stride = ctx->width;
    GstBuffer* buf = gst_sample_get_buffer(sample);
    GstVideoMeta* vmeta = gst_buffer_get_video_meta(buf);
    if (vmeta && vmeta->n_planes > 0 && vmeta->stride[0] > 0) {
        ctx->stride = vmeta->stride[0];
    }

    /* preroll 后 qtdemux 可查询总时长 → 总帧数 */
    gint64 dur = GST_CLOCK_TIME_NONE;
    if (gst_element_query_duration(ctx->pipeline, GST_FORMAT_TIME, &dur) &&
        dur > 0 && ctx->fps > 0) {
        ctx->total_frames = (int)((double)dur / 1e9 * ctx->fps + 0.5);
    }

    ctx->pending = sample;   // 首帧留给首次 pull

    if (width)       *width  = ctx->width;
    if (height)      *height = ctx->height;
    if (fps)         *fps    = ctx->fps;
    if (total_frames)*total_frames = ctx->total_frames;
    if (stride)      *stride = ctx->stride;
    return slot + 1;
}

/* 零拷贝热路径: 返回 MPP 输出 dma-buf fd 供 RGA 硬件直接转换。
 * fd 由 current sample 持有, 有效至下一次 pull 或 close。 */
extern "C" int gst_dec_pull_dmabuf(int handle, int* fd_out, int* size_out, int timeout_ms) {
    if (handle < 1 || handle > GST_DEC_MAX) return -3;
    GstDecCtx* ctx = &g_ctx[handle - 1];
    if (!ctx->pipeline || !ctx->appsink) return -3;

    if (drain_bus(ctx) < 0) return -3;

    GstSample* sample = ctx->pending;
    ctx->pending = nullptr;
    if (!sample) {
        sample = gst_app_sink_try_pull_sample(GST_APP_SINK(ctx->appsink),
                                              (GstClockTime)timeout_ms * 1000000LL);
    }
    if (!sample) {
        if (gst_app_sink_is_eos(GST_APP_SINK(ctx->appsink))) return -2;
        if (drain_bus(ctx) < 0) return -3;
        return -1;
    }

    GstBuffer* buf = gst_sample_get_buffer(sample);
    GstMemory* mem = gst_buffer_peek_memory(buf, 0);
    if (!gst_is_dmabuf_memory(mem)) {
        ctx->pending = sample;   // 非 dma-buf: 帧放回, 由 gst_dec_pull memcpy 路径处理
        return -4;
    }

    if (ctx->current) gst_sample_unref(ctx->current);
    ctx->current = sample;
    if (fd_out)   *fd_out   = gst_dmabuf_memory_get_fd(mem);
    if (size_out) *size_out = (int)gst_buffer_get_size(buf);
    return 0;
}

extern "C" int gst_dec_pull(int handle, uint8_t* dst, int max_bytes, int timeout_ms) {
    if (handle < 1 || handle > GST_DEC_MAX || !dst || max_bytes <= 0) return -3;
    GstDecCtx* ctx = &g_ctx[handle - 1];
    if (!ctx->pipeline || !ctx->appsink) return -3;

    if (drain_bus(ctx) < 0) return -3;

    GstSample* sample = ctx->pending;
    ctx->pending = nullptr;
    if (!sample) {
        sample = gst_app_sink_try_pull_sample(GST_APP_SINK(ctx->appsink),
                                              (GstClockTime)timeout_ms * 1000000LL);
    }
    if (!sample) {
        if (gst_app_sink_is_eos(GST_APP_SINK(ctx->appsink))) return -2;
        if (drain_bus(ctx) < 0) return -3;
        return -1;
    }

    GstBuffer* buf = gst_sample_get_buffer(sample);
    GstMapInfo map;
    int n = -3;
    if (gst_buffer_map(buf, &map, GST_MAP_READ)) {
        n = (int)((map.size < (gsize)max_bytes) ? map.size : (gsize)max_bytes);
        memcpy(dst, map.data, n);
        gst_buffer_unmap(buf, &map);
    }
    gst_sample_unref(sample);
    return n;
}

extern "C" void gst_dec_close(int handle) {
    if (handle < 1 || handle > GST_DEC_MAX) return;
    GstDecCtx* ctx = &g_ctx[handle - 1];
    if (ctx->pending) { gst_sample_unref(ctx->pending); ctx->pending = nullptr; }
    if (ctx->current) { gst_sample_unref(ctx->current); ctx->current = nullptr; }
    if (ctx->pipeline) {
        gst_element_set_state(ctx->pipeline, GST_STATE_NULL);
        gst_object_unref(ctx->pipeline);
    }
    memset(ctx, 0, sizeof(GstDecCtx));
}