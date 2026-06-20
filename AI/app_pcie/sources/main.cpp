/**
 * @file main.cpp
 * @brief PCIe DMA -> RGA -> DRM 纯硬件零拷贝极速视频流 (脱离 OpenCV 版 - 双缓冲防撕裂完整版)
 */

#include "../includes/pcie_dma_read_test.h"
#include <iostream>
#include <chrono>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <string.h>

// --- DRM 显示库 ---
#include <xf86drm.h>
#include <xf86drmMode.h>

// --- RGA 硬件加速 ---
#include <rga/RgaApi.h>
#include <rga/im2d.h>


#include <math.h>   // 需要用到 fabs()
#include <float.h>  // 需要用到 FLT_MAX

using namespace std;

const int IMG_WIDTH  = 1280;
const int IMG_HEIGHT = 720;
const uint32_t FRAME_SIZE_BYTES  = IMG_WIDTH * IMG_HEIGHT * 2; 
const uint32_t PING_PONG_OFFSET  = 0x1C2000;                   

int pci_driver_fd;
COMMAND_OPERATION command_operation;
DMA_OPERATION dma_operation;

// =========================================================================
// 驱动基础接口声明
// =========================================================================
int open_pci_driver(void);
void cmd_operation(int fd, unsigned char cmd, COMMAND_OPERATION *cmd_op);
int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size);
int pci_dma_single_read(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size);
int pci_map(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx);
int pci_umap(int pci_driver_fd);
DMA_DATA pci_mmp(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx);


// =========================================================================
// 原有驱动基础函数实现 (完全保留)
// =========================================================================

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

void cmd_operation(int fd, unsigned char cmd, COMMAND_OPERATION *cmd_op)
{
    unsigned int w_data = 0;           
    unsigned int r_data = 0;           
    unsigned int i = 0;                
    unsigned int j = 0;                
    unsigned int cnt = 0;              
    unsigned long temp_bar_len;        
    int value = 0;                     
    char pci_info[20][20];             
    char unit[5][10] = {"B", "KB", "MB", "GB", "TB"};
    void *vaddr1, *vaddr2;             

    switch(cmd)
    {
        case info_num:
            cmd_op->delay = 0;
            read(fd, cmd_op, sizeof(COMMAND_OPERATION));
            sprintf(pci_info[cnt++], "%04x", cmd_op->get_pci_dev_info.vendor_id);
            sprintf(pci_info[cnt++], "%04x", cmd_op->get_pci_dev_info.device_id);

            if(cmd_op->cap_info.cap_status == 1)
            {
                strcpy(pci_info[cnt++],  "Up");
                printf("PCIe link successful\n");
                printf("PCIe link successful\n");
            }
            else
            {
                strcpy(pci_info[cnt++],  "Down");
                printf("PCIe link failure !!!\n");
                printf("PCIe link failure !!!\n");
            }

            sprintf(pci_info[cnt++], "Gen%x", cmd_op->get_pci_dev_info.link_speed);
            sprintf(pci_info[cnt++], "x%x", cmd_op->get_pci_dev_info.link_width);
            strcpy(pci_info[cnt++],  "No");

            for(i = 0; i <= 5; i++)
            {
                sprintf(pci_info[cnt++], "%08lx", cmd_op->get_pci_dev_info.bar[i].bar_base);
            }

            for(i = 0; i <= 5; i++)
            {
                value = 0;
                temp_bar_len = cmd_op->get_pci_dev_info.bar[i].bar_len;
                while(temp_bar_len >= 1024)
                {
                    temp_bar_len = temp_bar_len / 1024;
                    value++;
                }
                printf(pci_info[cnt++], "%d%s", temp_bar_len, unit[value]);
            }

            printf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mps);
            printf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mrrs);
            break;

        case performance_num:
            break;

        default:
            break;
    }
}

int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
{
    int msi_ret = 0;
    dma_operation.offset_addr   = mmp_offset;
    dma_operation.ddr3_addr     = start_ddr3_addr;
    dma_operation.total_length  = total_size;

    int ret = ioctl(pci_driver_fd, PCI_DMA_READ_CMD, &dma_operation);
    if (ret < 0)
    {
        printf("PCI_DMA_READ_CMD 失败! 目标地址: 0x%08X, 错误码: %d (%s)\n",
               start_ddr3_addr, errno, strerror(errno));
        return -1;
    }
    return 0;
}

