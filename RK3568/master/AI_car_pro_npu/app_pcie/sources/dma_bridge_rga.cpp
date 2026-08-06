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
 int pci_driver_fd = -1;                         // PCIe 驱动设备文件描述符
 COMMAND_OPERATION command_operation;             // 控制命令结构体（ioctl/read 复用）
 DMA_OPERATION dma_operation;                     // DMA 操作结构体（ioctl 复用）
 
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
 // PCIe 底层驱动函数实现 
 // =========================================================================
 
 /*
 * open_pci_driver — 打开 PCIe 驱动设备节点，获取用户态操作句柄
 *
 * 通过 open() 系统调用打开 PCIE_DRIVER_FILE_PATH（如 /dev/pcie_dma_driver），
 * 以读写模式获取 fd，后续所有 ioctl / read / mmap 操作均通过此 fd 完成。
 *
 * 返回值：成功返回 fd（≥0），失败返回 -1。
 */
int open_pci_driver(void)
 {
     int fd;
     fd = open(PCIE_DRIVER_FILE_PATH, O_RDWR);
     if(fd < 0)
     {
         perror("open fail\n");
         return -1;
     }
     return fd;
 }
 
/*
 * cmd_operation — 向 PCIe 驱动发起控制命令，读取设备信息或触发性能测试
 *
 * 数据流：
 *   [调用方] --fd,cmd,cmd_op--> [ioctl/read 透传到驱动]
 *                                      |
 *                              驱动填充 cmd_op
 *                                      |
 *                              [调用方读取结果]
 *
 * 参数：
 *   fd      - PCIe 驱动设备文件描述符，通过 open() 获取
 *   cmd     - 操作类型，对应枚举 op_num 的值：
 *               info_num        → 读取设备硬件信息（vendor、device、链路状态、BAR等）
 *               performance_num → 触发 PCIe 性能测试（DMA 读写吞吐、误码统计）
 *   cmd_op  - 入参：携带命令参数（如 delay 延迟）；出参：驱动返回的设备信息或测试结果
 *
 * pci_info[][] 的作用域：
 *   仅在 info_num 分支内被写入，写入 20 个字符串字段，覆盖：
 *     [0]  Vendor ID（十六进制）
 *     [1]  Device ID（十六进制）
 *     [2]  PCIe 链路状态（"Up"/"Down"）
 *     [3]  PCIe Gen 速率（Gen1/Gen2/Gen3）
 *     [4]  链路宽度（x1/x4/x8/x16）
 *     [5]  预留字段（当前填 "No"）
 *     [6–11] BAR0–BAR5 基地址（物理地址，十六进制）
 *     [12–17] BAR0–BAR5 资源长度（带单位 B/KB/MB/GB/TB，自动换档）
 *     [18] Max Payload Size
 *     [19] Max Read Request Size
 *   注意：当前实现仅写入未做后续消费，属于调试/保留字段，可被外部扩展使用。
 */
//  void cmd_operation(int fd, unsigned char cmd, COMMAND_OPERATION *cmd_op)
//  {
//      unsigned int i = 0;                
//      unsigned int cnt = 0;              
//      unsigned long temp_bar_len;        
//      int value = 0;                     
//      char pci_info[20][20];             
//      char unit[5][10] = {"B", "KB", "MB", "GB", "TB"};
 
//      switch(cmd)
//      {
//          case info_num:
//              // 清空 delay，确保驱动按无延迟模式返回信息
//             cmd_op->delay = 0;
//              // 通过 read 系统调用将命令下发至驱动，驱动在内核态填充 cmd_op 的全部字段
//             read(fd, cmd_op, sizeof(COMMAND_OPERATION));
//             // ---- 采集并格式化设备信息至 pci_info[] ----

//             // [0] Vendor ID：厂商识别码（4 位十六进制）
//              sprintf(pci_info[cnt++], "%04x", cmd_op->get_pci_dev_info.vendor_id);
//             // [1] Device ID：设备识别码（4 位十六进制）
//              sprintf(pci_info[cnt++], "%04x", cmd_op->get_pci_dev_info.device_id);
 
//             // [2] 链路状态：cap_status == 1 表示 PCIe 链路训练成功
//              if(cmd_op->cap_info.cap_status == 1)
//              {
//                  strcpy(pci_info[cnt++],  "Up");
//                  printf("PCIe link successful\n");
//              }
//              else
//              {
//                  strcpy(pci_info[cnt++],  "Down");
//                  printf("PCIe link failure !!!\n");
//              }
 
//             // [3] 链路速率：Gen1/Gen2/Gen3...（整数代次）
//              sprintf(pci_info[cnt++], "Gen%x", cmd_op->get_pci_dev_info.link_speed);
//             // [4] 链路宽度：x1/x2/x4/x8/x16...（通道数）
//              sprintf(pci_info[cnt++], "x%x", cmd_op->get_pci_dev_info.link_width);
//             // [5] 预留字段，暂时写死为 "No"
//              strcpy(pci_info[cnt++],  "No");
 
