/**
 * @file dma_bridge_rga.cpp
 * @brief  零拷贝 AI 管线：PCIe DMA 采集 FPGA 图像 → RGA 格式转换与缩放 → DRM 直显
 *
 * 单一动态库 libdma_rga.so 的相机/HDMI/DRM 桥接部分。
 * 与 pci_dma_bridge.cpp / fpga_npu_bridge.cpp 联合编译, 共享同一
 * pci_driver_fd 与 dma_operation 映射 (内核驱动全局只允许分配一次 DMA 缓冲)。
 *
 * Python (ctypes) 调用接口:
 *   set_pipeline_resolution(w, h)      → 采集分辨率运行时切换 (相机 1280×720 / HDMI 1920×1080)
 *   get_connected_connectors(buf, n)   → 枚举已连接屏幕
 *   init_hardware_pipeline_ex(idx)     → 全链路初始化 (PCIe + RGA + DRM, 指定屏幕索引)
 *   fetch_next_frame()                 → 取一帧, RGA 输出 yolo(640×640) + hd(采集分辨率)
 *   sync_to_screen(hd_ptr)             → hd 帧 RGA 缩放/旋转后 DRM page-flip 上屏
 *   cleanup_hardware()                 → 释放 PCIe/RGA/DRM 资源
 *   gpio / pwm                         → 小车电机控制 (FPGA GPIO/PWM)
 *   sd_drm_init / sd_drm_put_and_show_ex / sd_drm_put_and_show_rot / sd_drm_cleanup
 *                                      → 纯软件源 (SD 卡/DSI 小屏) 上屏
 *   rga_cvt_resize_bgr_to_rgb          → BGR888→RGB888 + 缩放 (AI 输入预处理, 单次硬件操作)
 *   rga_resize_bgr                     → BGR888→BGR888 缩放 (渲染预处理, 单次硬件操作)
 *   rga_cvt_nv12_to_bgr                → NV12→BGR888 + 缩放 (SD 卡 MPP 硬解帧预处理, 单次硬件操作)
 *   rga_cvt_nv12_fd_to_bgr             → NV12 dma-buf fd→BGR888 + 缩放 (零拷贝硬解热路径)
 *
 * 依赖:
 *   - 内核态 pango_pci_driver (设备节点 /dev/pango_pci_driver)
 *   - Rockchip RGA 库 (librga.so, im2d API)
 *   - libdrm (用户态 DRM 接口, 直接控制显示输出)
 */

// =========================================================================
// 头文件
// =========================================================================

#include "../includes/pcie_dma_read_test.h"
#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

// Rockchip RGA 硬件加速 (格式转换、缩放、裁切)
#include <rga/im2d.h>
// DRM 用户态接口 (直接控制显示输出, 绕过 X11/Wayland)
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm_fourcc.h>
// DRM_MODE_ROTATE_90 在部分 libdrm 版本中未定义, 手动兜底
#ifndef DRM_MODE_ROTATE_90
#define DRM_MODE_ROTATE_90 2
#endif

// === 硬件与参数配置 ===
// 采集分辨率运行时配置 (set_pipeline_resolution):
//   相机 1280×720 RGB565 / HDMI 1920×1080 RGB565, 默认 1920×1080
static int g_img_width  = 1920;
static int g_img_height = 1080;
// FPGA 侧双缓冲 ping-pong 偏移: 第二帧与第一帧的字节距离 (1080p RGB565 一帧 = 0x3F4800)
const uint32_t PING_PONG_OFFSET = 0x3F4800;

const int YOLO_WIDTH  = 640;
const int YOLO_HEIGHT = 640;
const int YOLO_CHANNELS = 3;
// YOLO 帧: 640×640×3 = 1,228,800 字节
const int YOLO_SIZE = YOLO_WIDTH * YOLO_HEIGHT * YOLO_CHANNELS;
// HD 帧大小随当前采集分辨率: 1080p = 6,220,800 字节 / 720p = 2,764,800 字节
static int g_hd_size() { return g_img_width * g_img_height * 3; }
// RGA 输出缓冲布局: yolo 在前, hd 在后, 连续存放
static int g_frame_block_size() { return YOLO_SIZE + g_hd_size(); }

// =========================================================================
// 全局变量定义
// =========================================================================
static int buffer_index = 0;                 // FPGA 端 ping-pong 读取索引 (0/1)
static int py_buffer_index = 0;              // RGA 输出写入索引 (0/1)
static void* rga_out_buf = nullptr;          // RGA 输出双缓冲 (每块 yolo+hd 连续存放)

static rga_buffer_t src_bufs[2];             // 源: FPGA DMA 读缓冲 (ping[0]/pong[1])
static rga_buffer_t yolo_bufs[2];            // 目标: YOLO 640×640 RGB888
static rga_buffer_t hd_bufs[2];              // 目标: HD 直显 (采集分辨率) RGB888

