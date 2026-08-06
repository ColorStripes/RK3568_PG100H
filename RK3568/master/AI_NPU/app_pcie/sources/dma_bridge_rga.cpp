/**
 * @file dma_bridge_rga.cpp
 * @brief  零拷贝 AI 推理管线：PCIe DMA 采集 FPGA 图像 → RGA 格式转换与缩放 → DRM 直显
 *
 * 整体数据流（以 Python 为调用方）：
 *   Python (ctypes) 调用此 .so 的 extern "C" 函数
 *     init_hardware_pipeline()  →  初始化 PCIe + RGA + DRM 全链路
 *     fetch_next_frame()        →  PCI_GET_IMG 取一帧，RGA 转换出 yolo(640×640) + hd(1280×720)
 *     sync_to_screen()          →  hd 帧通过 RGA 缩放后 DRM page-flip 上屏
 *     cleanup_hardware()        →  释放全部资源，恢复原始 CRTC 状态
 *
 * 依赖：
 *   - 内核态 pango_pci_driver（提供 /dev/pcie_dma_driver 设备节点）
 *   - Rockchip RGA 库（librga.so，提供 im2d API）
 *   - libdrm（用户态 DRM 接口，直接控制显示输出）
 */

// =========================================================================
// 头文件
// =========================================================================

 // PCIe DMA 驱动用户态接口（设备路径、ioctl 命令码、结构体定义）
 #include "../includes/pcie_dma_read_test.h"
 #include "../includes/npu_config.h"
 // C++ 标准库
 #include <iostream>
 #include <fcntl.h>
 #include <unistd.h>
 #include <sys/mman.h>
 #include <sys/ioctl.h>
 #include <cstdlib>
 #include <cstring>
 #include <algorithm>

 // Rockchip RGA 硬件加速（格式转换、缩放、裁切）
 #include <rga/RgaApi.h>
 #include <rga/im2d.h>
 // DRM 用户态接口（直接控制显示输出，绕过 X11/Wayland）
 #include <xf86drm.h>
 #include <xf86drmMode.h>
 #include <drm_fourcc.h>
 // DRM_MODE_ROTATE_90 在部分 libdrm 版本中未定义，手动兜底
 #ifndef DRM_MODE_ROTATE_90
 #define DRM_MODE_ROTATE_90 2
 #endif
  
 using namespace std;
  
 // === 硬件与参数配置 ===
 // 通过编译宏选择分辨率：-DCAMERA_MODE → 1280×720，默认 → 1920×1080
#ifdef CAMERA_MODE
 // 摄像头模式：1280×720 RGB565
const int FPGA_IMG_WIDTH  = 1280;
const int FPGA_IMG_HEIGHT = 720;
#else
 // HDMI 模式：1920×1080 RGB565
const int FPGA_IMG_WIDTH  = 1920;
const int FPGA_IMG_HEIGHT = 1080;
#endif
 // FPGA 侧双缓冲 ping-pong 偏移，两帧交替存放避免读写竞争
// const uint32_t PING_PONG_OFFSET = 0x1C2000;
const uint32_t PING_PONG_OFFSET =0x3F4800;
 const int YOLO_WIDTH  = 640;
 const int YOLO_HEIGHT = 640;
 const int YOLO_CHANNELS = 3; 
 
 // YOLO 帧：640×640×3 = 1,228,800 字节
const int YOLO_SIZE = YOLO_WIDTH * YOLO_HEIGHT * YOLO_CHANNELS;
 // HD 帧：1920×1080×3 = 6,220,800 字节
// 【旧】1280×720×3 = 2,764,800 字节
const int HD_SIZE = FPGA_IMG_WIDTH * FPGA_IMG_HEIGHT * 3; 
 // RGA 输出缓冲布局：yolo 在前，hd 在后，连续存放
