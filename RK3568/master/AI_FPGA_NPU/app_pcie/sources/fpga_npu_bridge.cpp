/**
 * fpga_npu_bridge.cpp — YOLOv5 NPU 推理桥接接口 (并入 libdma_rga.so)
 *
 * 初始化三件套 (Python 程序启动时执行一次, 与 car_qt.py 顶部一致):
 *   npu_init -> npu_configure_layers -> npu_upload_weights -> npu_upload_instructions
 *
 * 推理循环 (Python 在合适位置插入):
 *   npu_upload_image_rgba(rgba_buf, verify) -> npu_infer_start() -> npu_infer_read(out_buf, out_size)
 *   或
 *   npu_upload_image_file(image_path, verify) -> npu_infer_start() -> npu_infer_read(out_buf, out_size)
 *
 * 程序结束:
 *   npu_release()
 *
 * FPGA DDR3 内存布局 (480MB, 起始 0x02000000):
 *   ┌──────────────────────────────────────┐  0x02000000
 *   │  权重区 (60 层 × 1MB)                │  ~60MB
 *   ├──────────────────────────────────────┤  0x05C00000
 *   │  空闲                                │
 *   ├──────────────────────────────────────┤  0x06000000
 *   │  输入图像 (RGBA 640x640x4)           │
 *   ├──────────────────────────────────────┤  0x07000000
 *   │  三头输出 Head1|Head2|Head3 连续存放  │  ~263KB
 *   ├──────────────────────────────────────┤  0x40000000
 *   │  NPU 指令流                          │
 *   ├──────────────────────────────────────┤  0x50000000
 *   │  NPU 总层数寄存器                     │  4B
 *   ├──────────────────────────────────────┤  0x51000000
 *   │  NPU 启动信号                         │  4B
 *   └──────────────────────────────────────┘
 *
 * 主机 TX 缓冲区 (3MB): 层数 0x040000 | 启动 0x041000 | 权重 0x042000
 *                       图像 0x142000 | 指令 0x2D2000
 * 主机 RX 缓冲区: 0x007E9000 起三头连续存放, 总 NPU_TOTAL_OUTPUT_SIZE 字节
 */

#include "../includes/pcie_dma_read_test.h"
#include "../includes/npu_config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <time.h>
#include <stdint.h>
#include <algorithm>
#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <rga/im2d.h>

// ---- 辅助 ----
static uint8_t* tx_buf() { return (uint8_t *)dma_operation.data.write_buf; }
static uint8_t* rx_buf() { return (uint8_t *)dma_operation.data.read_buf; }

static uint64_t get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static uint32_t parse_hex_line(const char *line) {
    return (uint32_t)strtoul(line, NULL, 16);
}

// =====================================================================
// DMA 写后读回校验 (debug 用)
// =====================================================================

/**
 * verify_write_readback — 将刚写到 DDR3 的数据读回，与 TX 缓冲区原始数据对比
 *   ddr3_addr : FPGA DDR3 地址
 *   total_size: 字节数
 *   tx_offset : TX 缓冲区中源数据偏移 (权重 TX_WEIGHT_OFFSET / 图像 TX_IMAGE_OFFSET)
 *   name      : 描述名 (用于日志)
 *   返回 0 表示一致，-1 表示有不匹配
 */
static int verify_write_readback(uint32_t ddr3_addr, uint32_t total_size,
                                 uint32_t tx_offset, const char *name) {
    if (total_size == 0) return 0;

    // 读回到 RX 缓冲区偏移 0 处
    memset(rx_buf(), 0, total_size);

    uint64_t t0 = get_time_ms();
    int ret = pci_dma_single_read(pci_driver_fd, ddr3_addr, 0, total_size);
    uint64_t t1 = get_time_ms();

    if (ret < 0) {
        fprintf(stderr, "  [%s] readback failed: 0x%08X\n", name, ddr3_addr);
        return -1;
    }

    const uint8_t *src = tx_buf() + tx_offset;
    const uint8_t *dst = rx_buf();
    int error_count = 0;
    const int max_errors = 10;

    for (uint32_t i = 0; i < total_size; i++) {
        if (src[i] != dst[i]) {
            if (error_count < max_errors) {
                printf("  [%s] byte %u: wrote 0x%02X, read 0x%02X\n",
                       name, i, src[i], dst[i]);
            }
            error_count++;
        }
    }

    if (error_count == 0) {
        printf("  [%s] verify OK: 0x%08X + %u bytes (%llu ms)\n",
               name, ddr3_addr, total_size, (unsigned long long)(t1 - t0));
    } else {
        printf("  [%s] verify FAIL: %d/%u bytes mismatch\n",
               name, error_count, total_size);
        return -1;
    }
    return 0;
}