//              for(i = 0; i <= 5; i++)
//              {
//                  // 依次输出 BAR0–BAR5 物理基地址，%08lx 保证 8 位十六进制宽度
//                  sprintf(pci_info[cnt++], "%08lx", cmd_op->get_pci_dev_info.bar[i].bar_base);
//              }
 
//              for(i = 0; i <= 5; i++)
//              {
//                  value = 0;
//                  temp_bar_len = cmd_op->get_pci_dev_info.bar[i].bar_len;
//                  // 每次除以 1024 升一档单位（B→KB→MB→GB→TB），直到 < 1024
//                  while(temp_bar_len >= 1024)
//                  {
//                      temp_bar_len = temp_bar_len / 1024;
//                      value++;
//                  }
//                  // 格式化为 "数值+单位"，例如 "256MB"、"1GB"、"4096B"
//                  sprintf(pci_info[cnt++], "%ld%s", temp_bar_len, unit[value]);
//              }
 
//             // [18] Max Payload Size：PCIe TLP 最大有效载荷字节数
//              sprintf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mps);
//             // [19] Max Read Request Size：PCIe 最大读请求字节数
//              sprintf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mrrs);
//              break;
 
//          case performance_num:
//              // 性能测试分支：驱动侧在此 case 下填充 cmd_op 的读写吞吐、延迟、误码率等字段
//              // 当前为空实现，预留扩展
//              break;
 
//          default:
//              // 未知命令，不操作
//              break;
//      }
//  }
 
 /*
 * pci_dma_single_write — 通过 PCIe DMA 将少量控制数据写入 FPGA 寄存器（单次 4/8/12/24 字节）
 *
 * 向 FPGA 侧指定 MMP 偏移地址写入 small payload，通常用于：
 *   - 配置寄存器
 *   - ACK 信号
 *   - 状态清除
 *
 * 参数：
 *   pci_driver_fd  - PCIe 驱动 fd
 *   start_ddr3_addr - FPGA 侧 DDR3 目标基地址
 *   mmp_offset      - FPGA 内 MMP 寄存器偏移
 *   total_size      - 写入字节数
 */
int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
 {
     dma_operation.offset_addr   = mmp_offset;
     dma_operation.ddr3_addr     = start_ddr3_addr;
     dma_operation.total_length  = total_size;
 
     int ret = ioctl(pci_driver_fd, PCI_DMA_READ_CMD, &dma_operation);
     if (ret < 0) return -1;
     return 0;
 }
 
 /*
 * pci_dma_single_read — 通过 PCIe DMA 从 FPGA 读取数据块到用户态内存
 *
 * 通过 ioctl(PCI_DMA_WRITE_CMD) 发起 FPGA → Host 方向的 DMA 传输，
 * 实际方向由 PCIe RC 端配置决定：此函数 "read" 指 Host 读入 FPGA 数据。
 *
 * 参数：
 *   pci_driver_fd  - PCIe 驱动 fd
 *   start_ddr3_addr - FPGA 侧 DDR3 源基地址
 *   mmp_offset      - 需要映射的偏移（与 write 对称）
 *   total_size      - 读取字节数
 */
