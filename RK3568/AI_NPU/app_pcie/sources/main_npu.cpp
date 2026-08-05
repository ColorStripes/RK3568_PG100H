/**
 * main_npu.cpp — YOLOv5 NPU 推理上位机程序
 *
 * 功能:
 *   1. 加载 NPU 权重 (.bin) 和指令 (.txt) 文件
 *   2. 通过 pci_dma_single_write 上传到 FPGA DDR3
 *   3. 启动 NPU 推理并等待完成
 *   4. 通过 pci_dma_single_read 读取 NPU 输出结果并保存
 *
 * FPGA DDR3 内存布局 (480MB, 起始 0x02000000):
 *   ┌──────────────────────────────────────┐  0x02000000
 *   │  权重区 (60 层 × 1MB)                │  ~60MB
 *   │  conv1.bin ... out3.bin              │
 *   ├──────────────────────────────────────┤  0x05C00000
 *   │  空闲                                │
 *   ├──────────────────────────────────────┤  0x06000000
 *   │  输入图像 (focus)                    │
 *   ├──────────────────────────────────────┤  0x06800000
 *   │  BUF_1: 通用特征图缓冲               │
 *   ├──────────────────────────────────────┤  0x07000000
 *   │  三头输出 (FPGA 连续存放)             │
 *   │  Head1 20×20 | Head2 40×40 | Head3 80×80 │
 *   │  主机一次 DMA 从 0x07000000 读完      │  ~263KB
 *   ├──────────────────────────────────────┤  0x07041A00
 *   │  BUF_3~BUF_B: 中间计算缓冲           │
 *   ├──────────────────────────────────────┤  0x0C000000
 *   │  空闲                                │
 *   ├──────────────────────────────────────┤  0x40000000
 *   │  NPU 指令流                          │  ~2MB
 *   ├──────────────────────────────────────┤  0x40200000
 *   │  空闲                                │
 *   ├──────────────────────────────────────┤  0x50000000
 *   │  NPU 总层数寄存器                     │  4B
 *   └──────────────────────────────────────┘
 *
 * 主机 RX 缓冲区 (NPU 三头融合读取):
 *   0x007E9000  Head1 | Head2 | Head3  连续存放, 总大小 NPU_HEAD1+2+3_SIZE
 *
 * 主机 TX 缓冲区 (3MB, 后 2.5MB 分区):
 *   0x080000  层数 | 0x081000  启动信号 | 0x082000  权重 staging
 *   0x182000  输入图片 | 0x2AE000  指令流
 *
 * 编译: 参考 app_pcie/Makefile
 * 运行: sudo ./npu_inference <weights_dir> <instruction_file> [output_dir]
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
#include <signal.h>

// ---- 辅助 ----
static uint8_t* tx_buf() { return (uint8_t *)dma_operation.data.write_buf; }
static uint8_t* rx_buf() { return (uint8_t *)dma_operation.data.read_buf; }

static uint64_t get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
// =====================================================================
// DMA 写后读回校验
// =====================================================================

/**
 * verify_write_readback — 将刚写到 DDR3 的数据读回，与 TX 缓冲区原始数据对比
 *   ddr3_addr : FPGA DDR3 地址
 *   total_size: 字节数
 *   name      : 描述名 (用于日志)
 *   返回 0 表示一致，-1 表示有不匹配
 */