// -- DRM 上下文 (直接控制显示管线) --
struct DRM_CONTEXT {
    int fd;
    uint32_t conn_id;                        // 连接器 ID (物理输出端口)
    uint32_t crtc_id;                        // CRTC ID (控制显示时序)
    drmModeModeInfo mode;
    uint32_t fb_id[2];
    uint32_t handle[2];
    uint32_t pitch[2];                       // 每行字节数 (stride)
    uint32_t size[2];                        // 每帧总字节数
    void* map[2];                            // 用户态 mmap 映射地址
    drmModeCrtc* saved_crtc;                 // 接管前的 CRTC 状态 (退出时仅 free, 不回写:
                                             //   buffer_id 已被 lightdm 释放, setCrtc 回去会内核 Oops)
    int back_index;                          // 后备缓冲区索引 (0/1)
} static drm_ctx;

// =========================================================================
// RGA / DRM 硬件桥接层
//
// RGA (Rockchip Graphics Acceleration) — 硬件格式转换 + 缩放, 零 CPU 开销
// DRM (Direct Rendering Manager) — 接管显示器输出, 绕过桌面合成器
// =========================================================================

/*
 * init_drm_ex — 按已连接屏幕索引选择目标屏幕进行 DRM 初始化
 * connector_idx: 0=第1个已连接屏幕, 1=第2个, ...
 *
 * 执行流程:
 *   1. open("/dev/dri/card0") 获取 DRM master 权限
 *   2. 按索引找到第 connector_idx 个已接屏的 connector
 *   3. 优先选择横屏 mode (hdisplay >= vdisplay)
 *   4. 创建两块 dumb buffer (双缓冲) 并注册 Framebuffer, mmap 到用户态
 *   5. 保存原始 CRTC 状态, drmModeSetCrtc 接管显示输出
 *   6. 隐藏硬件光标, 避免桌面光标叠加到推流画面
 */
int init_drm_ex(int connector_idx) {
    drm_ctx.fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (drm_ctx.fd < 0) return -1;
    drmSetClientCap(drm_ctx.fd, DRM_CLIENT_CAP_ATOMIC, 1);
    drmModeRes* res = drmModeGetResources(drm_ctx.fd);
    if (!res) return -1;
    drmModeConnector* conn = nullptr;
    int connected_count = 0;
    for (int i = 0; i < res->count_connectors; ++i) {
        conn = drmModeGetConnector(drm_ctx.fd, res->connectors[i]);
        if (conn && conn->connection == DRM_MODE_CONNECTED) {
            if (connected_count == connector_idx) break;
            connected_count++;
        }
        drmModeFreeConnector(conn);
        conn = nullptr;
    }
    if (!conn) { drmModeFreeResources(res); return -1; }
    drm_ctx.conn_id = conn->connector_id;
    // 优先选择横屏 mode (hdisplay >= vdisplay), 避免 DSI 竖屏面板显示旋转
    int best_mode_idx = 0;
    for (int m = 0; m < conn->count_modes; ++m) {
        if (conn->modes[m].hdisplay >= conn->modes[m].vdisplay) {
            best_mode_idx = m;
            break;
        }
    }
    drm_ctx.mode = conn->modes[best_mode_idx];
    drmModeEncoder* enc = drmModeGetEncoder(drm_ctx.fd, conn->encoder_id);
    drm_ctx.crtc_id = enc->crtc_id;
    drmModeFreeEncoder(enc);
    drmModeFreeConnector(conn);
    for (int i = 0; i < 2; ++i) {
        struct drm_mode_create_dumb create_arg = {};
        create_arg.width = drm_ctx.mode.hdisplay;
        create_arg.height = drm_ctx.mode.vdisplay;
        create_arg.bpp = 32;
        if (drmIoctl(drm_ctx.fd, DRM_IOCTL_MODE_CREATE_DUMB, &create_arg) < 0) return -1;
        drm_ctx.handle[i] = create_arg.handle;
        drm_ctx.pitch[i] = create_arg.pitch;
        drm_ctx.size[i] = create_arg.size;
        uint32_t handles[4] = {drm_ctx.handle[i]}, pitches[4] = {drm_ctx.pitch[i]}, offsets[4] = {0};
        if (drmModeAddFB2(drm_ctx.fd, drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay,
                          DRM_FORMAT_ARGB8888, handles, pitches, offsets, &drm_ctx.fb_id[i], 0) < 0) return -1;
        struct drm_mode_map_dumb map_arg = {};
        map_arg.handle = drm_ctx.handle[i];
        drmIoctl(drm_ctx.fd, DRM_IOCTL_MODE_MAP_DUMB, &map_arg);
        drm_ctx.map[i] = mmap(0, drm_ctx.size[i], PROT_READ | PROT_WRITE, MAP_SHARED, drm_ctx.fd, map_arg.offset);
    }
    drm_ctx.saved_crtc = drmModeGetCrtc(drm_ctx.fd, drm_ctx.crtc_id);
    if (drmModeSetCrtc(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[0], 0, 0, &drm_ctx.conn_id, 1, &drm_ctx.mode) < 0) return -1;
    // 隐藏硬件光标, 避免 X/lightdm 的鼠标光标叠加到推流画面并触发桌面重绘
    drmModeSetCursor(drm_ctx.fd, drm_ctx.crtc_id, 0, 0, 0);
    // 竖屏面板旋转由 sync_to_screen 中的 RGA 硬件旋转统一处理,
    // 不再依赖 CRTC rotation property (Rockchip 平台可能不支持)
    drm_ctx.back_index = 1;
    drmModeFreeResources(res);
    return 0;
}