// =====================================================================
// NPU weight upload
// =====================================================================

static int upload_weight_file(const char *bin_path, int weight_index, int do_verify) {
    FILE *fp = fopen(bin_path, "rb");
    if (!fp) { fprintf(stderr, "warning: weight file %s not found, skip\n", bin_path); return -1; }
    fseek(fp, 0, SEEK_END);
    size_t file_size = ftell(fp);
    rewind(fp);

    if (file_size > NPU_WEIGHT_STRIDE) {
        fprintf(stderr, "error: %s exceeds 1MB (%zu)\n", bin_path, file_size);
        fclose(fp); return -1;
    }

    uint8_t *buf = tx_buf() + TX_WEIGHT_OFFSET;
    memset(buf, 0, file_size);
    size_t n = fread(buf, 1, file_size, fp);
    fclose(fp);
    if (n != file_size) { fprintf(stderr, "error: read %s incomplete\n", bin_path); return -1; }

    uint32_t addr = NPU_WEIGHT_DDR3_BASE + weight_index * NPU_WEIGHT_STRIDE;

    if (pci_dma_single_write(pci_driver_fd, addr, TX_WEIGHT_OFFSET, (uint32_t)file_size) < 0) {
        fprintf(stderr, "upload weight failed: idx=%d, addr=0x%08X, err=%s\n",
                weight_index, addr, strerror(errno));
        return -1;
    }
    printf("  weight[%2d] -> FPGA 0x%08X, %zu bytes\n", weight_index, addr, file_size);
    if (do_verify &&
        verify_write_readback(addr, (uint32_t)file_size, TX_WEIGHT_OFFSET, bin_path) < 0) {
        fprintf(stderr, "  [weight %d] readback verify FAIL\n", weight_index);
        return -1;
    }
    return 0;
}

static int upload_all_weights(const char *weight_dir, int do_verify) {
    printf("\n--- upload NPU weights (readback verify: %s) ---\n",
           do_verify ? "ON" : "OFF");
    int failures = 0;
    for (int i = 1; i <= 57; i++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/conv%d_weight.bin", weight_dir, i);
        if (upload_weight_file(path, i - 1, do_verify) < 0) failures++;
    }
    for (int i = 1; i <= 3; i++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/out%d_weight.bin", weight_dir, i);
        if (upload_weight_file(path, 57 + i - 1, do_verify) < 0) failures++;
    }
    printf("weight upload done: %d failed\n", failures);
    return (failures > 0) ? -1 : 0;
}

// =====================================================================
// 输入图像预处理: 解码(imread) -> RGA letterbox(灰边128) -> RGBA8888 写入 TX -> DMA 上传
// =====================================================================

/**
 * rga_upload_input_image — 用 RGA 完成 BGR->RGBA8888 + letterbox 缩放, 直接写入 TX 图像区并 DMA 上传。
 *   与旧 CPU 路径字节等价: 输入量化 q = round(p/(255*quant_scale))
 *   在当前 quant_scale≈1/255、quant_zero=0 下恒等于 p, RGBA 直通无需 CPU 换算。
 *   注意: 该等价性依赖上述量化参数, 换模型后若 scale/zero 变化, 必须恢复 CPU 量化预处理。
 *   差异: RGA 缩放为双线性 (参考为 BICUBIC), 对拍 diff 不逐位一致, 对检测精度影响可忽略。
 *   返回 0 成功 (已完成 DMA 上传), -1 失败。
 */
