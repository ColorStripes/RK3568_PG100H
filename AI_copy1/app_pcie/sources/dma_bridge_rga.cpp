/**
 * @file dma_bridge_rga.cpp
 * @brief  
 */

 #include "../includes/pcie_dma_read_test.h"
 #include <iostream>
 #include <fcntl.h>
 #include <unistd.h>
 #include <sys/mman.h>
 #include <sys/ioctl.h>
 #include <cstdlib>
 #include <cstring>
 #include <algorithm>
  
 #include <rga/RgaApi.h>
 #include <rga/im2d.h>
 #include <xf86drm.h>
 #include <xf86drmMode.h>
 #include <drm_fourcc.h>
  
 using namespace std;
  
 // === 硬件与参数配置 ===
 const int FPGA_IMG_WIDTH  = 1280;
 const int FPGA_IMG_HEIGHT = 720;
 const uint32_t PING_PONG_OFFSET = 0x1C2000;
  
 const int YOLO_WIDTH  = 640;
 const int YOLO_HEIGHT = 640;
 const int YOLO_CHANNELS = 3; 
 
 const int YOLO_SIZE = YOLO_WIDTH * YOLO_HEIGHT * YOLO_CHANNELS;
 const int HD_SIZE = FPGA_IMG_WIDTH * FPGA_IMG_HEIGHT * 3; 
 const int FRAME_BLOCK_SIZE = YOLO_SIZE + HD_SIZE; 
  
 // =========================================================================
 // 全局变量定义 
 // =========================================================================
 int pci_driver_fd = -1;
 COMMAND_OPERATION command_operation;
 DMA_OPERATION dma_operation;
 
 int buffer_index = 0;     
 int py_buffer_index = 0;  
 void* rga_out_buf = nullptr; 
 
 rga_buffer_t src_bufs[2];
 rga_buffer_t yolo_bufs[2];
 rga_buffer_t hd_bufs[2];
  
 struct DRM_CONTEXT {
     int fd;
     uint32_t conn_id;
     uint32_t crtc_id;
     drmModeModeInfo mode;
     uint32_t fb_id[2]; 
     uint32_t handle[2]; 
     uint32_t pitch[2];
     uint32_t size[2];
     void* map[2];
     drmModeCrtc* saved_crtc;
     int back_index;
 } drm_ctx;
  
 
 // =========================================================================
 // PCIe 底层驱动函数实现 
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
     unsigned int i = 0;                
     unsigned int cnt = 0;              
     unsigned long temp_bar_len;        
     int value = 0;                     
     char pci_info[20][20];             
     char unit[5][10] = {"B", "KB", "MB", "GB", "TB"};
 
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
             }
             else
             {
                 strcpy(pci_info[cnt++],  "Down");
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
                 sprintf(pci_info[cnt++], "%ld%s", temp_bar_len, unit[value]);
             }
 
             sprintf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mps);
             sprintf(pci_info[cnt++], "%d", cmd_op->get_pci_dev_info.mrrs);
             break;
 
         case performance_num:
             break;
 
         default:
             break;
     }
 }
 
 int pci_dma_single_write(int pci_driver_fd, uint32_t start_ddr3_addr, uint32_t mmp_offset, uint32_t total_size)
 {
     dma_operation.offset_addr   = mmp_offset;
     dma_operation.ddr3_addr     = start_ddr3_addr;
     dma_operation.total_length  = total_size;
 
     int ret = ioctl(pci_driver_fd, PCI_DMA_READ_CMD, &dma_operation);
     if (ret < 0) return -1;
     return 0;
 }
 
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
 // RGA / DRM Python 桥接
 // =========================================================================
 
 int init_drm(int connector_index) {
    drm_ctx.fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (drm_ctx.fd < 0) return -1;
    drmModeRes* res = drmModeGetResources(drm_ctx.fd);
    if (!res) return -1;
    drmModeConnector* conn = nullptr;

    if (connector_index >= 0) {
        int connected_count = 0;
        for (int i = 0; i < res->count_connectors; ++i) {
            drmModeConnector* tmp = drmModeGetConnector(drm_ctx.fd, res->connectors[i]);
            if (tmp && tmp->connection == DRM_MODE_CONNECTED) {
                if (connected_count == connector_index) {
                    conn = tmp;
                    break;
                }
                connected_count++;
                drmModeFreeConnector(tmp);
            } else if (tmp) {
                drmModeFreeConnector(tmp);
            }
        }
    } else {
        for (int i = 0; i < res->count_connectors; ++i) {
            conn = drmModeGetConnector(drm_ctx.fd, res->connectors[i]);
            if (conn && conn->connection == DRM_MODE_CONNECTED) break;
            drmModeFreeConnector(conn);
            conn = nullptr;
        }
    }
    if (!conn) return -1;
    drm_ctx.conn_id = conn->connector_id;
    drm_ctx.mode = conn->modes[0];
    drmModeEncoder* enc = drmModeGetEncoder(drm_ctx.fd, conn->encoder_id);
    if (!enc) { drmModeFreeConnector(conn); drmModeFreeResources(res); return -1; }
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
    drm_ctx.back_index = 1; 
    drmModeFreeResources(res);
    return 0;
}
  