// DMA 映射共享语义 (单一动态库内相机/HDMI/FPGA_NPU 共用同一份 fd/mmap):
//   - NPU 先 npu_init 时: fd/mmap 已就绪, 本模块直接复用 (pci_map 返回 EBUSY, 跳过分配)
//   - 相机先初始化时: 本模块自行 open + pci_map
// 内核驱动全局 TX/RX 缓冲只允许分配一次, 复用者不得 umap/close 分配者资源。
// 所有权分三档记录, cleanup 各司其职:
//   s_camera_opened_fd   = 本模块 open 了驱动 fd          → cleanup 时 close
//   s_camera_created_map = 本模块创建了驱动全局 DMA 映射  → cleanup 时 umap
//   s_camera_mapped      = 本模块 mmap 了 TX/RX           → cleanup 时 munmap
static int s_camera_opened_fd   = 0;
static int s_camera_created_map = 0;
static int s_camera_mapped      = 0;

static const uint32_t DMA_TX_BUF_SIZE = 1024*1024*3;   // 与 npu_config.h TX_BUF_SIZE 一致
static const uint32_t DMA_RX_BUF_SIZE = 1024*1024*10;  // 与 npu_config.h RX_BUF_SIZE 一致

static int ensure_pci_dma_ready(void) {
    if (pci_driver_fd < 0) {
        pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        s_camera_opened_fd = 1;
    }

    if (!dma_operation.data.write_buf || dma_operation.data.write_buf == MAP_FAILED) {
        int map_ret = pci_map(pci_driver_fd, 3, DMA_TX_BUF_SIZE, DMA_RX_BUF_SIZE);
        if (map_ret < 0 && errno != EBUSY) return -1;   // EBUSY: 复用已分配的全局映射
        s_camera_created_map = (map_ret == 0);
        dma_operation.data = pci_mmp(pci_driver_fd, 3, DMA_TX_BUF_SIZE, DMA_RX_BUF_SIZE);
        s_camera_mapped = (dma_operation.data.write_buf &&
                           dma_operation.data.write_buf != MAP_FAILED);
    }

    if (!dma_operation.data.write_buf || dma_operation.data.write_buf == MAP_FAILED)
        return -1;
    return 0;
}

/*
 * init_pci_rga_common — PCIe + RGA 公共初始化 (init_hardware_pipeline_ex 调用)
 *   1. 确保 DMA 映射就绪 (复用或新建, 见 ensure_pci_dma_ready)
 *   2. 分配 RGA 输出双缓冲并绑定源/目标句柄
 *   3. 配置 FPGA 采集寄存器 (双缓冲基址/使能) 并复位帧索引
 */
static int init_pci_rga_common(void) {
    if (ensure_pci_dma_ready() < 0) return -1;
    if (rga_out_buf) { free(rga_out_buf); rga_out_buf = nullptr; }
    rga_out_buf = malloc(g_frame_block_size() * 2);
    if (!rga_out_buf) return -1;

    void* fpga_base = (void*)dma_operation.data.read_buf;
    src_bufs[0] = wrapbuffer_virtualaddr(fpga_base, g_img_width, g_img_height, RK_FORMAT_BGR_565);
    src_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)fpga_base + PING_PONG_OFFSET, g_img_width, g_img_height, RK_FORMAT_BGR_565);

    void* py_base_0 = rga_out_buf;
    void* py_base_1 = (uint8_t*)rga_out_buf + g_frame_block_size();
    yolo_bufs[0] = wrapbuffer_virtualaddr(py_base_0, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
    yolo_bufs[1] = wrapbuffer_virtualaddr(py_base_1, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
    hd_bufs[0] = wrapbuffer_virtualaddr((uint8_t*)py_base_0 + YOLO_SIZE, g_img_width, g_img_height, RK_FORMAT_RGB_888);
    hd_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)py_base_1 + YOLO_SIZE, g_img_width, g_img_height, RK_FORMAT_RGB_888);

    // FPGA 采集寄存器配置 (双缓冲基址/使能/中断使能)
    unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
    ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = PING_PONG_OFFSET;
    ptr32[4] = 0x00000001; ptr32[5] = 0x00000002; ptr32[6] = 0x00000003;
    pci_dma_single_write(pci_driver_fd, 0x20000080, 8,  4);
    pci_dma_single_write(pci_driver_fd, 0x200000c0, 12, 4);
    pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);
    pci_dma_single_write(pci_driver_fd, 0x20000040, 4,  4);

    buffer_index = 0;
    py_buffer_index = 0;
    return 0;
}