static int rga_upload_input_image(const cv::Mat &img, int do_verify) {
    // letterbox 几何与旧 CPU 路径一致: min-scale, 尺寸截断取整, 居中
    double scale = std::min((double)NPU_INPUT_W / img.cols, (double)NPU_INPUT_H / img.rows);
    int nw = (int)(img.cols * scale);
    int nh = (int)(img.rows * scale);
    if (nw < 1) nw = 1;
    if (nh < 1) nh = 1;
    int dx = (NPU_INPUT_W - nw) / 2;
    int dy = (NPU_INPUT_H - nh) / 2;

    uint8_t *img_area = tx_buf() + TX_IMAGE_OFFSET;

    // 灰边: RGBA 每像素 {R,G,B,A} = {128,128,128,0} = 小端 uint32 0x00808080
    std::fill((uint32_t *)img_area, (uint32_t *)(img_area + NPU_IMAGE_SIZE), 0x00808080u);

    // RGA: BGR888 -> RGBA8888, 双线性缩放到中心区域 (同步调用, 返回后数据已落 TX)
    rga_buffer_t src = wrapbuffer_virtualaddr(img.data, img.cols, img.rows, RK_FORMAT_BGR_888);
    rga_buffer_t dst = wrapbuffer_virtualaddr(img_area, NPU_INPUT_W, NPU_INPUT_H,
                                              RK_FORMAT_RGBA_8888);
    im_rect src_rect = {0, 0, img.cols, img.rows};
    im_rect dst_rect = {dx, dy, nw, nh};
    IM_STATUS st = improcess(src, dst, {}, src_rect, dst_rect, {}, 0, nullptr, nullptr, 0);
    if (st != IM_STATUS_SUCCESS) {
        fprintf(stderr, "RGA improcess failed (status %d)\n", (int)st);
        return -1;
    }
    printf("  RGA: BGR->RGBA8888 letterbox scale=%.4f pad=(%d,%d) -> TX 0x%08X\n",
           scale, dx, dy, TX_IMAGE_OFFSET);

    // DMA 上传 FPGA 输入区
    if (pci_dma_single_write(pci_driver_fd, NPU_IMAGE_DDR3_ADDR, TX_IMAGE_OFFSET,
                             (uint32_t)NPU_IMAGE_SIZE) < 0) {
        fprintf(stderr, "upload image (RGA path) failed: %s\n", strerror(errno));
        return -1;
    }
    printf("  input image(RGA, TX offset 0x%08X) -> FPGA 0x%08X, %u bytes (%dx%dx%d RGBA)\n",
           TX_IMAGE_OFFSET, NPU_IMAGE_DDR3_ADDR, (unsigned)NPU_IMAGE_SIZE,
           NPU_INPUT_W, NPU_INPUT_H, NPU_INPUT_C);
    if (do_verify &&
        verify_write_readback(NPU_IMAGE_DDR3_ADDR, (uint32_t)NPU_IMAGE_SIZE,
                              TX_IMAGE_OFFSET, "input_image") < 0) {
        fprintf(stderr, "input image readback verify FAIL\n");
        return -1;
    }
    return 0;
}

/**
 * upload_input_image — 将处理后的图像写入 TX 缓冲区 TX_IMAGE_OFFSET 处, 再 DMA 上传到 FPGA:
 *   - image_path 是 jpg/png 等: RGA 完成 BGR->RGBA8888 + letterbox 后放入 TX 并上传
 *   - image_path 是 640x640x4 字节的 raw bin: 原样放入 TX 上传 (预量化参考图, 字节布局自负)
 *   - image_path 为 NULL: 上传 TX 缓冲区残留 (兼容旧行为, 不推荐)
 */