const int FRAME_BLOCK_SIZE = YOLO_SIZE + HD_SIZE; 
  
 // =========================================================================
 // 全局变量定义 
 // =========================================================================
 int buffer_index = 0;                            // FPGA 端 ping-pong 读取索引（0/1）
 int py_buffer_index = 0;                         // Python 端 RGA 输出写入索引（0/1）
 void* rga_out_buf = nullptr;                     // RGA 输出双缓冲（每块 yolo+hd 约 4MB）
 
 rga_buffer_t src_bufs[2];                        // 源：FPGA DMA 读缓冲（ping[0]/pong[1]）
 rga_buffer_t yolo_bufs[2];                       // 目标：YOLO 640×640 RGB888
 rga_buffer_t hd_bufs[2];                         // 目标：HD 直显 1280×720 RGB888
  
 // -- DRM 上下文（直接控制显示管线） --
struct DRM_CONTEXT {
     int fd;
     uint32_t conn_id;                            // 连接器 ID (物理输出端口)
     uint32_t crtc_id;                            // CRTC ID (控制显示时序)
     drmModeModeInfo mode;
     uint32_t fb_id[2]; 
     uint32_t handle[2]; 
     uint32_t pitch[2];                           // 每行字节数 (stride)
     uint32_t size[2];                            // 每帧总字节数
     void* map[2];                               // 用户态 mmap 映射地址
     drmModeCrtc* saved_crtc;                    // 原始 CRTC (退出时恢复桌面)
     int back_index;                              // 后备缓冲区索引 (0/1)
 } drm_ctx;
  
 
 // =========================================================================
 // RGA / DRM 硬件桥接层
//
// RGA (Rockchip Graphics Acceleration) — 硬件格式转换 + 缩放，零 CPU 开销
// DRM (Direct Rendering Manager) — 接管显示器输出，绕过桌面合成器
 // =========================================================================
 
 /*
 * init_drm — 初始化 DRM 直接显示管线，绕过 X11/Wayland 桌面
 *
 * 执行流程：
 *   1. open("/dev/dri/card0") 获取 DRM master 权限
 *   2. 遍历连接器找到第一个已接屏的 connector
 *   3. 获取首选显示模式（分辨率 + 刷新率）
 *   4. 通过 DRM_IOCTL_MODE_CREATE_DUMB 创建两块 dumb buffer（双缓冲）
 *   5. 通过 drmModeAddFB2 将 buffer 注册为 Framebuffer
 *   6. 通过 DRM_IOCTL_MODE_MAP_DUMB + mmap 映射到用户态
 *   7. 保存原始 CRTC 状态（退出时恢复）
 *   8. drmModeSetCrtc 接管显示输出，初始显示 fb[0]
 *
 * 双缓冲索引: back_index 初始设为 1（第一帧将写入 fb[0]）
 */