/*
 * cleanup_drm_ctx — 释放 DRM 资源 (cleanup_hardware / sd_drm_cleanup 共用)
 *   不恢复 CRTC: saved_crtc 的 buffer_id 来自 lightdm, 接管后可能已被释放,
 *   drmModeSetCrtc 回去会触发内核 Oops。关闭 fd 后 DRM 框架会自动回收 CRTC。
 */
static void cleanup_drm_ctx(void) {
    if (drm_ctx.saved_crtc) {
        drmModeFreeCrtc(drm_ctx.saved_crtc);
        drm_ctx.saved_crtc = nullptr;
    }
    for (int i = 0; i < 2; ++i) {
        if (drm_ctx.map[i]) { munmap(drm_ctx.map[i], drm_ctx.size[i]); drm_ctx.map[i] = nullptr; }
        if (drm_ctx.fb_id[i]) { drmModeRmFB(drm_ctx.fd, drm_ctx.fb_id[i]); drm_ctx.fb_id[i] = 0; }
        if (drm_ctx.handle[i]) {
            struct drm_mode_destroy_dumb destroy_arg = {};
            destroy_arg.handle = drm_ctx.handle[i];
            drmIoctl(drm_ctx.fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy_arg);
            drm_ctx.handle[i] = 0;
        }
    }
    if (drm_ctx.fd > 0) { close(drm_ctx.fd); drm_ctx.fd = -1; }
}