extern "C" {


    int gpio(int value)
    {
        unsigned int cmd;

        // 1. 根据传入的值，选择对应的 ioctl 命令
        if (value == 1) {
            cmd = GPIO_OUT;  // 对应内核输出高电平
        } 
        else if (value == 0) {
            cmd = GPIO_IN;   // 对应内核输出低电平
        } 
        else {
            printf("Error: Invalid GPIO value %d! Must be 0 or 1.\n", value);
            return -1;
        }

        // 2. 严格按照你要求的格式调用 ioctl
        int ret = ioctl(pci_driver_fd, cmd, &dma_operation);

        // 3. 错误处理
        if (ret < 0) {
            perror("ioctl GPIO control failed");
            return ret;
        }

        return 0;
    }




    int get_connected_connectors(char* out_buf, int buf_size) {
        int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
        if (fd < 0) { out_buf[0] = '\0'; return 0; }
        drmModeRes* res = drmModeGetResources(fd);
        if (!res) { close(fd); out_buf[0] = '\0'; return 0; }
        int count = 0;
        int written = 0;
        for (int i = 0; i < res->count_connectors; ++i) {
            drmModeConnector* conn = drmModeGetConnector(fd, res->connectors[i]);
            if (conn && conn->connection == DRM_MODE_CONNECTED) {
                const char* type_name = "Unknown";
                switch (conn->connector_type) {
                    case DRM_MODE_CONNECTOR_VGA: type_name = "VGA"; break;
                    case DRM_MODE_CONNECTOR_DVII: type_name = "DVI-I"; break;
                    case DRM_MODE_CONNECTOR_DVID: type_name = "DVI-D"; break;
                    case DRM_MODE_CONNECTOR_DVIA: type_name = "DVI-A"; break;
                    case DRM_MODE_CONNECTOR_Composite: type_name = "Composite"; break;
                    case DRM_MODE_CONNECTOR_SVIDEO: type_name = "S-Video"; break;
                    case DRM_MODE_CONNECTOR_LVDS: type_name = "LVDS"; break;
                    case DRM_MODE_CONNECTOR_Component: type_name = "Component"; break;
                    case DRM_MODE_CONNECTOR_9PinDIN: type_name = "9PinDIN"; break;
                    case DRM_MODE_CONNECTOR_DisplayPort: type_name = "DP"; break;
                    case DRM_MODE_CONNECTOR_HDMIA: type_name = "HDMI-A"; break;
                    case DRM_MODE_CONNECTOR_HDMIB: type_name = "HDMI-B"; break;
                    case DRM_MODE_CONNECTOR_TV: type_name = "TV"; break;
                    case DRM_MODE_CONNECTOR_eDP: type_name = "eDP"; break;
                    case DRM_MODE_CONNECTOR_DSI: type_name = "DSI"; break;
                    case DRM_MODE_CONNECTOR_DPI: type_name = "DPI"; break;
                }
                int w = conn->modes[0].hdisplay;
                int h = conn->modes[0].vdisplay;
                int n = snprintf(out_buf + written, buf_size - written,
                    "%d:%s-%d(%dx%d)\n", count, type_name, conn->connector_type_id, w, h);
                if (n > 0 && written + n < buf_size) { written += n; }
                count++;
            }
            if (conn) drmModeFreeConnector(conn);
        }
        if (written > 0 && out_buf[written - 1] == '\n') out_buf[written - 1] = '\0';
        drmModeFreeResources(res);
        close(fd);
        return count;
    }

    int init_hardware_pipeline_ex(int connector_index) {
        pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        
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

        unsigned int *ptr32 = (unsigned int *)dma_operation.data.write_buf;
        ptr32[1] = 0x00000001; ptr32[2] = 0x00000000; ptr32[3] = 0x003F4800;
        ptr32[4] = 0x00000001; ptr32[5] = 0x00000002; ptr32[6] = 0x00000003;
        pci_dma_single_write(pci_driver_fd, 0x20000080, 8,  4);
        pci_dma_single_write(pci_driver_fd, 0x200000c0, 12, 4);
        pci_dma_single_write(pci_driver_fd, 0x20000000, 24, 4);
        pci_dma_single_write(pci_driver_fd, 0x20000040, 4,  4);

        buffer_index = 0; 
        py_buffer_index = 0;
        if (init_drm(connector_index) < 0) return -1;
        return 0;
    }

    int init_hardware_pipeline() {
        return init_hardware_pipeline_ex(-1);
    }
  
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
  
     void sync_to_screen(uint8_t* hd_ptr) {
         if (!rga_out_buf || !hd_ptr) return;
         rga_buffer_t py_hd_buf = wrapbuffer_virtualaddr(hd_ptr, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT, RK_FORMAT_RGB_888);
         rga_buffer_t drm_dst_buf = wrapbuffer_virtualaddr(drm_ctx.map[drm_ctx.back_index], drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay, RK_FORMAT_BGRA_8888);
         im_rect drm_dst_rect = {0, 0, drm_ctx.mode.hdisplay, drm_ctx.mode.vdisplay};
         improcess(py_hd_buf, drm_dst_buf, {}, {0, 0, FPGA_IMG_WIDTH, FPGA_IMG_HEIGHT}, drm_dst_rect, {}, 0, nullptr, nullptr, 0);
         
         drmModePageFlip(drm_ctx.fd, drm_ctx.crtc_id, drm_ctx.fb_id[drm_ctx.back_index], DRM_MODE_PAGE_FLIP_ASYNC, nullptr);
         drm_ctx.back_index = 1 - drm_ctx.back_index;
     }
  
     void cleanup_hardware() {
         if (rga_out_buf) { free(rga_out_buf); rga_out_buf = nullptr; }
         if (drm_ctx.saved_crtc) {
             drmModeSetCrtc(drm_ctx.fd, drm_ctx.saved_crtc->crtc_id, drm_ctx.saved_crtc->buffer_id, 
                            drm_ctx.saved_crtc->x, drm_ctx.saved_crtc->y, nullptr, 0, &drm_ctx.saved_crtc->mode);
             drmModeFreeCrtc(drm_ctx.saved_crtc);
         }
         for (int i = 0; i < 2; ++i) {
             if (drm_ctx.map[i]) munmap(drm_ctx.map[i], drm_ctx.size[i]);
             if (drm_ctx.fb_id[i]) drmModeRmFB(drm_ctx.fd, drm_ctx.fb_id[i]);
             if (drm_ctx.handle[i]) {
                 struct drm_mode_destroy_dumb destroy_arg = {};
                 destroy_arg.handle = drm_ctx.handle[i];
                 drmIoctl(drm_ctx.fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy_arg);
             }
         }
         if (drm_ctx.fd >= 0) close(drm_ctx.fd);
         if (pci_driver_fd >= 0) { pci_umap(pci_driver_fd); close(pci_driver_fd); pci_driver_fd = -1; }
     }
 }