int pci_dma_single_read(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
 {
     dma_operation.offset_addr  = mmp_offset;
     dma_operation.ddr3_addr    = start_ddr3_addr;
     dma_operation.total_length = total_size;
 
     int ret = ioctl(pci_driver_fd, PCI_DMA_WRITE_CMD, &dma_operation);
     if (ret < 0)
     {
         printf("PCI_DMA_WRITE_CMD 失败! 目标地址: 0x%08X, 错误码: %d (%s)\n",
                start_ddr3_addr, errno, strerror(errno));
         return -1;
     }
     return 0;
 }
 
 /*
 * pci_mmp — 将 PCIe BAR 空间 mmap 到用户态，返回可读写的 TX/RX 缓冲区指针
 *
 * cmd 控制映射方向：
 *   0 → 仅映射 TX 写缓冲（offset=0）
 *   1 → 仅映射 RX 读缓冲（offset=RX_MMAP_OFFSET，通常为 3MB）
 *   3 → 同时映射 TX + RX（双通道模式，用于零拷贝管线）
 *
 * 映射长度向上对齐到页边界（getpagesize()）。
 */
DMA_DATA pci_mmp(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx){
     DMA_DATA mmp = {};
     unsigned long page_size = getpagesize();
     unsigned long mmap_size_tx = (total_size_tx + page_size - 1) & ~(page_size - 1);
     unsigned long mmap_size_rx = (total_size_rx + page_size - 1) & ~(page_size - 1);
 
     if(cmd == 0){
         mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
         if (mmp.write_buf == MAP_FAILED) {
             printf("mmap TX buffer failed!\n");
         }
     }
     else if(cmd == 1){
         mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
         if (mmp.read_buf == MAP_FAILED) {
             printf("mmap RX buffer failed!\n");
         }
     }
     else if(cmd == 3){
         mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
         if (mmp.write_buf == MAP_FAILED) {
             printf("mmap TX buffer failed!\n");
         }
         mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
         if (mmp.read_buf == MAP_FAILED) {
             printf("mmap RX buffer failed!\n");
         }
     }
     return mmp; 
 }
 
 /*
 * pci_umap — 释放 PCIe mmap 映射（设置 cmd=3 请求驱动端清理）
 *
 * 在关闭驱动或重新初始化前调用，确保内核侧 DMA 上下文被正确回收。
 * 失败时打印 errno 信息但不改变程序流。
 */
int pci_umap(int pci_driver_fd){
     int ret;
     dma_operation.cmd = 3;
     ret = ioctl(pci_driver_fd, PCI_UMAP_ADDR_CMD, &dma_operation);
     if (ret < 0) {
         printf("PCI_UMAP_ADDR_CMD 释放缓存失败! 错误码: %d (%s)\n", errno, strerror(errno));
         return -1;
     }
     return 0;
 }
 
 /*
 * pci_map — 向内核驱动注册 DMA 地址空间（mmap 的前置条件）
 *
 * 通过 ioctl(PCI_MAP_ADDR_CMD) 告知驱动端需要映射的缓冲区大小，
 * 驱动在内核态分配/锁定 DMA 地址，后续 pci_mmp() 才能成功 mmap。
 *
 * cmd 控制注册方向：
 *   0 → 仅注册 TX（写）方向
 *   1 → 仅注册 RX（读）方向
 *   3 → 同时注册 TX + RX
 *
 * 失败时自动调用 pci_umap 回滚已注册的映射。
 */
int pci_map(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx){
     int ret;
     if(cmd == 0) {
         dma_operation.cmd = 0;
         dma_operation.total_length = total_size_tx;
         ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
         if (ret < 0) { pci_umap(pci_driver_fd); return -1; }
     }
     else if(cmd == 1) {
         dma_operation.cmd = 1;
         dma_operation.total_length = total_size_rx; 
         ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
         if (ret < 0) { pci_umap(pci_driver_fd); return -1; }
     }
     else if(cmd == 3) {
         dma_operation.cmd = 0;
         dma_operation.total_length = total_size_tx;
         ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
         if (ret < 0) { pci_umap(pci_driver_fd); return -1; }
 
         dma_operation.cmd = 1;
         dma_operation.total_length = total_size_rx;
         ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
         if (ret < 0) { pci_umap(pci_driver_fd); return -1; }
     }
     return 0;
 }
 
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
    //  *   2. cmd_operation(info_num)      → 查询并打印 PCIe 链路状态
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
         pci_driver_fd = open_pci_driver();
         if (pci_driver_fd < 0) return -1;
         
         // 打印一下连接状态，确保底层正常工作
         cmd_operation(pci_driver_fd, info_num, &command_operation);
 
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
  
         // ---- 配置 FPGA 侧图像采集寄存器 ----
        // 通过 DMA 单次写入配置 FPGA 内部寄存器：
        //   ptr32[1..3] → 0x20000080（图像采集参数）
        //   ptr32[4..6] → 0x200000c0（色彩/格式参数）
        //   0 → 0x20000000（ACK/状态清除）
        //   1 → 0x20000040（启动采集使能）
        unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
         ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = 0x003F4800;
         ptr32[4] = 0x00000001; ptr32[5] = 0x00000002; ptr32[6] = 0x00000003;
         pci_dma_single_write(pci_driver_fd, 0x20000080, 8,  4);
         pci_dma_single_write(pci_driver_fd, 0x200000c0, 12, 4);
         pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4); // 清空状态
         pci_dma_single_write(pci_driver_fd, 0x20000040, 4,  4);
 
         buffer_index = 0; 
         py_buffer_index = 0;
         if (init_drm() < 0) return -1;
         return 0;
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
        //  cmd_operation(pci_driver_fd, info_num, &command_operation);
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
        //  cmd_operation(pci_driver_fd, info_num, &command_operation);
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

    int pci_adc_read(int channel) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        ADC_CHANNEL adc = {0};
        adc.channel = (unsigned int)channel;
        int ret = ioctl(pci_driver_fd, PCI_ADC_READ_CMD, &adc);
        if (ret < 0) return -1;
        return (int)adc.voltage_mv;
    }

    int pci_spi_xfer(unsigned int cs, unsigned char* tx, unsigned int tx_len,
                     unsigned char* rx, unsigned int rx_len) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        SPI_TRANSFER spi = {0};
        spi.cs_pin = cs;
        spi.tx_len = tx_len > 256 ? 256 : tx_len;
        spi.rx_len = rx_len > 256 ? 256 : rx_len;
        if (tx && spi.tx_len) memcpy(spi.tx_buf, tx, spi.tx_len);
        int ret = ioctl(pci_driver_fd, PCI_SPI_BUS_CMD, &spi);
        if (ret < 0) return -1;
        if (rx && spi.rx_len) memcpy(rx, spi.rx_buf, spi.rx_len);
        return 0;
    }

    int pci_can_send(CAN_MESSAGE* msg) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0 || !msg) return -1;
        return ioctl(pci_driver_fd, PCI_CAN_BUS_CMD, msg);
    }

    int pci_imu_read(IMU_DATA* imu) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0 || !imu) return -1;
        return ioctl(pci_driver_fd, PCI_IMU_READ_CMD, imu);
    }

    int pci_ultrasonic_read(int sensor_id, ULTRASONIC_DATA* data) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0 || !data) return -1;
        data->sensor_id = (unsigned int)sensor_id;
        return ioctl(pci_driver_fd, PCI_ULTRASONIC_CMD, data);
    }

    int pci_get_sensor_fusion(SENSOR_FUSION* fusion) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0 || !fusion) return -1;
        memset(fusion, 0, sizeof(SENSOR_FUSION));
        pci_imu_read(&fusion->imu);
        for (int i = 0; i < 4; i++) {
            pci_ultrasonic_read(i, &fusion->ultrasonic[i]);
        }
        return 0;
    }

    int pci_i2c_write(unsigned char addr, unsigned char reg,
                      unsigned char* data, unsigned int len) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        struct { unsigned char addr; unsigned char reg; unsigned int len; unsigned char data[64]; } i2c = {0};
        i2c.addr = addr;
        i2c.reg = reg;
        i2c.len = len > 64 ? 64 : len;
        if (data && i2c.len) memcpy(i2c.data, data, i2c.len);
        return ioctl(pci_driver_fd, PCI_I2C_BUS_CMD, &i2c);
    }