// =========================================================================
// extern "C" 块 — Python ctypes 调用的动态库入口
//
// C++ mangling 被 extern "C" 抑制, 符号名与 Python 侧一致。
// =========================================================================
extern "C" {

    /*
     * get_connected_connectors — 检测所有已连接的 DRM 屏幕
     * buf: 输出缓冲, 每行 "序号:类型-类型ID" (如 "0:HDMI-1")
     * 返回值: 已连接屏幕数量, -1 表示失败
     */
    int get_connected_connectors(char* buf, int buf_size) {
        int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
        if (fd < 0) return -1;
        drmModeRes* res = drmModeGetResources(fd);
        if (!res) { close(fd); return -1; }
        int count = 0, offset = 0;
        for (int i = 0; i < res->count_connectors; ++i) {
            drmModeConnector* conn = drmModeGetConnector(fd, res->connectors[i]);
            if (!conn) continue;
            if (conn->connection == DRM_MODE_CONNECTED) {
                const char* type_name = "Other";
                switch (conn->connector_type) {
                    case DRM_MODE_CONNECTOR_VGA:  type_name = "VGA";  break;
                    case DRM_MODE_CONNECTOR_DVII: case DRM_MODE_CONNECTOR_DVID:
                    case DRM_MODE_CONNECTOR_DVIA: type_name = "DVI";  break;
                    case DRM_MODE_CONNECTOR_HDMIA: case DRM_MODE_CONNECTOR_HDMIB:
                                                  type_name = "HDMI"; break;
                    case DRM_MODE_CONNECTOR_LVDS: type_name = "LVDS"; break;
                    case DRM_MODE_CONNECTOR_DSI:  type_name = "DSI";  break;
                    case DRM_MODE_CONNECTOR_eDP:  type_name = "eDP";  break;
                    case DRM_MODE_CONNECTOR_DisplayPort: type_name = "DP"; break;
                }
                int written = snprintf(buf + offset, buf_size - offset,
                                       "%d:%s-%u\n", count, type_name, conn->connector_type_id);
                if (written > 0) offset += written;
                count++;
            }
            drmModeFreeConnector(conn);
        }
        drmModeFreeResources(res);
        close(fd);
        return count;
    }

    /*
     * set_pipeline_resolution — 设置 FPGA 采集分辨率 (在 init 之前调用)
     *
     * 单一动态库同时服务相机 (1280×720) 与 HDMI (1920×1080) 管线,
     * 分辨率由运行时配置, 不再依赖编译宏。
     *
     * 返回值: 成功 0, 不支持的分辨率 -1。
     */
    int set_pipeline_resolution(int width, int height) {
        if ((width == 1280 && height == 720) || (width == 1920 && height == 1080)) {
            g_img_width = width;
            g_img_height = height;
            return 0;
        }
        fprintf(stderr, "set_pipeline_resolution: unsupported %dx%d\n", width, height);
        return -1;
    }

    /*
     * init_hardware_pipeline_ex — 指定目标屏幕的全链路硬件管线初始化
     *   PCIe + RGA 公共初始化 (init_pci_rga_common) + DRM 接管 (init_drm_ex)
     *
     * connector_idx: 0=第1个已连接屏幕, 1=第2个, ...
     * 返回值: 成功 0, 失败 -1。
     */
    int init_hardware_pipeline_ex(int connector_idx) {
        if (init_pci_rga_common() < 0) return -1;
        if (init_drm_ex(connector_idx) < 0) return -1;
        return 0;
    }

    /*
     * fetch_next_frame — 从 FPGA 取一帧并完成 RGA 格式转换
     *
     * 数据流:
     *   ioctl(PCI_GET_IMG)  →  FPGA 侧 ping-pong buffer → src_bufs[src_idx]
     *   pci_dma_single_write(ACK)  →  通知 FPGA 本帧已取, 准备下一帧
     *   improcess(src → yolo_bufs[dst_idx])  →  RGB565 → RGB888, 缩放至 640×640
     *   improcess(src → hd_bufs[dst_idx])    →  RGB565 → RGB888, 保持采集分辨率
     *
     * ping-pong 索引翻转:
     *   - buffer_index (FPGA 端): 每次读取后翻转, 交替 ping/pong
     *   - py_buffer_index (输出端): 每次 RGA 处理后翻转, 输出块交替
     *
     * 返回值: 成功返回当前 yolo+hd 块起始指针, 失败返回 nullptr。
     */
    uint8_t* fetch_next_frame() {
        int ret = ioctl(pci_driver_fd, PCI_GET_IMG, &dma_operation);
        if (ret < 0) return nullptr;
        uint32_t fpga_ack_offset = buffer_index * 4 + 16;
        pci_dma_single_write(pci_driver_fd, 0x20000000, fpga_ack_offset, 4);
        if (dma_operation.data.read_buf != NULL && dma_operation.data.read_buf != MAP_FAILED) {
            // 直接使用预绑定的索引, 不再重复 wrapbuffer
            int src_idx = buffer_index;
            int dst_idx = py_buffer_index;
            improcess(src_bufs[src_idx], yolo_bufs[dst_idx], {}, {0, 0, g_img_width, g_img_height}, {0, 0, YOLO_WIDTH, YOLO_HEIGHT}, {}, 0, nullptr, nullptr, 0);
            improcess(src_bufs[src_idx], hd_bufs[dst_idx], {}, {0, 0, g_img_width, g_img_height}, {0, 0, g_img_width, g_img_height}, {}, 0, nullptr, nullptr, 0);
        }

        buffer_index = 1 - buffer_index;
        void* ret_ptr = (py_buffer_index == 0) ? rga_out_buf : (uint8_t*)rga_out_buf + g_frame_block_size();
        py_buffer_index = 1 - py_buffer_index;

        return (uint8_t*)ret_ptr;
    }

    /*
     * sync_to_screen — 将 HD 帧推送到物理屏幕
     *
     * 流程:
     *   1. wrapbuffer_virtualaddr 包装 hd_ptr 和 DRM dumb buffer 为 RGA 句柄
     *   2. improcess 使用 RGA 硬件将 HD RGB888 → 屏幕分辨率 BGRA8888
     *      (竖屏面板时附加 RGA 硬件旋转 90°)
     *   3. drmModePageFlip 异步翻页 (双缓冲), 不阻塞 CPU
     *   4. 翻转 back_index, 下次写入另一块 buffer
     *
     * 参数 hd_ptr: fetch_next_frame() 返回的帧块中 hd 部分的起始地址。
     */
    void sync_to_screen(uint8_t* hd_ptr) {
        if (!hd_ptr || drm_ctx.fd <= 0) return;
        rga_buffer_t py_hd_buf = wrapbuffer_virtualaddr(hd_ptr, g_img_width, g_img_height, RK_FORMAT_RGB_888);
        rga_buffer_t drm_dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index], drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay, RK_FORMAT_BGRA_8888);
        im_rect drm_dst_rect = {0, 0, drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay};
        int im_usage = 0;
        if (drm_ctx.mode.hdisplay < drm_ctx.mode.vdisplay) {
            // 竖屏面板: RGA 硬件旋转 90°, 源旋转后适配竖屏缓冲区
            im_usage = IM_HAL_TRANSFORM_ROT_90;
        }
        improcess(py_hd_buf, drm_dst_buf, {}, {0, 0, g_img_width, g_img_height}, drm_dst_rect, {}, 0, nullptr, nullptr, im_usage);

        int flip_ret = drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index], DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
        if (flip_ret == 0) {
            drm_ctx.back_index = 1 - drm_ctx.back_index;
            return;
        }
        // -EBUSY: 前一 flip 尚未完成, 属于正常的高帧率排队失败。
        // 本帧不上屏, 保持 back_index 不变 (下一帧覆盖同一 buffer), 避免写正在显示的 buffer 造成画面重叠/撕裂。
        if (flip_ret == -EBUSY) {
            return;
        }
        // 其余错误: 失去 DRM master/CRTC (Xorg/lightdm 抢占, 鼠标/触摸点击小屏触发桌面重绘)。
        // 强制 modeset 抢回屏幕, 成功后才翻转 back_index, 保证推流不被鼠标打断且不破坏双缓冲。
        static int recover_cnt = 0;
        if (recover_cnt++ < 5 || recover_cnt % 200 == 1)
            printf("[DRM] page_flip=%d 失败, 强制 modeset 抢回屏幕 (第 %d 次)\n", flip_ret, recover_cnt);
        drmSetMaster(drm_ctx.fd);
        int crtc_ret = -1;
        for (int attempt = 0; attempt < 3 && crtc_ret != 0; ++attempt) {
            crtc_ret = drmModeSetCrtc(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index],
                                      0, 0, &drm_ctx.conn_id, 1, &drm_ctx.mode);
            if (crtc_ret != 0) usleep(2000);   // Xorg 可能正在提交, 稍等再试
        }
        drmModeSetCursor(drm_ctx.fd, drm_ctx.crtc_id, 0, 0, 0);
        if (crtc_ret == 0) {
            drm_ctx.back_index = 1 - drm_ctx.back_index;
        }
    }

    /*
     * gpio — 控制 FPGA 端 GPIO 引脚电平 (通过 PCIe ioctl)
     *
     * 参数:
     *   num   - FPGA 引脚编号 (如 AIN1=88 / BIN1=90 / STBY=74)
     *   value - 电平值 (0=低电平, 1=高电平)
     *
     * 返回值: 成功 0, 失败 -1。
     */
    int gpio(int num, int value) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        C_GPIO my_gpio = {0};
        my_gpio.gpio_num = (unsigned int)num;
        my_gpio.level    = (unsigned int)value;

        int ret = ioctl(pci_driver_fd, GPIO_CTRL, &my_gpio);
        if (ret < 0) {
            perror("GPIO_CTRL failed");
            return -1;
        }
        return 0;
    }

    /*
     * pwm — 控制 FPGA 端 PWM 通道输出
     *
     * 参数:
     *   num    - PWM 通道号 (2=左电机, 3=右电机)
     *   enable - 使能开关 (0=关闭, 1=开启)
     *   period - PWM 周期, 单位纳秒 (ns)
     *   duty   - 占空比, 百分比 0~100 (内部取反: 高电平 = 100-duty)
     *
     * 返回值: 成功 0, 失败 -1。
     */
    int pwm(int num, int enable, int period, int duty) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        int real_duty_ns = (100 - duty) * period / 100;
        C_GPIO my_pwm = {0};
        my_pwm.gpio_num   = (unsigned int)num;
        my_pwm.pwm_enable = (unsigned int)enable;

        if (enable) {
            my_pwm.pwm_period = (unsigned int)period;
            my_pwm.pwm_duty   = (unsigned int)real_duty_ns;
        }

        int ret = ioctl(pci_driver_fd, PWM_CTRL, &my_pwm);
        if (ret < 0) {
            perror("PWM_CTRL failed");
            return -1;
        }
        return 0;
    }

    // ── 纯软件源上屏 (SD 卡 / DSI 小屏共用): RGA 硬件加速, 零 CPU 像素搬运 ──

    int sd_drm_init(int connector_idx) {
        return init_drm_ex(connector_idx);
    }

    /*
     * sd_drm_put_and_show_ex — RGA 硬件加速上屏 (动态分辨率, 直通 BGR)
     *
     *   - 接受任意分辨率的 BGR888 输入 (OpenCV cv2.VideoCapture 原生格式)
     *   - RGA 内部完成 BGR→BGRA 转换 + 缩放至屏幕分辨率
     *   - Python 侧无需做 cv2.resize + cv2.cvtColor, 零 CPU 像素搬运
     *
     * 参数:
     *   src_data - BGR888 格式的帧数据指针
     *   width    - 输入帧宽度
     *   height   - 输入帧高度
     */
    int sd_drm_put_and_show_ex(uint8_t* src_data, int width, int height) {
        if (!src_data || drm_ctx.fd <= 0) return -1;
        if (width <= 0 || height <= 0) return -1;

        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src_data, width, height, RK_FORMAT_BGR_888);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index],
                                                       drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay,
                                                       RK_FORMAT_BGRA_8888);

        im_rect src_rect = {0, 0, width, height};
        im_rect dst_rect = {0, 0, (int)drm_ctx.mode.hdisplay, (int)drm_ctx.mode.vdisplay};

        improcess(src_buf, dst_buf, {}, src_rect, dst_rect, {}, 0, nullptr, nullptr, 0);

        drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index],
                        DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
        drm_ctx.back_index = 1 - drm_ctx.back_index;
        return 0;
    }

    void sd_drm_cleanup() {
        cleanup_drm_ctx();
    }

    /*
     * rga_cvt_resize_bgr_to_rgb — RGA 硬件 BGR888→RGB888 格式转换 + 缩放 (单次)
     *
     * AI 推理输入预处理: 原分辨率 BGR 帧 → 640×640 RGB888 (YOLO 输入格式),
     * 取代 Python 侧 cv2.cvtColor(BGR2RGB) + cv2.resize 两步 CPU 操作。
     *
     * 参数:
     *   src    - 源 BGR888 帧数据指针
     *   sw/sh  - 源帧宽高
     *   dst    - 目标 RGB888 缓冲 (dw×dh)
     *   dw/dh  - 目标宽高
     *
     * 返回值: 成功 0, 失败 -1。
     */
    int rga_cvt_resize_bgr_to_rgb(uint8_t* src, int sw, int sh,
                                  uint8_t* dst, int dw, int dh) {
        if (!src || !dst) return -1;
        if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return -1;
        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src, sw, sh, RK_FORMAT_BGR_888);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(dst, dw, dh, RK_FORMAT_RGB_888);
        IM_STATUS st = improcess(src_buf, dst_buf, {},
                                 {0, 0, sw, sh}, {0, 0, dw, dh}, {},
                                 0, nullptr, nullptr, 0);
        return (st == IM_STATUS_SUCCESS) ? 0 : -1;
    }

    /*
     * rga_resize_bgr — RGA 硬件 BGR888→BGR888 缩放 (单次)
     *
     * 渲染预处理: 原分辨率 BGR 帧 → 1280×720 BGR 绘图缓冲,
     * 取代 Python 侧 cv2.resize CPU 缩放。
     *
     * 参数同 rga_cvt_resize_bgr_to_rgb。
     */
    int rga_resize_bgr(uint8_t* src, int sw, int sh,
                       uint8_t* dst, int dw, int dh) {
        if (!src || !dst) return -1;
        if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return -1;
        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src, sw, sh, RK_FORMAT_BGR_888);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(dst, dw, dh, RK_FORMAT_BGR_888);
        IM_STATUS st = improcess(src_buf, dst_buf, {},
                                 {0, 0, sw, sh}, {0, 0, dw, dh}, {},
                                 0, nullptr, nullptr, 0);
        return (st == IM_STATUS_SUCCESS) ? 0 : -1;
    }

    /*
     * sd_drm_put_and_show_rot — RGA 上屏 (BGR888 → BGRA8888 + 缩放 + 可选旋转 90°)
     *
     * sd_drm_put_and_show_ex 的旋转增强版: 竖屏面板时 rot=1,
     * RGA 在单次硬件操作中同时完成 格式转换 + 缩放 + 旋转 90°,
     * 取代 Python 侧 cv2.rotate + 二次 RGA 上屏。
     *
     * 参数:
     *   src_data    - BGR888 帧数据指针
     *   width/height- 输入帧宽高
     *   rot         - 0=不旋转, 1=顺时针旋转 90°
     */
    int sd_drm_put_and_show_rot(uint8_t* src_data, int width, int height, int rot) {
        if (!src_data || drm_ctx.fd <= 0) return -1;
        if (width <= 0 || height <= 0) return -1;

        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src_data, width, height, RK_FORMAT_BGR_888);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index],
                                                       drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay,
                                                       RK_FORMAT_BGRA_8888);

        im_rect src_rect = {0, 0, width, height};
        im_rect dst_rect = {0, 0, (int)drm_ctx.mode.hdisplay, (int)drm_ctx.mode.vdisplay};

        int im_usage = (rot == 1) ? IM_HAL_TRANSFORM_ROT_90 : 0;
        improcess(src_buf, dst_buf, {}, src_rect, dst_rect, {}, 0, nullptr, nullptr, im_usage);

        drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index],
                        DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
        drm_ctx.back_index = 1 - drm_ctx.back_index;
        return 0;
    }

    /*
     * rga_cvt_nv12_to_bgr — RGA 硬件 NV12→BGR888 格式转换 + 缩放 (单次)
     *
     * SD 卡硬解路径渲染预处理: GStreamer MPP (mppvideodec) 输出的 NV12 裸帧
     * → 显示分辨率 BGR 绘图帧, 取代 CPU 侧 YUV→BGR 全帧转换。
     *
     * 参数:
     *   src    - NV12 帧数据指针 (Y 平面 w*h + UV 交错平面 w*h/2)
     *   sw/sh  - 源帧宽高 (UV 半分辨率)
     *   stride - 源行 stride 字节数 (MPP 输出可能 16 对齐, 如 1080→1088)
     *   dst    - 目标 BGR888 缓冲 (dw×dh)
     *   dw/dh  - 目标宽高
     *
     * 返回值: 成功 0, 失败 -1。
     */
    int rga_cvt_nv12_to_bgr(uint8_t* src, int sw, int sh, int stride,
                            uint8_t* dst, int dw, int dh) {
        if (!src || !dst) return -1;
        if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return -1;
        if (stride < sw) stride = sw;
        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src, sw, sh, RK_FORMAT_YCbCr_420_SP,
                                                       stride, sh);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(dst, dw, dh, RK_FORMAT_BGR_888);
        IM_STATUS st = improcess(src_buf, dst_buf, {},
                                 {0, 0, sw, sh}, {0, 0, dw, dh}, {},
                                 0, nullptr, nullptr, 0);
        return (st == IM_STATUS_SUCCESS) ? 0 : -1;
    }

    /*
     * rga_cvt_nv12_fd_to_bgr — RGA 硬件经 dma-buf fd 零拷贝转换 NV12→BGR888 (单次)
     *
     * MPP 硬解输出的 NV12 dma-buf (无缓存 DRM 内存) 由 RGA DMA 引擎直接读取,
     * 免去 CPU memcpy (无缓存读仅 ~160MB/s, 1080p 单帧约 19ms 的代价)。
     * 板端实测: 解码 + 本转换 ≈ 5.7ms/帧 (~176fps)。
     *
     * 参数:
     *   fd     - NV12 dma-buf fd (有效至调用方释放 sample)
     *   sw/sh  - 源帧宽高
     *   stride - 源行 stride 字节数 (MPP 输出可能 16 对齐, 如 1080→1088)
     *   dst    - 目标 BGR888 缓冲 (dw×dh)
     *   dw/dh  - 目标宽高
     *
     * 返回值: 成功 0, 失败 -1。
     */
    int rga_cvt_nv12_fd_to_bgr(int fd, int sw, int sh, int stride,
                               uint8_t* dst, int dw, int dh) {
        if (fd < 0 || !dst) return -1;
        if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return -1;
        if (stride < sw) stride = sw;
        rga_buffer_t src_buf = wrapbuffer_fd(fd, sw, sh, RK_FORMAT_YCbCr_420_SP,
                                              stride, sh);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(dst, dw, dh, RK_FORMAT_BGR_888);
        IM_STATUS st = improcess(src_buf, dst_buf, {},
                                 {0, 0, sw, sh}, {0, 0, dw, dh}, {},
                                 0, nullptr, nullptr, 0);
        return (st == IM_STATUS_SUCCESS) ? 0 : -1;
    }

    /*
     * cleanup_hardware — 释放全部硬件资源
     *
     * 释放顺序:
     *   1. free(rga_out_buf)               → 释放 RGA 输出双缓冲
     *   2. cleanup_drm_ctx                 → 释放 DRM dumb buffer 并关闭 fd (不恢复 CRTC)
     *   3. munmap TX/RX                    → 收回本模块建立的用户态映射
     *   4. umap + close                    → 仅收回本模块创建的驱动映射与 fd
     */
    void cleanup_hardware() {
        if (rga_out_buf) { free(rga_out_buf); rga_out_buf = nullptr; }
        cleanup_drm_ctx();
        // 收回本实例建立的 TX/RX 用户态映射 (munmap 不影响驱动全局缓冲)
        if (s_camera_mapped) {
            if (dma_operation.data.write_buf && dma_operation.data.write_buf != MAP_FAILED)
                munmap(dma_operation.data.write_buf, DMA_TX_BUF_SIZE);
            if (dma_operation.data.read_buf && dma_operation.data.read_buf != MAP_FAILED)
                munmap(dma_operation.data.read_buf, DMA_RX_BUF_SIZE);
            dma_operation.data = {};
            s_camera_mapped = 0;
        }
        // 仅本实例创建的映射才 umap: 驱动全局缓冲由分配者 fd 的 release 兜底回收,
        // 复用他库映射时 umap 会误杀仍在使用的共享缓冲。
        if (s_camera_created_map && pci_driver_fd >= 0) {
            pci_umap(pci_driver_fd);
            s_camera_created_map = 0;
        }
        // 本实例自行 open 的 fd 一律 close (驱动仅分配者 fd 的 release 才释放全局缓冲,
        // 复用映射的实例 close 自己的 fd 不再有误杀风险)。
        if (s_camera_opened_fd && pci_driver_fd >= 0) {
            close(pci_driver_fd);
            pci_driver_fd = -1;
        }
        s_camera_opened_fd = 0;
    }
}