static int upload_input_image(const char *image_path, int do_verify) {
    printf("\n--- upload input image (readback verify: %s) ---\n",
           do_verify ? "ON" : "OFF");

    if (NPU_IMAGE_SIZE > TX_INSTR_OFFSET - TX_IMAGE_OFFSET) {
        fprintf(stderr, "error: TX image area insufficient, need %u bytes\n",
                (unsigned)NPU_IMAGE_SIZE);
        return -1;
    }

    uint8_t *img_area = tx_buf() + TX_IMAGE_OFFSET;

    if (image_path) {
        cv::Mat img = cv::imread(image_path, cv::IMREAD_COLOR);
        if (!img.empty()) {
            // 可解码图像: RGA 直通 (BGR->RGBA8888 + letterbox), 失败即报错, 不再回退 CPU 转换
            return rga_upload_input_image(img, do_verify);
        }
        // 不可解码: 按 640x640x4 raw bin 原样上传 (预量化参考数据)
        FILE *fp = fopen(image_path, "rb");
        if (!fp) { fprintf(stderr, "cannot open image file: %s\n", image_path); return -1; }
        fseek(fp, 0, SEEK_END);
        size_t file_size = (size_t)ftell(fp);
        rewind(fp);
        if (file_size != NPU_IMAGE_SIZE) {
            fprintf(stderr, "error: %s is not a decodable image and raw size %zu != %u bytes\n",
                    image_path, file_size, (unsigned)NPU_IMAGE_SIZE);
            fclose(fp);
            return -1;
        }
        if (fread(img_area, 1, file_size, fp) != file_size) {
            fprintf(stderr, "error: read %s incomplete\n", image_path);
            fclose(fp);
            return -1;
        }
        fclose(fp);
        printf("  raw bin %s (%zu bytes) copied to TX, byte layout as-is\n",
               image_path, file_size);
    } else {
        fprintf(stderr, "warning: no input image, uploading undefined TX buffer residue\n");
    }

    if (pci_dma_single_write(pci_driver_fd, NPU_IMAGE_DDR3_ADDR, TX_IMAGE_OFFSET, (uint32_t)NPU_IMAGE_SIZE) < 0) {
        fprintf(stderr, "upload image failed: %s\n", strerror(errno));
        return -1;
    }
    printf("  input image(TX offset 0x%08X) -> FPGA 0x%08X, %u bytes (%dx%dx%d RGBA)\n",
           TX_IMAGE_OFFSET, NPU_IMAGE_DDR3_ADDR, (unsigned)NPU_IMAGE_SIZE,
           NPU_INPUT_W, NPU_INPUT_H, NPU_INPUT_C);
    if (do_verify &&
        verify_write_readback(NPU_IMAGE_DDR3_ADDR, (uint32_t)NPU_IMAGE_SIZE,
                              TX_IMAGE_OFFSET, "input_image") < 0) {
        fprintf(stderr, "input image readback verify FAIL\n");
        return -1;
    }
    return 0;
}

// =====================================================================
// NPU configure / instruction upload
// =====================================================================