int pci_dma_single_read(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
{
    int msi_ret = 0;
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

DMA_DATA pci_mmp(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx){
    DMA_DATA mmp;
    unsigned long page_size = getpagesize();
    unsigned long mmap_size_tx = (total_size_tx + page_size - 1) & ~(page_size - 1);
    unsigned long mmap_size_rx = (total_size_rx + page_size - 1) & ~(page_size - 1);

    if(cmd == 0){
        mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
        if (mmp.write_buf == MAP_FAILED) {
            printf("mmap TX buffer failed!\n");
        }
        printf("内核空间TX映射地址:%p, 映射大小:%ld\n", mmp.write_buf, mmap_size_tx);
    }
    else if(cmd == 1){
        mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
        if (mmp.read_buf == MAP_FAILED) {
            printf("mmap RX buffer failed!\n");
        }
        printf("内核空间RX映射地址:%p, 映射大小:%ld\n", mmp.read_buf, mmap_size_rx);
    }
    else if(cmd == 3){
        mmp.write_buf = mmap(NULL, mmap_size_tx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, 0);
        if (mmp.write_buf == MAP_FAILED) {
            printf("mmap TX buffer failed!\n");
        }
        printf("内核空间TX映射地址:%p, 映射大小:%ld\n", mmp.write_buf, mmap_size_tx);

        mmp.read_buf = mmap(NULL, mmap_size_rx, PROT_READ | PROT_WRITE, MAP_SHARED, pci_driver_fd, RX_MMAP_OFFSET);
        if (mmp.read_buf == MAP_FAILED) {
            printf("mmap RX buffer failed!\n");
        }
        printf("内核空间RX映射地址:%p, 映射大小:%ld\n", mmp.read_buf, mmap_size_rx);
    }
    
    return mmp; 
}

int pci_umap(int pci_driver_fd){
    int ret;
    dma_operation.cmd = 3;
    ret = ioctl(pci_driver_fd, PCI_UMAP_ADDR_CMD, &dma_operation);
    if (ret < 0) {
        printf("PCI_UMAP_ADDR_CMD 释放缓存失败! 警告: 可能发生内存泄漏! 错误码: %d (%s)\n", errno, strerror(errno));
        return -1;
    }
    printf("PCI_UMAP_ADDR_CMD 释放缓存成功! \n");
    return 0;
}

int pci_map(int pci_driver_fd, int cmd, uint32_t total_size_tx, uint32_t total_size_rx){
    int ret;
    if(cmd == 0) {
        dma_operation.cmd = 0;
        dma_operation.total_length = total_size_tx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            printf("DMA MAP TX 失败! 错误码: %d (%s)\n", errno, strerror(errno));
            pci_umap(pci_driver_fd);
            return -1;
        }
        printf("DMA MAP TX 完成: 内核开辟空间大小 [%u bytes]\n", total_size_tx);
    }
    else if(cmd == 1) {
        dma_operation.cmd = 1;
        dma_operation.total_length = total_size_rx; 
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            printf("DMA MAP RX 失败! 错误码: %d (%s)\n", errno, strerror(errno));
            pci_umap(pci_driver_fd);
            return -1;
        }
        printf("DMA MAP RX 完成: 内核开辟空间大小 [%u bytes]\n", total_size_rx);
    }
    else if(cmd == 3) {
        dma_operation.cmd = 0;
        dma_operation.total_length = total_size_tx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            printf("DMA MAP TX 失败! 错误码: %d (%s)\n", errno, strerror(errno));
            pci_umap(pci_driver_fd);
            return -1;
        }
        printf("DMA MAP TX 完成: 内核开辟空间大小 [%u bytes]\n", total_size_tx);

        dma_operation.cmd = 1;
        dma_operation.total_length = total_size_rx;
        ret = ioctl(pci_driver_fd, PCI_MAP_ADDR_CMD, &dma_operation);
        if (ret < 0) {
            printf("DMA MAP RX 失败! 错误码: %d (%s)\n", errno, strerror(errno));
            pci_umap(pci_driver_fd);
            return -1;
        }
        printf("DMA MAP RX 完成: 内核开辟空间大小 [%u bytes]\n", total_size_rx);
    }
    return 0;
}