#define PCI_NPU_UPLOAD_CMD      _IOWR('S', 16, int)
#define PCI_NPU_START_CMD       _IOWR('S', 17, int)
#define PCI_NPU_GET_OUTPUT_CMD  _IOWR('S', 18, int)

    typedef struct {
        unsigned int instr_ddr3_addr;
        unsigned int instr_total_size;
        unsigned int output_ddr3_addr;
        unsigned int output_total_size;
        unsigned int output_host_offset;
    } NPU_CONFIG;

    int pci_npu_upload_instr(uint32_t fpga_ddr3_addr, uint32_t instr_size) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        NPU_CONFIG npu_cfg = {};
        npu_cfg.instr_ddr3_addr = fpga_ddr3_addr;
        npu_cfg.instr_total_size = instr_size;
        int ret = ioctl(pci_driver_fd, PCI_NPU_UPLOAD_CMD, &npu_cfg);
        if (ret < 0) {
            printf("PCI_NPU_UPLOAD_CMD failed! %s\n", strerror(errno));
            return -1;
        }
        return 0;
    }

    int pci_npu_start_and_wait(uint32_t output_ddr3_addr, uint32_t output_size, uint32_t output_host_offset) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        NPU_CONFIG npu_cfg = {};
        npu_cfg.instr_ddr3_addr = NPU_INSTR_DDR3_BASE;
        npu_cfg.output_ddr3_addr = output_ddr3_addr;
        npu_cfg.output_total_size = output_size;
        npu_cfg.output_host_offset = output_host_offset;
        if (ioctl(pci_driver_fd, PCI_NPU_UPLOAD_CMD, &npu_cfg) < 0) return -1;
        if (ioctl(pci_driver_fd, PCI_NPU_START_CMD, &npu_cfg) < 0) {
            printf("NPU start failed! %s\n", strerror(errno));
            return -1;
        }
        return 0;
    }

    int pci_npu_read_output(uint32_t fpga_ddr3_addr, uint32_t output_size, uint32_t host_offset) {
        if (pci_driver_fd < 0) pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        NPU_CONFIG npu_cfg = {};
        npu_cfg.instr_ddr3_addr = NPU_INSTR_DDR3_BASE;
        npu_cfg.output_ddr3_addr = fpga_ddr3_addr;
        npu_cfg.output_total_size = output_size;
        npu_cfg.output_host_offset = host_offset;
        if (ioctl(pci_driver_fd, PCI_NPU_GET_OUTPUT_CMD, &npu_cfg) < 0) {
            printf("NPU read output failed! %s\n", strerror(errno));
            return -1;
        }
        return 0;
    }
 }