static int configure_npu(void) {
    printf("\n--- configure NPU ---\n");

    *(uint32_t *)(tx_buf() + TX_LAYER_OFFSET) = NPU_LAYER_NUM;
    printf("set NPU total layers %u -> FPGA 0x%08X\n", NPU_LAYER_NUM, NPU_LAYER_ADDR);
    if (pci_dma_single_write(pci_driver_fd, NPU_LAYER_ADDR, TX_LAYER_OFFSET, 4) < 0) {
        fprintf(stderr, "write NPU layer count failed: %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

static int upload_npu_instructions(const char *instr_file) {
    printf("\n--- upload NPU instruction stream ---\n");
    FILE *fp = fopen(instr_file, "r");
    if (!fp) { perror("cannot open instruction file"); return -1; }

    char line_buf[64];
    uint32_t word_count = 0;
    uint32_t max_words = TX_INSTR_SIZE / 4;
    uint32_t *instr_buf = (uint32_t *)(tx_buf() + TX_INSTR_OFFSET);

    while (fgets(line_buf, sizeof(line_buf), fp)) {
        char *p = line_buf;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '\0' || *p == '\n' || *p == '\r' || *p == '#') continue;
        size_t len = strlen(p);
        while (len > 0 && (p[len-1] == '\n' || p[len-1] == '\r')) p[--len] = '\0';
        if (word_count >= max_words) { fprintf(stderr, "instruction stream overflow\n"); fclose(fp); return -1; }
        instr_buf[word_count++] = parse_hex_line(p);
    }
    fclose(fp);

    uint32_t instr_size = word_count * 4;
    printf("instruction file parsed: %u words, %u bytes\n", word_count, instr_size);

    if (instr_size > TX_INSTR_SIZE) {
        fprintf(stderr, "error: instruction stream %u bytes exceeds TX area %u bytes\n",
                instr_size, (unsigned)TX_INSTR_SIZE);
        return -1;
    }

    if (pci_dma_single_write(pci_driver_fd, NPU_INSTR_DDR3_BASE, TX_INSTR_OFFSET, instr_size) < 0) {
        fprintf(stderr, "upload instruction stream failed: %s\n", strerror(errno));
        return -1;
    }
    printf("instruction stream upload done: %u bytes -> FPGA 0x%08X\n", instr_size, NPU_INSTR_DDR3_BASE);
    return (int)instr_size;
}

// =====================================================================
// NPU inference: start signal + interrupt wait, three-head output read
// =====================================================================

/**
 * dump_heads_diagnostic — 超时诊断: 直接 DMA 读回 FPGA 三头输出区并打印统计。
 *   非零字节统计用于区分:
 *     - 有大量非零数据 -> NPU 已算到输出阶段, 超时是中断链路问题
 *     - 全零            -> NPU 没算到三头输出 (卡在中间层或没启动)
 */
static void dump_heads_diagnostic(void) {
    static const struct { const char *name; uint32_t size; } heads[3] = {
        { "head1_20x20", NPU_HEAD1_SIZE },
        { "head2_40x40", NPU_HEAD2_SIZE },
        { "head3_80x80", NPU_HEAD3_SIZE },
    };
    uint32_t total_size = NPU_TOTAL_OUTPUT_SIZE;

    memset(rx_buf() + NPU_HOST_OUTPUT_BASE, 0, total_size);
    if (pci_dma_single_read(pci_driver_fd, NPU_OUTPUT_DDR3_BASE, NPU_HOST_OUTPUT_BASE, total_size) < 0) {
        fprintf(stderr, "timeout diagnostic: read heads failed: %s\n", strerror(errno));
        return;
    }
    printf("timeout diagnostic: read back FPGA 0x%08X + %u bytes\n", NPU_OUTPUT_DDR3_BASE, total_size);

    const uint8_t *base = rx_buf() + NPU_HOST_OUTPUT_BASE;
    uint32_t off = 0;
    for (int h = 0; h < 3; h++) {
        const uint8_t *p = base + off;
        uint32_t nonzero = 0;
        uint32_t first_nz = UINT32_MAX;
        int sum = 0;
        for (uint32_t i = 0; i < heads[h].size; i++) {
            if (p[i] != 0) { nonzero++; if (first_nz == UINT32_MAX) first_nz = i; }
            sum += (int8_t)p[i];
        }
        printf("  %s: nonzero %u/%u bytes (%.1f%%), first_nz@%u, int8 sum %d\n",
               heads[h].name, nonzero, heads[h].size,
               nonzero * 100.0f / heads[h].size, first_nz, sum);
        printf("    first 16 bytes:");
        for (int i = 0; i < 16; i++) printf(" %02X", p[i]);
        printf("\n");
        off += heads[h].size;
    }
}

/**
 * start_npu_inference — 发送启动信号 (0xF0F0F0F0 -> 0x51000000), 阻塞等待中断完成。
 *   超时 (6s) 时打印三头诊断。返回 0 成功, -1 失败。
 */
static int start_npu_inference(void) {
    printf("\n--- start NPU inference ---\n");

    *(uint32_t *)(tx_buf() + TX_START_OFFSET) = NPU_START_MAGIC;
    printf("send NPU start signal 0x%08X -> FPGA 0x%08X\n", NPU_START_MAGIC, NPU_START_DDR3_BASE);
    if (pci_dma_single_write(pci_driver_fd, NPU_START_DDR3_BASE, TX_START_OFFSET, 4) < 0) {
        fprintf(stderr, "NPU start signal send failed: %s\n", strerror(errno));
        return -1;
    }

    uint64_t t_start = get_time_ms();
    printf("waiting for NPU completion (interrupt wait)...\n");
    int ret = ioctl(pci_driver_fd, PCI_GET_NPU, &dma_operation);
    if (ret < 0) {
        if (errno == ETIMEDOUT) {
            fprintf(stderr, "NPU inference timeout (6s)\n");
            dump_heads_diagnostic();
        } else {
            fprintf(stderr, "NPU interrupt wait failed: %s\n", strerror(errno));
        }
        return -1;
    }
    printf("NPU inference done! elapsed: %llu ms\n",
           (unsigned long long)(get_time_ms() - t_start));
    return 0;
}

/**
 * read_npu_output — 一次 DMA 读回三头连续输出到调用方缓冲。
 *   out_buf : 由调用方分配, 至少 NPU_TOTAL_OUTPUT_SIZE (268800) 字节
 *   out_size: out_buf 可用字节数
 * 成功后 out_buf 内容为 Head1(20x20) | Head2(40x40) | Head3(80x80) 连续 int8 数据。
 * 返回 0 成功, -1 失败。
 */
static int read_npu_output(uint8_t *out_buf, int out_size) {
    uint32_t total_size = NPU_TOTAL_OUTPUT_SIZE;

    printf("DMA read three-head continuous data: FPGA 0x%08X -> Host 0x%06X, %u bytes\n",
           NPU_OUTPUT_DDR3_BASE, NPU_HOST_OUTPUT_BASE, total_size);
    if (pci_dma_single_read(pci_driver_fd, NPU_OUTPUT_DDR3_BASE, NPU_HOST_OUTPUT_BASE, total_size) < 0) {
        fprintf(stderr, "DMA read NPU output failed: %s\n", strerror(errno));
        return -1;
    }
    memcpy(out_buf, rx_buf() + NPU_HOST_OUTPUT_BASE, total_size);
    return 0;
}

// =====================================================================
// extern "C" — Python ctypes 可调用的 FPGA NPU 桥接接口
//
// 与 dma_bridge_rga.cpp 编入同一个 libdma_rga.so 时共享 pci_driver_fd / dma_operation:
//   - 相机/HDMI 管线先初始化时, npu_init 直接复用已建立的 fd 与 TX/RX 映射
//     (内核驱动全局只允许分配一次 DMA 缓冲, 重复 pci_map 会 -EBUSY)
//   - NPU 先初始化时, 相机/HDMI 管线复用 NPU 建立的映射
//
// 典型 Python 调用序列:
//   npu_init()                                        # 一次
//   npu_configure_layers()                            # 初始化三件套
//   npu_upload_weights(weight_dir, verify)            #   配置层数 -> 权重 -> 指令
//   npu_upload_instructions(instr_file)               #
//   npu_upload_image_file(image_path, verify)         # 推理循环: 上传图像 (jpg/png/raw bin)
//   npu_upload_image_rgba(rgba_buf, verify)           #           或直接给 640x640x4 RGBA 缓冲
//   npu_infer_start()                                 #           启动推理 (阻塞等中断)
//   npu_infer_read(out_buf, out_size)                 #           读回三头输出
//   npu_release()                                     # 结束
// =====================================================================
extern "C" {

static int g_npu_init_done = 0;   // npu_init 是否已成功完成
static int g_npu_owns_fd   = 0;   // 本模块是否自行 open 了驱动 fd
static int g_npu_owns_map  = 0;   // 本模块是否创建了驱动全局 DMA 映射 (umap 权限)
static int g_npu_mapped    = 0;   // 本模块是否 mmap 了 TX/RX (munmap 权限)

/**
 * npu_init — 打开 PCIe 驱动并建立 TX/RX DMA 映射
 * 返回 0 成功, -1 失败。
 * 跨模块复用: pci_map 返回 EBUSY 时跳过分配, 直接 pci_mmp 复用已建立的映射。
 */
int npu_init(void) {
    if (pci_driver_fd < 0) {
        pci_driver_fd = open_pci_driver();
        if (pci_driver_fd < 0) return -1;
        g_npu_owns_fd = 1;
    }
    if (!dma_operation.data.write_buf || dma_operation.data.write_buf == MAP_FAILED) {
        int map_ret = pci_map(pci_driver_fd, 3, TX_BUF_SIZE, RX_BUF_SIZE);
        if (map_ret < 0 && errno != EBUSY) return -1;   // EBUSY: 复用已分配的全局映射
        g_npu_owns_map = (map_ret == 0);
        dma_operation.data = pci_mmp(pci_driver_fd, 3, TX_BUF_SIZE, RX_BUF_SIZE);
        g_npu_mapped = (dma_operation.data.write_buf &&
                        dma_operation.data.write_buf != MAP_FAILED);
    }
    if (!dma_operation.data.write_buf || dma_operation.data.write_buf == MAP_FAILED) {
        fprintf(stderr, "npu_init: mmap TX/RX buffers failed\n");
        return -1;
    }
    g_npu_init_done = 1;
    printf("npu_init: pci fd=%d, TX/RX buffers mapped\n", pci_driver_fd);
    return 0;
}

/**
 * npu_release — 收回本模块持有的映射与驱动资源
 *   - munmap: 本模块 mmap 的 TX/RX 用户态映射 (不影响其他实例的映射)
 *   - umap  : 仅当本模块创建了驱动全局映射时执行 (复用他人映射时不得误杀共享缓冲)
 *   - close : 本模块自行 open 的 fd 一律关闭 (驱动仅分配者 fd 的 release 回收全局缓冲,
 *             复用映射的实例关闭自身 fd 不会误杀共享缓冲)
 */
void npu_release(void) {
    if (g_npu_mapped) {
        if (dma_operation.data.write_buf && dma_operation.data.write_buf != MAP_FAILED)
            munmap(dma_operation.data.write_buf, TX_BUF_SIZE);
        if (dma_operation.data.read_buf && dma_operation.data.read_buf != MAP_FAILED)
            munmap(dma_operation.data.read_buf, RX_BUF_SIZE);
        dma_operation.data = {};   // 清空映射指针, 避免误复用已释放的缓冲
        g_npu_mapped = 0;
    }
    if (g_npu_owns_map && pci_driver_fd >= 0) {
        pci_umap(pci_driver_fd);
    }
    if (g_npu_owns_fd && pci_driver_fd >= 0) {
        close(pci_driver_fd);
        pci_driver_fd = -1;
    }
    g_npu_owns_map = 0;
    g_npu_owns_fd = 0;
    g_npu_init_done = 0;
    printf("npu_release: pci driver closed\n");
}

/**
 * npu_configure_layers — 配置 NPU 总层数到 FPGA 层数寄存器
 * 初始化三件套之一: 配置层数 -> 发送权重 -> 发送指令。
 * 返回 0 成功, -1 失败。重复调用幂等 (覆盖写同一值)。
 */
int npu_configure_layers(void) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_configure_layers: not initialized\n");
        return -1;
    }
    return configure_npu();
}

/**
 * npu_upload_weights — 上传 60 个权重文件到 FPGA DDR3 权重区
 *   weight_dir: 包含 conv1_weight.bin ... out3_weight.bin 的目录
 *   do_verify : 非 0 时每次上传后 DMA 读回逐字节校验 (debug 用)
 * 返回 0 全部成功, -1 存在失败。
 */
int npu_upload_weights(const char *weight_dir, int do_verify) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_upload_weights: not initialized\n");
        return -1;
    }
    if (!weight_dir) {
        fprintf(stderr, "npu_upload_weights: null weight dir\n");
        return -1;
    }
    return upload_all_weights(weight_dir, do_verify ? 1 : 0);
}

