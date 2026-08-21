/**
 * @file sd_video_decode.cpp
 * @brief SD 卡视频硬解码 (Rockchip MPP via GStreamer), 输出 NV12 帧
 *
 * 背景: OpenCV 的 GStreamer 后端每帧约 39ms 固定开销 (实测 1080p60 仅 25fps),
 *       而原生 appsink pull 实测 344fps。本模块直接在桥接库内拉流,
 *       Python 侧拿到 NV12 原始帧后由 RGA 硬件完成格式转换与缩放。
 *
 * 架构:
 *   - sd_video_open: 构建 filesrc→qtdemux→parse→mppvideodec→appsink 管线,
 *     独立线程运行 GLib main loop 分发总线消息, 阻塞等首帧并解析
 *     宽高/帧率/时长 (成功 0, 失败 -1)
 *   - sd_video_read: 从内部队列取一帧 NV12 拷入调用方缓冲
 *     (0 成功, -1 EOF/错误, -2 100ms 超时无帧 — 供上层检查停止标志)
 *   - sd_video_close: 停止管线, 解除所有阻塞
 *
 * 帧格式: NV12 (Y 平面 w×h + UV 交错平面 w×h/2), 总字节 w*h*3/2。
 * 背压: 内部队列满 (4 帧) 时流线程阻塞, 解码自动跟随消费速率。
 *
 * Python (ctypes) 调用接口:
 *   sd_video_open(path, parser, &w, &h, &fps, &duration)
 *   sd_video_read(buf, buf_size)
 *   sd_video_close()
 */

#include <gst/gst.h>
#include <gst/app/gstappsink.h>
#include <cstdio>
#include <cstring>
#include <queue>
#include <pthread.h>

// 内部帧队列上限: 消费者慢时流线程阻塞 (背压), 不丢帧
static const int MAX_QUEUE = 4;
// read 无帧等待上限 (µs): 100ms, 让 Python 循环能周期性检查停止标志
static const gint64 READ_WAIT_US = 100 * 1000;

static GstElement* s_pipeline = nullptr;
static GMainLoop*   s_loop     = nullptr;
static pthread_t    s_thread   = 0;
static bool         s_thread_started = false;

static GMutex               s_mtx;
static GCond                s_cond;
static std::queue<GstSample*> s_queue;
static bool s_eos     = false;
static bool s_closing = false;

static int s_width = 0, s_height = 0;
static int s_frame_size = 0;
static double s_fps = 0.0;
static double s_duration = -1.0;

/*
 * on_new_sample — appsink 产出新帧 (流线程上下文)
 *   pull 当前样本入队; 队列满则阻塞等待消费者 (背压)。
 */
static GstFlowReturn on_new_sample(GstAppSink* sink, gpointer) {
    GstSample* sample = gst_app_sink_pull_sample(sink);
    if (!sample) return GST_FLOW_ERROR;

    g_mutex_lock(&s_mtx);
    while ((int)s_queue.size() >= MAX_QUEUE && !s_eos && !s_closing) {
        g_cond_wait(&s_cond, &s_mtx);
    }
    if (s_closing) {
        g_mutex_unlock(&s_mtx);
        gst_sample_unref(sample);
        return GST_FLOW_FLUSHING;
    }
    s_queue.push(sample);
    g_cond_signal(&s_cond);
    g_mutex_unlock(&s_mtx);
    return GST_FLOW_OK;
}

/*
 * on_bus — 总线消息 (decode 线程的 GLib main loop 分发)
 *   EOS/ERROR 时广播唤醒 read; ERROR 时置 NULL 解除流线程阻塞。
 */
static gboolean on_bus(GstBus*, GstMessage* msg, gpointer) {
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_EOS:
            g_mutex_lock(&s_mtx);
            s_eos = true;
            g_cond_broadcast(&s_cond);
            g_mutex_unlock(&s_mtx);
            break;
        case GST_MESSAGE_ERROR: {
            GError* err = nullptr;
            gchar* dbg = nullptr;
            gst_message_parse_error(msg, &err, &dbg);
            fprintf(stderr, "[sd_video] GST ERROR: %s (%s)\n",
                    err ? err->message : "?", dbg ? dbg : "");
            if (err) g_error_free(err);
            if (dbg) g_free(dbg);
            g_mutex_lock(&s_mtx);
            s_eos = true;
            g_cond_broadcast(&s_cond);
            g_mutex_unlock(&s_mtx);
            gst_element_set_state(s_pipeline, GST_STATE_NULL);
            break;
        }
        default:
            break;
    }
    return TRUE;
}