int init_drm() {
     drm_ctx.fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
     if (drm_ctx.fd < 0) return -1;
     drmSetClientCap(drm_ctx.fd, DRM_CLIENT_CAP_ATOMIC, 1);
     drmModeRes* res = drmModeGetResources(drm_ctx.fd);
     if (!res) return -1;
     drmModeConnector* conn = nullptr;
     for (int i = 0; i < res->count_connectors; ++i) {
         conn = drmModeGetConnector(drm_ctx.fd, res->connectors[i]);
         if (conn && conn->connection == DRM_MODE_CONNECTED) break;
         drmModeFreeConnector(conn);
         conn = nullptr;
     }
     if (!conn) return -1;
     drm_ctx.conn_id = conn->connector_id;
     drm_ctx.mode = conn->modes[0];
     // 优先选择横屏 mode（hdisplay >= vdisplay），避免 DSI 竖屏面板显示旋转
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
     // 竖屏面板：尝试 CRTC → CONNECTOR 查找 rotation property
     if (drm_ctx.mode.hdisplay < drm_ctx.mode.vdisplay) {
         bool rotated = false;
         for (int obj_type = 0; obj_type < 2; ++obj_type) {
             uint32_t obj_id = (obj_type == 0) ? drm_ctx.crtc_id : drm_ctx.conn_id;
             uint32_t drm_type = (obj_type == 0) ? DRM_MODE_OBJECT_CRTC : DRM_MODE_OBJECT_CONNECTOR;
             drmModeObjectPropertiesPtr props = drmModeObjectGetProperties(drm_ctx.fd, obj_id, drm_type);
             if (props) {
                 for (uint32_t i = 0; i < props->count_props && i < 64; i++) {
                     drmModePropertyPtr prop = drmModeGetProperty(drm_ctx.fd, props->props[i]);
                     if (prop && strcmp(prop->name, "rotation") == 0) {
                         drmModeObjectSetProperty(drm_ctx.fd, obj_id, drm_type,
                                                  props->props[i], DRM_MODE_ROTATE_90);
                         rotated = true;
                         drmModeFreeProperty(prop);
                         break;
                     }
                     if (prop) drmModeFreeProperty(prop);
                 }
                 drmModeFreeObjectProperties(props);
             }
             if (rotated) break;
         }
         if (!rotated) {
             printf("[DRM] 竖屏面板 (CRTC+Connector) 均无 rotation property，保持竖屏\n");
         }
     }
     drm_ctx.back_index = 1; 
     drmModeFreeResources(res);
     return 0;
 }
 
 /*
 * init_drm_ex — 按已连接屏幕索引选择目标屏幕进行 DRM 初始化
 * connector_idx: 0=第1个已连接屏幕, 1=第2个, ...
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
    drm_ctx.mode = conn->modes[0];
    // 优先选择横屏 mode（hdisplay >= vdisplay），避免 DSI 竖屏面板显示旋转
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
    // 竖屏面板旋转由 sync_to_screen 中的 RGA 硬件旋转统一处理，
    // 不再依赖 CRTC rotation property（Rockchip 平台可能不支持）
    drm_ctx.back_index = 1;
    drmModeFreeResources(res);
    return 0;
}
  
/*
 * =========================================================================
 * extern "C" 块 — Python ctypes 调用的动态库入口
 *
 * 以下四个函数通过 ctypes.CDLL 从 Python 侧直接调用：
 *   get_connected_connectors() → 检测所有已连接屏幕的名称列表
 *   init_hardware_pipeline()  → 全链路初始化（PCIe + RGA + DRM，默认第一屏幕）
 *   init_hardware_pipeline_ex(idx) → 全链路初始化（指定屏幕索引）
 *   fetch_next_frame()        → 取一帧 FPGA 图像，RGA 转换为 yolo + hd
 *   sync_to_screen(hd_ptr)    → hd 帧上屏（DRM page-flip）
 *   cleanup_hardware()       → 释放全部资源，恢复桌面
 *
 * C++ mangling 被 extern "C" 抑制，符号名与 Python 侧一致。
 * =========================================================================
 */
 extern "C" {
     /*
     * init_hardware_pipeline — 一次性初始化全链路硬件管线
     *
     * 执行顺序：
     *   1. open_pci_driver()            → 打开 PCIe 设备节点
     *   3. pci_map(cmd=3, TX=3MB, RX=10MB) → 向驱动注册 DMA 地址空间
     *   4. pci_mmp(cmd=3)               → mmap TX/RX 缓冲区到用户态
     *   5. malloc(FRAME_BLOCK_SIZE×2)   → 分配 RGA 输出双缓冲（~8MB）
     *   6. wrapbuffer_virtualaddr       → 预绑定 RGA 源/目标缓冲区句柄
     *   7. DMA 写 FPGA 配置寄存器        → 启动 FPGA 侧图像采集
     *   8. init_drm()                   → 接管显示输出
     *
     * 返回值：成功 0，任何步骤失败返回 -1。
     */

    /*
     * get_connected_connectors — 检测所有已连接的 DRM 屏幕
     * 返回值：已连接屏幕数量，-1 表示失败
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
     * init_hardware_pipeline_ex — 指定目标屏幕的全链路硬件管线初始化
     *
     * 与 init_hardware_pipeline() 的唯一区别：调用 init_drm_ex(connector_idx)
     * 而不是 init_drm()，从而允许选择第二个屏幕（例如 HDMI=1）而非默认第一个（DSI=0）。
     *
     * connector_idx: 0=第1个已连接屏幕, 1=第2个, ...
     * 返回值：成功 0，失败 -1。
     */
    int init_hardware_pipeline_ex(int connector_idx) {
         pci_driver_fd = open_pci_driver();
         if (pci_driver_fd < 0) return -1;
         if (pci_map(pci_driver_fd, 3, 1024*1024*3, 1024*1024*10) < 0) return -1;
         dma_operation.data = pci_mmp(pci_driver_fd, 3, 1024*1024*3, 1024*1024*10);
         rga_out_buf = malloc(FRAME_BLOCK_SIZE * 2);
         if (!rga_out_buf) return -1;
         void* fpga_base = (void*)dma_operation.data.read_buf;
         src_bufs[0] = wrapbuffer_virtualaddr(fpga_base, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_BGR_565);
         src_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)fpga_base + PING_PONG_OFFSET, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_BGR_565);
         void* py_base_0 = rga_out_buf;
         void* py_base_1 = (uint8_t*)rga_out_buf + FRAME_BLOCK_SIZE;
         yolo_bufs[0] = wrapbuffer_virtualaddr(py_base_0, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
         yolo_bufs[1] = wrapbuffer_virtualaddr(py_base_1, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
         hd_bufs[0] = wrapbuffer_virtualaddr((uint8_t*)py_base_0 + YOLO_SIZE, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         hd_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)py_base_1 + YOLO_SIZE, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
         ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = 0x003F4800;
         ptr32[4] = 0x00000001; ptr32[5] = 0x00000002; ptr32[6] = 0x00000003;
         pci_dma_single_write(pci_driver_fd, 0x20000080, 8,  4);
         pci_dma_single_write(pci_driver_fd, 0x200000c0, 12, 4);
         pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);
         pci_dma_single_write(pci_driver_fd, 0x20000040, 4,  4);
         buffer_index = 0;
         py_buffer_index = 0;
         if (init_drm_ex(connector_idx) < 0) return -1;
         return 0;
     }

    /*
     * init_pci_rga_pipeline — 仅初始化 PCIe + RGA，不接管 DRM
     *
     * 用于 Qt UI 内嵌预览：帧由 fetch_next_frame 获取后直接渲染到 Qt widget，
     * 无需 DRM page-flip，避免了与 lightdm 的 DRM master 冲突和竖屏问题。
     */
    int init_pci_rga_pipeline() {
         pci_driver_fd = open_pci_driver();
         if (pci_driver_fd < 0) return -1;
         if (pci_map(pci_driver_fd, 3, 1024*1024*3, 1024*1024*10) < 0) return -1;
         dma_operation.data = pci_mmp(pci_driver_fd, 3, 1024*1024*3, 1024*1024*10);
         rga_out_buf = malloc(FRAME_BLOCK_SIZE * 2);
         if (!rga_out_buf) return -1;
         void* fpga_base = (void*)dma_operation.data.read_buf;
         src_bufs[0] = wrapbuffer_virtualaddr(fpga_base, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_BGR_565);
         src_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)fpga_base + PING_PONG_OFFSET, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_BGR_565);
         void* py_base_0 = rga_out_buf;
         void* py_base_1 = (uint8_t*)rga_out_buf + FRAME_BLOCK_SIZE;
         yolo_bufs[0] = wrapbuffer_virtualaddr(py_base_0, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
         yolo_bufs[1] = wrapbuffer_virtualaddr(py_base_1, YOLO_WIDTH, YOLO_HEIGHT, RK_FORMAT_RGB_888);
         hd_bufs[0] = wrapbuffer_virtualaddr((uint8_t*)py_base_0 + YOLO_SIZE, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         hd_bufs[1] = wrapbuffer_virtualaddr((uint8_t*)py_base_1 + YOLO_SIZE, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
         ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = 0x003F4800;
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
     * fetch_next_frame — 从 FPGA 取一帧并完成 RGA 格式转换
     *
     * 数据流：
     *   ioctl(PCI_GET_IMG)  →  FPGA 侧 ping-pong buffer → src_bufs[src_idx]
     *           │
     *    pci_dma_single_write(ACK)  → 通知 FPGA 本帧已取，准备下一帧
     *           │
     *    improcess(src → yolo_bufs[dst_idx])  → BGR565 → RGB888, 缩放至 640×640
     *    improcess(src → hd_bufs[dst_idx])    → BGR565 → RGB888, 保持 1280×720
     *           │
     *    返回当前 rga_out_buf 中 yolo+hd 块的起始指针
     *
     * ping-pong 索引翻转：
     *   - buffer_index (FPGA 端): 每次读取后翻转，交替 ping/pong
     *   - py_buffer_index (Python 端): 每次 RGA 处理后翻转，输出块交替
     *
     * 返回值：成功返回 yolo+hd 内存块指针，失败返回 nullptr。
     */
    uint8_t* fetch_next_frame() {
         int ret = ioctl(pci_driver_fd, PCI_GET_IMG, &dma_operation);
         if (ret < 0) return nullptr; 
        //  pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);//双发ACK
        uint32_t fpga_ack_offset = buffer_index * 4 + 16; 
        pci_dma_single_write(pci_driver_fd, 0x20000000, fpga_ack_offset, 4);
         if (dma_operation.data.read_buf != NULL && dma_operation.data.read_buf != MAP_FAILED) {
             // 直接使用预绑定的索引，不再重复 wrapbuffer
             int src_idx = buffer_index; 
             int dst_idx = py_buffer_index;
             improcess(src_bufs[src_idx], yolo_bufs[dst_idx], {}, {0, 0, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT}, {0, 0, YOLO_WIDTH, YOLO_HEIGHT}, {}, 0, nullptr, nullptr, 0);
             improcess(src_bufs[src_idx], hd_bufs[dst_idx], {}, {0, 0, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT}, {0, 0, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT}, {}, 0, nullptr, nullptr, 0);
         }
  
         buffer_index = 1 - buffer_index;
         void* ret_ptr = (py_buffer_index == 0) ? rga_out_buf : (uint8_t*)rga_out_buf + FRAME_BLOCK_SIZE;
         py_buffer_index = 1 - py_buffer_index; 
         
         return (uint8_t*)ret_ptr; 
     }
  
     /*
     * sync_to_screen — 将 Python 端处理后的 HD 帧推送到物理屏幕
     *
     * 流程：
     *   1. wrapbuffer_virtualaddr 临时包装 hd_ptr 和 DRM dumb buffer 为 RGA 句柄
     *   2. improcess 使用 RGA 硬件将 1280×720 RGB888 → 屏幕分辨率 BGRA8888
     *   3. drmModePageFlip 异步翻页（双缓冲），不阻塞 CPU
     *   4. 翻转 back_index，下次写入另一块 buffer
     *
     * 参数 hd_ptr：fetch_next_frame() 返回的帧块中 hd 部分的偏移地址。
     */
    void sync_to_screen(uint8_t* hd_ptr) {
         if (!hd_ptr || drm_ctx.fd <= 0) return;
         rga_buffer_t py_hd_buf = wrapbuffer_virtualaddr(hd_ptr, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         rga_buffer_t drm_dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index], drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay, RK_FORMAT_BGRA_8888);
         im_rect drm_dst_rect = {0, 0, drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay};
         int im_usage = 0;
         if (drm_ctx.mode.hdisplay < drm_ctx.mode.vdisplay) {
             // 竖屏面板：RGA 硬件旋转 90°，1920×1080 源旋转后适配 1080×1920 缓冲区
             im_usage = IM_HAL_TRANSFORM_ROT_90;
         }
         improcess(py_hd_buf, drm_dst_buf, {}, {0, 0, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT}, drm_dst_rect, {}, 0, nullptr, nullptr, im_usage);
         
         drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index], DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
         drm_ctx.back_index = 1 - drm_ctx.back_index;
     }
  
     /*
     * gpio — 控制 FPGA 端 GPIO 引脚电平
     *
     * 参数：
     *   num   - GPIO 端口号 (对应 Linux gpio_direction_output 的 gpio 编号)
     *   value - 电平值 (0=低电平, 1=高电平)
     *
     * 返回值：成功 0，失败 -1。
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
     * 参数：
     *   num    - PWM 通道号 (2=左电机, 3=右电机)
     *   enable - 使能开关 (0=关闭, 1=开启)
     *   period - PWM 周期，单位纳秒 (ns)
     *   duty   - 占空比，百分比 0~100
     *
     * 返回值：成功 0，失败 -1。
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

    /*
     * init_drm_only — 仅初始化 DRM 屏幕输出（无需 PCIe/DMA，供 SD 卡等纯软件源使用）
     */
    int init_drm_only(int connector_idx) {
        return init_drm_ex(connector_idx);
    }

    /*
     * cleanup_drm_only — 仅释放 DRM 资源（不涉及 PCIe）
     */
    void cleanup_drm_only() {
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

    // ── SD 卡专用：RGA 硬件加速上屏（零 CPU 像素搬运 ──
    // 对标 sync_to_screen 的 RGA improcess 路径，替代原软件逐像素循环
    static const int SD_W = 1280, SD_H = 720;

    int sd_drm_init(int connector_idx) {
        return init_drm_ex(connector_idx);
    }

    int sd_drm_put_and_show(uint8_t* src_data) {
        if (!src_data || drm_ctx.fd <= 0) return -1;

        rga_buffer_t src_buf = wrapbuffer_virtualaddr(src_data, SD_W, SD_H, RK_FORMAT_RGB_888);
        rga_buffer_t dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index],
                                                       drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay,
                                                       RK_FORMAT_BGRA_8888);

        im_rect src_rect = {0, 0, SD_W, SD_H};
        im_rect dst_rect = {0, 0, (int)drm_ctx.mode.hdisplay, (int)drm_ctx.mode.vdisplay};

        int im_usage = 0;

        improcess(src_buf, dst_buf, {}, src_rect, dst_rect, {}, 0, nullptr, nullptr, im_usage);

        drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index],
                        DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
        drm_ctx.back_index = 1 - drm_ctx.back_index;
        return 0;
    }

    /*
     * sd_drm_put_and_show_ex — RGA 硬件加速上屏（动态分辨率，直通 BGR）
     *
     * 与 sd_drm_put_and_show 的区别：
     *   - 接受任意分辨率的 BGR888 输入（OpenCV cv2.VideoCapture 原生格式）
     *   - RGA 内部完成 BGR→BGRA 转换 + 缩放至屏幕分辨率
     *   - Python 侧无需做 cv2.resize + cv2.cvtColor，零 CPU 像素搬运
     *
     * 参数：
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

        int im_usage = 0;

        improcess(src_buf, dst_buf, {}, src_rect, dst_rect, {}, 0, nullptr, nullptr, im_usage);

        drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index],
                        DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
        drm_ctx.back_index = 1 - drm_ctx.back_index;
        return 0;
    }

    void sd_drm_cleanup() {
        cleanup_drm_only();
    }

    /*
     * cleanup_hardware — 释放全部硬件资源，恢复原始显示状态
     *
     * 释放顺序（逆初始化）：
     *   1. free(rga_out_buf)               → 释放 RGA 输出双缓冲
     *   2. drmModeSetCrtc(原始 CRTC)       → 恢复 X11/Wayland 桌面显示
     *   3. munmap + drmModeRmFB            → 释放两块 DRM dumb buffer
     *   4. DRM_IOCTL_MODE_DESTROY_DUMB     → 内核侧销毁 dumb buffer
     *   5. close(drm_ctx.fd)               → 关闭 DRM 设备
     *   6. pci_umap + close(pci_driver_fd) → 释放 PCIe mmap 并关闭设备
     */
    void cleanup_hardware() {
         if (rga_out_buf) { free(rga_out_buf); rga_out_buf = nullptr; }
         // 不恢复 CRTC：saved_crtc 的 buffer_id 来自 lightdm，接管后可能已被释放，
         // drmModeSetCrtc 回去会触发内核 Oops。关闭 fd 后 DRM 框架会自动回收 CRTC。
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
        if (pci_driver_fd >= 0) { pci_umap(pci_driver_fd); close(pci_driver_fd); pci_driver_fd = -1; }
    }
}