static int verify_write_readback(uint32_t ddr3_addr, uint32_t total_size, const char *name) {
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

    const uint8_t *src = tx_buf() + TX_WEIGHT_OFFSET;
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

static uint32_t parse_hex_line(const char *line) {
    return (uint32_t)strtoul(line, NULL, 16);
}

static int upload_weight_file(const char *bin_path, int weight_index) {
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
    return 0;
}

static int upload_all_weights(const char *weight_dir) {
    printf("\n--- upload NPU weights ---\n");
    int failures = 0;
    for (int i = 1; i <= 57; i++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/conv%d_weight.bin", weight_dir, i);
        if (upload_weight_file(path, i - 1) < 0) failures++;
    }
    for (int i = 1; i <= 3; i++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/out%d_weight.bin", weight_dir, i);
        if (upload_weight_file(path, 57 + i - 1) < 0) failures++;
    }
    printf("weight upload done: %d failed\n", failures);
    return (failures > 0) ? -1 : 0;
}

static int upload_input_image(void) {
    printf("\n--- upload input image ---\n");

    if (NPU_IMAGE_SIZE > TX_INSTR_OFFSET - TX_IMAGE_OFFSET) {
        fprintf(stderr, "error: TX image area insufficient, need %u bytes\n",
                (unsigned)NPU_IMAGE_SIZE);
        return -1;
    }

    if (pci_dma_single_write(pci_driver_fd, NPU_IMAGE_DDR3_ADDR, TX_IMAGE_OFFSET, (uint32_t)NPU_IMAGE_SIZE) < 0) {
        fprintf(stderr, "upload image failed: %s\n", strerror(errno));
        return -1;
    }
    printf("  input image(TX offset 0x%08X) -> FPGA 0x%08X, %u bytes (%dx%dx%d RGB888)\n",
           TX_IMAGE_OFFSET, NPU_IMAGE_DDR3_ADDR, (unsigned)NPU_IMAGE_SIZE,
           NPU_INPUT_W, NPU_INPUT_H, NPU_INPUT_C);
    return 0;
}

// =====================================================================
// NPU configure
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

/**
 * dump_head_to_txt — dump quantized int8 output by channel to readable txt
 *   data    : output data (int8 format)
 *   spatial : HxW (e.g. 20x20, 40x40, 80x80)
 *   prefix  : file path prefix (without extension)
 */
static void dump_head_to_txt(const int8_t *data, int spatial_dim, const char *prefix) {
    char path[512];
    snprintf(path, sizeof(path), "%s.txt", prefix);
    FILE *fp = fopen(path, "w");
    if (!fp) { fprintf(stderr, "cannot create %s\n", path); return; }

    int H = spatial_dim, W = spatial_dim;
    fprintf(fp, "# %dx%d x %d channels (int8)\n", H, W, NPU_FPGA_CH);
    fprintf(fp, "# ch layout: 3 anchors x [tx ty tw th obj] + %d classes + %d pad\n",
            NPU_NUM_CLASSES, NPU_PAD_CHANNELS);

    for (int ch = 0; ch < NPU_FPGA_CH; ch++) {
        fprintf(fp, "\n--- channel %2d ---\n", ch);
        for (int r = 0; r < H; r++) {
            for (int c = 0; c < W; c++) {
                int idx = ch * H * W + r * W + c;
                fprintf(fp, "%4d ", (int)data[idx]);
            }
            fprintf(fp, "\n");
        }
    }
    fclose(fp);
    printf("  saved txt: %s\n", path);
}

static int start_npu_and_read_output(const char *output_dir) {
    printf("\n--- start NPU inference ---\n");

    struct { const char *name; uint32_t size; uint32_t host_off; int spatial; } heads[] = {
        { "head1_20x20", NPU_HEAD1_SIZE, NPU_HOST_OUTPUT_BASE, 20 },
        { "head2_40x40", NPU_HEAD2_SIZE, NPU_HEAD2_HOST_OFFSET, 40 },
        { "head3_80x80", NPU_HEAD3_SIZE, NPU_HEAD3_HOST_OFFSET, 80 },
    };
    uint32_t total_size = NPU_TOTAL_OUTPUT_SIZE;

    // step 1: send NPU start signal (0xF0F0F0F0 -> 0x40000000)
    *(uint32_t *)(tx_buf() + TX_START_OFFSET) = NPU_START_MAGIC;
    printf("send NPU start signal 0x%08X -> FPGA 0x%08X\n", NPU_START_MAGIC, NPU_INSTR_DDR3_BASE);
    int ret = pci_dma_single_write(pci_driver_fd, NPU_INSTR_DDR3_BASE, TX_START_OFFSET, 4);
    if (ret < 0) {
        fprintf(stderr, "NPU start signal send failed: %s\n", strerror(errno));
        return -1;
    }

    uint64_t t_start = get_time_ms();

    // step 2: wait for NPU completion (interrupt-driven)
    printf("waiting for NPU completion (interrupt wait)...\n");
    ret = ioctl(pci_driver_fd, PCI_GET_NPU, &dma_operation);
    if (ret < 0) {
        if (errno == ETIMEDOUT) {
            fprintf(stderr, "NPU inference timeout (60s)\n");
        } else {
            fprintf(stderr, "NPU interrupt wait failed: %s\n", strerror(errno));
        }
        return -1;
    }

    uint64_t t_end = get_time_ms();
    printf("NPU inference done! elapsed: %llu ms\n", (unsigned long long)(t_end - t_start));

    // step 3: single DMA read for all three heads
    printf("DMA read three-head continuous data: FPGA 0x%08X -> Host 0x%06X, %u bytes\n",
           NPU_OUTPUT_DDR3_BASE, NPU_HOST_OUTPUT_BASE, total_size);
    ret = pci_dma_single_read(pci_driver_fd, NPU_OUTPUT_DDR3_BASE, NPU_HOST_OUTPUT_BASE, total_size);
    if (ret < 0) {
        fprintf(stderr, "DMA read NPU output failed: %s\n", strerror(errno));
        return -1;
    }

    // step 4: save three-head output (commented out by default)
    // for (int i = 0; i < 3; i++) {
    //     char out_path[512];
    //     snprintf(out_path, sizeof(out_path), "%s/%s_output.bin", output_dir, heads[i].name);
    //     FILE *fp = fopen(out_path, "wb");
    //     if (!fp) { fprintf(stderr, "cannot create %s\n", out_path); continue; }
    //     size_t written = fwrite(rx_buf() + heads[i].host_off, 1, heads[i].size, fp);
    //     fclose(fp);
    //     if (written == heads[i].size)
    //         printf("  saved: %s (%u bytes)\n", out_path, heads[i].size);
    //     else
    //         fprintf(stderr, "  write incomplete: %s (%u/%u)\n", out_path, (unsigned)written, heads[i].size);
    //     snprintf(out_path, sizeof(out_path), "%s/%s_output", output_dir, heads[i].name);
    //     dump_head_to_txt((const int8_t *)(rx_buf() + heads[i].host_off), heads[i].spatial, out_path);
    // }
    return 0;
}

static int check_instruction_file(const char *instr_file) {
    FILE *fp = fopen(instr_file, "r");
    if (!fp) return -1;
    char line_buf[64];
    uint32_t word_count = 0;
    printf("instruction file preview:\n");
    while (fgets(line_buf, sizeof(line_buf), fp) && word_count < 20) {
        char *p = line_buf;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '\0' || *p == '\n' || *p == '\r') continue;
        size_t len = strlen(p);
        while (len > 0 && (p[len-1] == '\n' || p[len-1] == '\r')) p[--len] = '\0';
        printf("  [%3u] 0x%08X\n", word_count, parse_hex_line(p));
        word_count++;
    }
    fclose(fp);
    if (word_count > 0) printf("  ... (total %u+ instruction words)\n", word_count);
    return 0;
}