/**
 * npu_upload_instructions — 解析指令流文件并上传到 FPGA 指令区
 * 返回 指令字节数(成功), -1(失败)。
 */
int npu_upload_instructions(const char *instr_file) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_upload_instructions: not initialized\n");
        return -1;
    }
    if (!instr_file) {
        fprintf(stderr, "npu_upload_instructions: null instruction file\n");
        return -1;
    }
    return upload_npu_instructions(instr_file);
}

/**
 * npu_upload_image_file — 上传输入图像到 FPGA 输入区 (debug 用)
 *   image_path: jpg/png 走 RGA 解码+letterbox+RGBA8888; 640x640x4 raw bin 原样上传
 *   do_verify : 非 0 时上传后 DMA 读回校验
 * 返回 0 成功, -1 失败。
 */
int npu_upload_image_file(const char *image_path, int do_verify) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_upload_image_file: not initialized\n");
        return -1;
    }
    return upload_input_image(image_path, do_verify ? 1 : 0);
}

/**
 * npu_upload_image_rgba — 上传 Python 侧准备好的 640x640x4 RGBA 缓冲到 FPGA 输入区
 *   rgba     : 至少 NPU_IMAGE_SIZE 字节的 RGBA8888 数据 (预处理在 Python 完成)
 *   do_verify: 非 0 时上传后 DMA 读回校验 (debug 用)
 * 返回 0 成功, -1 失败。
 */