static void* decode_loop_func(void*) {
    GMainContext* ctx = g_main_loop_get_context(s_loop);
    g_main_context_push_thread_default(ctx);
    GstBus* bus = gst_pipeline_get_bus(GST_PIPELINE(s_pipeline));
    gst_bus_add_watch(bus, on_bus, nullptr);
    gst_object_unref(bus);
    g_main_loop_run(s_loop);
    g_main_context_pop_thread_default(ctx);
    return nullptr;
}

extern "C" {

/*
 * sd_video_open — 打开视频并启动硬解码管线
 *   path     - 视频文件路径
 *   parser   - 0=h264parse, 1=h265parse (由 Python 按编码格式探测后指定)
 *   width/height/fps/duration - 输出参数 (NV12 帧尺寸 / 帧率 / 文件时长秒, 时长未知为 -1)
 *
 * 返回值: 成功 0, 失败 -1。
 */
int sd_video_open(const char* path, int parser,
                  int* width, int* height, double* fps, double* duration) {
    sd_video_close();
    if (!gst_is_initialized()) gst_init(nullptr, nullptr);
    const char* parser_name = (parser == 1) ? "h265parse" : "h264parse";

    char pipe[2048];
    snprintf(pipe, sizeof(pipe),
             "filesrc location=%s ! qtdemux name=demux demux.video_0 "
             "! queue ! %s ! mppvideodec ! video/x-raw,format=NV12 "
             "! appsink name=sink sync=false max-buffers=2 emit-signals=true",
             path, parser_name);

    GError* err = nullptr;
    s_pipeline = gst_parse_launch(pipe, &err);
    if (!s_pipeline) {
        fprintf(stderr, "[sd_video] parse_launch: %s\n", err ? err->message : "?");
        if (err) g_error_free(err);
        return -1;
    }

    GstElement* sink = gst_bin_get_by_name(GST_BIN(s_pipeline), "sink");
    if (!sink) {
        fprintf(stderr, "[sd_video] appsink not found\n");
        gst_object_unref(s_pipeline);
        s_pipeline = nullptr;
        return -1;
    }
    g_signal_connect(sink, "new-sample", G_CALLBACK(on_new_sample), nullptr);
    gst_object_unref(sink);

    g_mutex_lock(&s_mtx);
    s_eos = false;
    s_closing = false;
    while (!s_queue.empty()) {
        gst_sample_unref(s_queue.front());
        s_queue.pop();
    }
    g_mutex_unlock(&s_mtx);

    // 启动消息分发线程 (总线 watch 挂在其 main loop 上)
    s_loop = g_main_loop_new(nullptr, FALSE);
    s_thread_started = (pthread_create(&s_thread, nullptr, decode_loop_func, nullptr) == 0);
    if (!s_thread_started) {
        fprintf(stderr, "[sd_video] pthread_create failed\n");
        g_main_loop_unref(s_loop);
        s_loop = nullptr;
        gst_object_unref(s_pipeline);
        s_pipeline = nullptr;
        return -1;
    }

    gst_element_set_state(s_pipeline, GST_STATE_PLAYING);

    // 阻塞等首帧 (最长 3s), 从 caps 解析宽高/帧率
    GstSample* first = nullptr;
    g_mutex_lock(&s_mtx);
    gint64 deadline = g_get_monotonic_time() + 3 * G_TIME_SPAN_SECOND;
    while (s_queue.empty() && !s_eos) {
        if (!g_cond_wait_until(&s_cond, &s_mtx, deadline)) break;
    }
    if (!s_queue.empty()) first = s_queue.front();
    g_mutex_unlock(&s_mtx);

    if (!first) {
        fprintf(stderr, "[sd_video] 首帧超时/失败 (parser=%s)\n", parser_name);
        sd_video_close();
        return -1;
    }

    GstCaps* caps = gst_sample_get_caps(first);
    if (caps) {
        GstStructure* s = gst_caps_get_structure(caps, 0);
        gst_structure_get_int(s, "width", &s_width);
        gst_structure_get_int(s, "height", &s_height);
        int num = 0, den = 1;
        gst_structure_get_fraction(s, "framerate", &num, &den);
        s_fps = (den > 0) ? (double)num / (double)den : 30.0;
    }
    if (s_width <= 0 || s_height <= 0) {
        fprintf(stderr, "[sd_video] 无效帧尺寸 %dx%d\n", s_width, s_height);
        sd_video_close();
        return -1;
    }
    s_frame_size = s_width * s_height * 3 / 2;

    gint64 dur = GST_CLOCK_TIME_NONE;
    if (gst_element_query_duration(s_pipeline, GST_FORMAT_TIME, &dur) && dur > 0) {
        s_duration = (double)dur / (double)GST_SECOND;
    } else {
        s_duration = -1.0;
    }

    *width = s_width;
    *height = s_height;
    *fps = s_fps;
    *duration = s_duration;
    printf("[sd_video] 硬解码就绪: %s %dx%d @%.2ffps %.2fs (parser=%s)\n",
           path, s_width, s_height, s_fps, s_duration, parser_name);
    return 0;
}

/*
 * sd_video_read — 取一帧 NV12 拷入 dst_buf
 *   dst_buf / dst_size - 调用方缓冲 (应 >= w*h*3/2)
 *
 * 返回值: 0 成功, -1 EOF/错误, -2 超时 (100ms 内无新帧)。
 */
int sd_video_read(uint8_t* dst_buf, int dst_size) {
    if (!s_pipeline || !dst_buf) return -1;

    GstSample* sample = nullptr;
    g_mutex_lock(&s_mtx);
    while (s_queue.empty() && !s_eos) {
        gint64 deadline = g_get_monotonic_time() + READ_WAIT_US;
        if (!g_cond_wait_until(&s_cond, &s_mtx, deadline)) {
            g_mutex_unlock(&s_mtx);
            return -2;
        }
    }
    if (s_queue.empty()) {
        g_mutex_unlock(&s_mtx);
        return -1;
    }
    sample = s_queue.front();
    s_queue.pop();
    g_cond_signal(&s_cond);   // 通知 on_new_sample 队列有空位
    g_mutex_unlock(&s_mtx);

    GstBuffer* buf = gst_sample_get_buffer(sample);
    GstMapInfo map;
    if (gst_buffer_map(buf, &map, GST_MAP_READ)) {
        int n = (int)map.size < dst_size ? (int)map.size : dst_size;
        memcpy(dst_buf, map.data, n);
        gst_buffer_unmap(buf, &map);
    }
    gst_sample_unref(sample);
    return 0;
}

/*
 * sd_video_close — 停止管线并释放全部资源 (可重复调用)
 */
void sd_video_close() {
    if (!s_pipeline) return;

    g_mutex_lock(&s_mtx);
    s_closing = true;
    s_eos = true;
    g_cond_broadcast(&s_cond);
    g_mutex_unlock(&s_mtx);

    gst_element_set_state(s_pipeline, GST_STATE_NULL);
    if (s_loop) g_main_loop_quit(s_loop);
    if (s_thread_started) {
        pthread_join(s_thread, nullptr);
        s_thread_started = false;
    }
    if (s_loop) {
        g_main_loop_unref(s_loop);
        s_loop = nullptr;
    }

    g_mutex_lock(&s_mtx);
    while (!s_queue.empty()) {
        gst_sample_unref(s_queue.front());
        s_queue.pop();
    }
    s_closing = false;
    s_eos = false;
    g_mutex_unlock(&s_mtx);

    gst_object_unref(s_pipeline);
    s_pipeline = nullptr;
    s_width = s_height = s_frame_size = 0;
    s_fps = 0.0;
    s_duration = -1.0;
}

}  // extern "C"