// =========================================================================
// 【核心修改】双缓冲 DRM 封装层
// =========================================================================
struct DrmContext {
    int fd;
    int current_buffer;        
    uint32_t crtc_id;          
    drmModeCrtc* saved_crtc;
    uint32_t screen_width;  
    uint32_t screen_height; 
    
    uint32_t handle[2];        
    uint32_t fb_id[2];         
    int prime_fd[2];           
};



/*
DrmContext init_drm_display() {
    DrmContext ctx = {};
    ctx.fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (ctx.fd < 0) {
        fprintf(stderr, "无法打开 /dev/dri/card0\n");
        return ctx;
    }

    // 1. 获取显卡的所有资源
    drmModeRes *res = drmModeGetResources(ctx.fd);
    if (!res) {
        fprintf(stderr, "无法获取 DRM 资源\n");
        return ctx;
    }

    // 2. 遍历并找到第一个已连接的屏幕
    drmModeConnector *conn = nullptr;
    uint32_t my_connector_id = 0;
    
    for (int i = 0; i < res->count_connectors; i++) {
        conn = drmModeGetConnector(ctx.fd, res->connectors[i]);
        if (conn && conn->connection == DRM_MODE_CONNECTED) {
            my_connector_id = conn->connector_id;
            break;
        }
        drmModeFreeConnector(conn);
        conn = nullptr;
    }

    if (!conn) {
        fprintf(stderr, "未找到已连接的屏幕！\n");
        drmModeFreeResources(res);
        return ctx;
    }

    // 3. 寻找驱动这块屏幕的 CRTC
    drmModeEncoder *enc = nullptr;
    if (conn->encoder_id) {
        enc = drmModeGetEncoder(ctx.fd, conn->encoder_id);
    } 
    
    if (!enc && conn->count_encoders > 0) {
        enc = drmModeGetEncoder(ctx.fd, conn->encoders[0]);
    }

    if (enc) {
        ctx.crtc_id = enc->crtc_id;
        drmModeFreeEncoder(enc);
    } else {
        fprintf(stderr, "无法为该屏幕找到合适的 Encoder/CRTC！\n");
        drmModeFreeConnector(conn);
        drmModeFreeResources(res);
        return ctx;
    }

    drmModeFreeResources(res);
    ctx.saved_crtc = drmModeGetCrtc(ctx.fd, ctx.crtc_id);

    // ------------------- 核心修改：寻找最接近 30.18Hz 的模式 -------------------
    int target_mode_index = 0; // 默认使用 modes[0] 作为保底
    float target_fps = 60.00f;
    float min_diff = FLT_MAX; // 记录最小误差
    float best_exact_refresh = 0.0f;

    for (int i = 0; i < conn->count_modes; i++) {
        drmModeModeInfo *mode = &conn->modes[i];
        
        // 防止除以 0 的异常情况
        if (mode->htotal == 0 || mode->vtotal == 0) continue;

        // 计算精确刷新率 (mode->clock 的单位是 kHz，所以要乘以 1000)
        float exact_refresh = (mode->clock * 1000.0f) / (mode->htotal * mode->vtotal);
        
        // 计算与目标帧率的差距
        float diff = fabs(exact_refresh - target_fps);

        // 找出差距最小的一个
        if (diff < min_diff) {
            min_diff = diff;
            target_mode_index = i;
            best_exact_refresh = exact_refresh;
        }
    }

    // 提取选中的模式
    drmModeModeInfo target_mode = conn->modes[target_mode_index];
    uint32_t real_w = target_mode.hdisplay; 
    uint32_t real_h = target_mode.vdisplay; 
    ctx.screen_width = real_w;
    ctx.screen_height = real_h;

    // 如果误差小于 1Hz，我们认为找到了目标附近的分辨率
    if (min_diff < 1.0f) {
        printf("✅ 成功找到最接近 30.18Hz 的模式: %dx%d @ %.2fHz (误差: %.2fHz)\n", 
               real_w, real_h, best_exact_refresh, min_diff);
    } else {
        printf("⚠️ 你的显示器不支持接近 30.18Hz 的刷新率。被迫选择最接近的: %dx%d @ %.2fHz\n", 
               real_w, real_h, best_exact_refresh);
    }
    // -------------------------------------------------------------------------

    // 5. 创建双缓冲 (Dumb Buffer) 并导出 DMA-BUF (Prime FD)
    for (int i = 0; i < 2; i++) {
        struct drm_mode_create_dumb creq = {};
        creq.width = real_w;
        creq.height = real_h;
        creq.bpp = 32; 
        ioctl(ctx.fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq);

        ctx.handle[i] = creq.handle;
        drmModeAddFB(ctx.fd, real_w, real_h, 24, 32, creq.pitch, creq.handle, &ctx.fb_id[i]);
        
        drmPrimeHandleToFD(ctx.fd, creq.handle, DRM_CLOEXEC, &ctx.prime_fd[i]);
    }

    printf("准备在 CRTC %d 上点亮模式: %dx%d (标称刷新率: %dHz，实际: %.2fHz)\n", 
           ctx.crtc_id, real_w, real_h, target_mode.vrefresh, best_exact_refresh);
    
    // 6. 提交显示 (SetCrtc)
    ctx.current_buffer = 0;
    
    int ret = drmModeSetCrtc(ctx.fd, ctx.crtc_id, ctx.fb_id[0], 0, 0, &my_connector_id, 1, &target_mode);
    if (ret < 0) {
        fprintf(stderr, "drmModeSetCrtc 失败: %s (错误码: %d)\n", strerror(errno), errno);
    } else {
        printf("✅ 屏幕已点亮！Connector ID: %d, CRTC ID: %d\n", my_connector_id, ctx.crtc_id);
    }

    // 释放屏幕对象
    drmModeFreeConnector(conn);
    return ctx;
}
*/
DrmContext init_drm_display() {
    DrmContext ctx = {};
    ctx.fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (ctx.fd < 0) {
        fprintf(stderr, "无法打开 /dev/dri/card0\n");
        return ctx;
    }

    // 1. 获取显卡的所有资源（包含所有的连接器、编码器、CRTC 等）
    drmModeRes *res = drmModeGetResources(ctx.fd);
    if (!res) {
        fprintf(stderr, "无法获取 DRM 资源\n");
        return ctx;
    }

    // 2. 遍历并找到第一个已连接的屏幕
    drmModeConnector *conn = nullptr;
    uint32_t my_connector_id = 0;
    
    for (int i = 0; i < res->count_connectors; i++) {
        conn = drmModeGetConnector(ctx.fd, res->connectors[i]);
        if (conn && conn->connection == DRM_MODE_CONNECTED) {
            my_connector_id = conn->connector_id;
            break; // 找到第一个已连接的就跳出循环
        }
        drmModeFreeConnector(conn);
        conn = nullptr;
    }

    if (!conn) {
        fprintf(stderr, "未找到已连接的屏幕！\n");
        drmModeFreeResources(res);
        return ctx;
    }

    // 3. 寻找驱动这块屏幕的 CRTC
    // 首先尝试获取当前绑定的 Encoder
    drmModeEncoder *enc = nullptr;
    if (conn->encoder_id) {
        enc = drmModeGetEncoder(ctx.fd, conn->encoder_id);
    } 
    
    // 如果当前没有绑定 Encoder（比如屏幕刚插上还未初始化），则遍历支持的 Encoder 随便挑一个
    if (!enc && conn->count_encoders > 0) {
        enc = drmModeGetEncoder(ctx.fd, conn->encoders[0]);
    }

    if (enc) {
        ctx.crtc_id = enc->crtc_id;
        drmModeFreeEncoder(enc);
    } else {
        fprintf(stderr, "无法为该屏幕找到合适的 Encoder/CRTC！\n");
        drmModeFreeConnector(conn);
        drmModeFreeResources(res);
        return ctx;
    }

    // 释放外层资源（不再需要了）
    drmModeFreeResources(res);

    // 4. 获取分辨率并保存当前 CRTC 状态（用于程序退出时恢复）
    ctx.saved_crtc = drmModeGetCrtc(ctx.fd, ctx.crtc_id);

    uint32_t real_w = conn->modes[0].hdisplay; 
    uint32_t real_h = conn->modes[0].vdisplay; 
    ctx.screen_width = real_w;
    ctx.screen_height = real_h;

    // 5. 创建双缓冲 (Dumb Buffer) 并导出 DMA-BUF (Prime FD)
    for (int i = 0; i < 2; i++) {
        struct drm_mode_create_dumb creq = {};
        creq.width = real_w;
        creq.height = real_h;
        creq.bpp = 32; 
        ioctl(ctx.fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq);

        ctx.handle[i] = creq.handle;
        drmModeAddFB(ctx.fd, real_w, real_h, 24, 32, creq.pitch, creq.handle, &ctx.fb_id[i]);
        
        // 导出 dma-buf fd
        drmPrimeHandleToFD(ctx.fd, creq.handle, DRM_CLOEXEC, &ctx.prime_fd[i]);
    }

    printf("准备在 CRTC %d 上点亮模式: %dx%d (双缓存防撕裂模式)\n", ctx.crtc_id, real_w, real_h);
    
    // 6. 提交显示 (SetCrtc)
    ctx.current_buffer = 0;
    int ret = drmModeSetCrtc(ctx.fd, ctx.crtc_id, ctx.fb_id[0], 0, 0, &my_connector_id, 1, &conn->modes[0]);
    if (ret < 0) {
        fprintf(stderr, "drmModeSetCrtc 失败: %s (错误码: %d)\n", strerror(errno), errno);
    } else {
        printf("✅ 屏幕已点亮！Connector ID: %d, CRTC ID: %d\n", my_connector_id, ctx.crtc_id);
    }

    // 释放屏幕对象
    drmModeFreeConnector(conn);
    return ctx;
}