int npu_upload_image_rgba(const uint8_t *rgba, int do_verify) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_upload_image_rgba: not initialized\n");
        return -1;
    }
    if (!rgba) {
        fprintf(stderr, "npu_upload_image_rgba: null buffer\n");
        return -1;
    }
    uint8_t *img_area = tx_buf() + TX_IMAGE_OFFSET;
    memcpy(img_area, rgba, NPU_IMAGE_SIZE);

    if (pci_dma_single_write(pci_driver_fd, NPU_IMAGE_DDR3_ADDR, TX_IMAGE_OFFSET,
                             (uint32_t)NPU_IMAGE_SIZE) < 0) {
        fprintf(stderr, "upload image (rgba buffer) failed: %s\n", strerror(errno));
        return -1;
    }
    if (do_verify &&
        verify_write_readback(NPU_IMAGE_DDR3_ADDR, (uint32_t)NPU_IMAGE_SIZE,
                              TX_IMAGE_OFFSET, "input_image") < 0) {
        fprintf(stderr, "input image readback verify FAIL\n");
        return -1;
    }
    printf("  input image(rgba buffer) -> FPGA 0x%08X, %u bytes\n",
           NPU_IMAGE_DDR3_ADDR, (unsigned)NPU_IMAGE_SIZE);
    return 0;
}