// =====================================================================
// Ctrl+C signal handler
// =====================================================================
static void sigint_handler(int sig) {
    (void)sig;
    fprintf(stderr, "\n[interrupt] Ctrl+C received, releasing resources...\n");
    if (pci_driver_fd >= 0) {
        pci_umap(pci_driver_fd);
        close(pci_driver_fd);
        pci_driver_fd = -1;
    }
    _exit(0);
}


// ---- NPU kernel ioctl interface (match driver pango_pci_driver) ----
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

// =====================================================================
// NPU kernel ioctl wrappers
// =====================================================================

static int pci_npu_upload_instr(uint32_t fpga_ddr3_addr, uint32_t instr_size)
{
    NPU_CONFIG npu_cfg = {};
    npu_cfg.instr_ddr3_addr    = fpga_ddr3_addr;
    npu_cfg.instr_total_size   = instr_size;
    if (ioctl(pci_driver_fd, PCI_NPU_UPLOAD_CMD, &npu_cfg) < 0) {
        printf("PCI_NPU_UPLOAD_CMD failed! %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

static int pci_npu_start_and_wait(uint32_t output_ddr3_addr, uint32_t output_size, uint32_t output_host_offset)
{
    NPU_CONFIG npu_cfg = {};
    npu_cfg.instr_ddr3_addr    = NPU_INSTR_DDR3_BASE;
    npu_cfg.output_ddr3_addr   = output_ddr3_addr;
    npu_cfg.output_total_size  = output_size;
    npu_cfg.output_host_offset = output_host_offset;
    if (ioctl(pci_driver_fd, PCI_NPU_UPLOAD_CMD, &npu_cfg) < 0) return -1;
    if (ioctl(pci_driver_fd, PCI_NPU_START_CMD, &npu_cfg) < 0) {
        printf("NPU start failed! %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

static int pci_npu_read_output(uint32_t fpga_ddr3_addr, uint32_t output_size, uint32_t host_offset)
{
    NPU_CONFIG npu_cfg = {};
    npu_cfg.instr_ddr3_addr    = NPU_INSTR_DDR3_BASE;
    npu_cfg.output_ddr3_addr   = fpga_ddr3_addr;
    npu_cfg.output_total_size  = output_size;
    npu_cfg.output_host_offset = host_offset;
    if (ioctl(pci_driver_fd, PCI_NPU_GET_OUTPUT_CMD, &npu_cfg) < 0) {
        printf("NPU read output failed! %s\n", strerror(errno));
        return -1;
    }
    return 0;
}


// =====================================================================
// main
// =====================================================================
int main(int argc, char *argv[]) {
    signal(SIGINT, sigint_handler);
    
    if (argc < 3) {
        printf("usage: %s <weights_dir> <instruction_file> [output_dir]\n", argv[0]);
        printf("  weights_dir: conv*_weight.bin + out*_weight.bin\n");
        printf("  instruction_file: instruction_all.txt\n");
        printf("  output_dir: (optional) default .\n");
        printf("  input image: pre-written to TX buffer by caller, DMA upload by this program\n");
        return 1;
    }

    const char *weight_dir = argv[1];
    const char *instr_file = argv[2];
    const char *output_dir = (argc >= 4) ? argv[3] : ".";

    printf("========================================\n");
    printf("  YOLOv5 NPU Inference Host\n");
    printf("========================================\n");
    printf("weights: %s  instr: %s  output: %s\n", weight_dir, instr_file, output_dir);

    check_instruction_file(instr_file);

    pci_driver_fd = open_pci_driver();
    if (pci_driver_fd < 0) { fprintf(stderr, "PCIe driver open failed!\n"); return -1; }

    if (pci_map(pci_driver_fd, 3, TX_BUF_SIZE, RX_BUF_SIZE) < 0) {
        fprintf(stderr, "DMA address mapping failed!\n"); close(pci_driver_fd); return -1;
    }

    dma_operation.data = pci_mmp(pci_driver_fd, 3, TX_BUF_SIZE, RX_BUF_SIZE);
    if (!dma_operation.data.write_buf || !dma_operation.data.read_buf) {
        fprintf(stderr, "mmap DMA buffer failed!\n");
        pci_umap(pci_driver_fd); close(pci_driver_fd); return -1;
    }
    printf("DMA mmap done: TX=%p RX=%p\n", dma_operation.data.write_buf, dma_operation.data.read_buf);

    
    int ret = 0;

    if (upload_all_weights(weight_dir) < 0)   { ret = -1; goto cleanup; }

    if (upload_input_image() < 0) { ret = -1; goto cleanup; }

    if (configure_npu() < 0) { ret = -1; goto cleanup; }
    if (upload_npu_instructions(instr_file) < 0) { ret = -1; goto cleanup; }
    if (start_npu_and_read_output(output_dir) < 0) { ret = -1; goto cleanup; }

    printf("\n========================================\n");
    printf("  NPU inference all done!\n");
    printf("========================================\n");

cleanup:
    pci_umap(pci_driver_fd);
    close(pci_driver_fd);
    return ret;
}