// 翻页事件回调函数 (用于唤醒 drmHandleEvent)
void page_flip_handler(int fd, unsigned int sequence, unsigned int tv_sec, unsigned int tv_usec, void *user_data) {
    // 翻页完成，无需特殊处理
}


// =========================================================================
// 主函数
// =========================================================================
int main(void)
{
    pci_driver_fd = open_pci_driver();
    if (pci_driver_fd < 0) return -1;
    cmd_operation(pci_driver_fd, info_num, &command_operation);

    char input[10];
    int ret = 0;

    // 1. 初始化 DMA 内存映射
    int map_cmd = 3;
    uint32_t total_size_tx = 1024 * 1024 * 3;  
    uint32_t total_size_rx = 1024 * 1024 * 10; 
    if (pci_map(pci_driver_fd, map_cmd, total_size_tx, total_size_rx) < 0) return -1;
    dma_operation.data = pci_mmp(pci_driver_fd, map_cmd, total_size_tx, total_size_rx);
    
    // 2. 初始化 FPGA 配置寄存器
    unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
    ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = 0x003F4800;
    ptr32[4] = 0x00000001; ptr32[5] = 0x00000002; ptr32[6] = 0x00000003;
    
    pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);
    pci_dma_single_write(pci_driver_fd, 0x20000080, 8,  4);
    pci_dma_single_write(pci_driver_fd, 0x200000c0, 12, 4);   
    pci_dma_single_write(pci_driver_fd, 0x20000040, 4,  4);
    

    while (1)
    {
        printf("输入y使能纯硬件视频流 (输入q退出): ");
        if (fgets(input, sizeof(input), stdin) != NULL)
        {
            input[strcspn(input, "\n")] = '\0';
            if (strcmp(input, "y") == 0)
            {
                printf("▶ 正在接管显示器... (注意：这会覆盖你的 Linux 桌面)\n");
                // 【修复核心】：每次按 y 进入前，重新唤醒 FPGA！
                pci_dma_single_write(pci_driver_fd, 0x20000040, 4, 4);

                DrmContext drm = init_drm_display();
                if (drm.fd < 0) break;

                // Wrap 目标地址 (DRM 显存：两个缓冲)
                rga_buffer_t dst_buf[2];
                dst_buf[0] = wrapbuffer_fd(drm.prime_fd[0], drm.screen_width, drm.screen_height, RK_FORMAT_BGRA_8888);
                dst_buf[1] = wrapbuffer_fd(drm.prime_fd[1], drm.screen_width, drm.screen_height, RK_FORMAT_BGRA_8888);

                // Wrap 源地址 (FPGA 数据)
                void* frame_ptr_0 = (void*)((uint8_t*)dma_operation.data.read_buf);
                void* frame_ptr_1 = (void*)((uint8_t*)dma_operation.data.read_buf + PING_PONG_OFFSET);
                rga_buffer_t src_buf[2];
                src_buf[0] = wrapbuffer_virtualaddr(frame_ptr_0, IMG_WIDTH, IMG_HEIGHT, RK_FORMAT_BGR_565);
                src_buf[1] = wrapbuffer_virtualaddr(frame_ptr_1, IMG_WIDTH, IMG_HEIGHT, RK_FORMAT_BGR_565);

                int buffer_index = 0;
                int frame_count = 0;
                auto last_time = std::chrono::high_resolution_clock::now();

                fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);

                drmEventContext ev = {};
                ev.version = DRM_EVENT_CONTEXT_VERSION;
                ev.page_flip_handler = page_flip_handler;

                // ==========================================================
                // 纯血硬件极速渲染主循环 (双缓存零撕裂 + 并行流水线优化版)
                // ==========================================================
                while (true)
                {
                    // 1. 获取 FPGA 传来的图像
                    int ret = ioctl(pci_driver_fd, PCI_GET_IMG, &dma_operation);
                    if (ret < 0) break; 

                    int next_drm_buffer = 1 - drm.current_buffer;

                    if (dma_operation.data.read_buf != NULL && dma_operation.data.read_buf != MAP_FAILED) 
                    {
                        // 2. 硬件转换：写入后台显存
                        imcvtcolor(src_buf[buffer_index], dst_buf[next_drm_buffer], RK_FORMAT_BGR_565, RK_FORMAT_BGRA_8888);
                    }

                    // 3. 【关键优化】：此时 RGA 已经读完了 src_buf，源内存已空出。
                    // 立刻通知 FPGA：你可以开始往当前这块源内存写下一帧了！
                    uint32_t fpga_ack_offset = buffer_index * 4 + 16; 
                    pci_dma_single_write(pci_driver_fd, 0x20000000, fpga_ack_offset, 4);

                    // 切换数据源索引 (为下个循环做准备)
                    buffer_index = 1 - buffer_index;

                    // 4. 提交翻页请求 (让 DRM 准备切换后台显存)
                    drmModePageFlip(drm.fd, drm.crtc_id, drm.fb_id[next_drm_buffer], DRM_MODE_PAGE_FLIP_EVENT, NULL);

                    // 5. 等待屏幕垂直同步 VBlank
                    // 【此时：CPU在睡大觉，显示器在等信号，但 FPGA 已经收到 ACK 在全速采集下一帧了！】
                    drmHandleEvent(drm.fd, &ev);

                    drm.current_buffer = next_drm_buffer;

                    // 帧率统计计算
                    frame_count++; 
                    auto current_time = std::chrono::high_resolution_clock::now();
                    std::chrono::duration<double> elapsed = current_time - last_time;
                    if (elapsed.count() >= 1.0) {
                        printf("\r[纯硬件双缓冲流] 当前帧率: %5.2f FPS | 退出请按回车键...", frame_count / elapsed.count());
                        fflush(stdout);
                        last_time = current_time;
                        frame_count = 0;
                    }

                    // 检测是否按下回车退出
                    char ch;
                    if (read(STDIN_FILENO, &ch, 1) > 0 && ch == '\n') break;
                }       

                // ==========================================================
                // 安全退出与资源清理
                // ==========================================================
                fcntl(STDIN_FILENO, F_SETFL, 0);

                // 恢复系统原有的 CRTC 状态（把屏幕还给 Linux 桌面）
                drmModeSetCrtc(drm.fd, drm.saved_crtc->crtc_id, drm.saved_crtc->buffer_id, 
                               drm.saved_crtc->x, drm.saved_crtc->y, nullptr, 0, &drm.saved_crtc->mode);
                
                // 释放双缓冲资源
                for (int i = 0; i < 2; i++) {
                    struct drm_mode_destroy_dumb dreq = {};
                    dreq.handle = drm.handle[i];
                    ioctl(drm.fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
                    close(drm.prime_fd[i]);
                    drmModeRmFB(drm.fd, drm.fb_id[i]);
                }

                drmModeFreeCrtc(drm.saved_crtc);
                close(drm.fd);

                printf("\n■ 视频流已安全关闭，屏幕已交还给系统。\n");

                // 通知 FPGA 停止发送
                pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);
                pci_dma_single_write(pci_driver_fd, 0x20000040, 8,  4);
                
            } 
            else if (strcmp(input, "q") == 0) break;
        }
    }
    


    
    pci_umap(pci_driver_fd); 
    close(pci_driver_fd);
    return 0;
}