/**
 * npu_infer_start — 发送 NPU 启动信号并阻塞等待推理完成中断
 * 调用前需已上传输入图像; 层数/权重/指令在初始化三件套中已就绪 (不再重复配置)。
 * 返回 0 成功, -1 失败 (超时 6s / 中断等待失败)。
 */
int npu_infer_start(void) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_infer_start: not initialized\n");
        return -1;
    }
    return start_npu_inference();
}

/**
 * npu_infer_read — 一次 DMA 读回三头融合输出到调用方缓冲
 *   out_buf : 由调用方分配, 至少 NPU_TOTAL_OUTPUT_SIZE (268800) 字节
 *   out_size: out_buf 可用字节数
 * 成功后 out_buf 内容为 Head1(20x20) | Head2(40x40) | Head3(80x80) 连续 int8 数据。
 * 返回 0 成功, -1 失败。
 */
int npu_infer_read(uint8_t *out_buf, int out_size) {
    if (!g_npu_init_done) {
        fprintf(stderr, "npu_infer_read: not initialized\n");
        return -1;
    }
    if (!out_buf || out_size < (int)NPU_TOTAL_OUTPUT_SIZE) {
        fprintf(stderr, "npu_infer_read: out buffer too small (%d < %u)\n",
                out_size, (unsigned)NPU_TOTAL_OUTPUT_SIZE);
        return -1;
    }
    return read_npu_output(out_buf, out_size);
}

} // extern "C"