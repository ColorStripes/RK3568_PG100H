#ifndef NPU_CONFIG_H
#define NPU_CONFIG_H

/**
 * npu_config.h — NPU 检测头、FPGA DDR3 地址、主机 TX/RX 缓冲区布局
 *
 * 用户态程序 (main_npu.cpp / dma_bridge_rga.cpp) 统一引用此头文件。
 * 修改检测类别数时只需改 NPU_NUM_CLASSES。
 */

// ---- 主机 DMA 缓冲区大小 ----
#define TX_BUF_SIZE             (3 * 1024 * 1024UL)
#define RX_BUF_SIZE             (10 * 1024 * 1024UL)

// ---- FPGA DDR3 地址 ----
#define NPU_INSTR_DDR3_BASE     0x40000000
#define NPU_WEIGHT_DDR3_BASE    0x02000000
#define NPU_WEIGHT_STRIDE       0x00100000
#define NPU_IMAGE_DDR3_ADDR     0x06000000

// ---- 输入图像 (RGB888 640×640) ----
#define NPU_INPUT_W             640
#define NPU_INPUT_H             640
#define NPU_INPUT_C             3
#define NPU_IMAGE_SIZE          (NPU_INPUT_W * NPU_INPUT_H * NPU_INPUT_C)

// ---- 主机 TX 缓冲区分区 (后 2.5MB, 互不重叠) ----
#define TX_CAMERA_RESERVED      (512 * 1024)
#define TX_NPU_BASE             TX_CAMERA_RESERVED
#define TX_LAYER_OFFSET         TX_NPU_BASE
#define TX_LAYER_SIZE           0x1000
#define TX_START_OFFSET         (TX_LAYER_OFFSET + TX_LAYER_SIZE)
#define TX_START_SIZE           0x1000
#define TX_WEIGHT_OFFSET        (TX_START_OFFSET + TX_START_SIZE)
#define TX_WEIGHT_SIZE          NPU_WEIGHT_STRIDE
#define TX_IMAGE_OFFSET         (TX_WEIGHT_OFFSET + TX_WEIGHT_SIZE)
#define TX_INSTR_OFFSET         (TX_IMAGE_OFFSET + NPU_IMAGE_SIZE)
#define TX_INSTR_SIZE           (TX_BUF_SIZE - TX_INSTR_OFFSET)

// ---- 主机 RX 缓冲区中 NPU 三头融合输出区 ----
#define NPU_HOST_OUTPUT_BASE    0x007E9000

// ---- NPU 检测头参数 ----
#define NPU_NUM_CLASSES         4
#define NPU_BBOX_PARAMS         5
#define NPU_NUM_ANCHORS         3
#define NPU_FPGA_CH             32

#define NPU_EFFECTIVE_CH        (NPU_NUM_ANCHORS * (NPU_BBOX_PARAMS + NPU_NUM_CLASSES))
#define NPU_PAD_CHANNELS        (NPU_FPGA_CH - NPU_EFFECTIVE_CH)

#define NPU_HEAD1_SPATIAL       (20 * 20)
#define NPU_HEAD2_SPATIAL       (40 * 40)
#define NPU_HEAD3_SPATIAL       (80 * 80)

#define NPU_HEAD1_SIZE          (NPU_HEAD1_SPATIAL * NPU_FPGA_CH)
#define NPU_HEAD2_SIZE          (NPU_HEAD2_SPATIAL * NPU_FPGA_CH)
#define NPU_HEAD3_SIZE          (NPU_HEAD3_SPATIAL * NPU_FPGA_CH)
#define NPU_TOTAL_OUTPUT_SIZE   (NPU_HEAD1_SIZE + NPU_HEAD2_SIZE + NPU_HEAD3_SIZE)

// 三头在 FPGA DDR3 上连续排列 (out1→out2→out3, 20→40→80)
#define NPU_OUTPUT_DDR3_BASE    0x07000000
#define NPU_HEAD1_DDR3_ADDR     NPU_OUTPUT_DDR3_BASE
#define NPU_HEAD2_DDR3_ADDR     (NPU_HEAD1_DDR3_ADDR + NPU_HEAD1_SIZE)
#define NPU_HEAD3_DDR3_ADDR     (NPU_HEAD2_DDR3_ADDR + NPU_HEAD2_SIZE)

// 三头在主机 RX 缓冲区中的偏移 (连续存放)
#define NPU_HEAD2_HOST_OFFSET   (NPU_HOST_OUTPUT_BASE + NPU_HEAD1_SIZE)
#define NPU_HEAD3_HOST_OFFSET   (NPU_HEAD2_HOST_OFFSET + NPU_HEAD2_SIZE)

// ---- NPU 控制 (与 FPGA RTL pcie_npu.v 约定一致) ----
#define NPU_START_MAGIC         0xF0F0F0F0
#define NPU_LAYER_ADDR          0x50000000
#define NPU_LAYER_NUM           53

#endif /* NPU_CONFIG_H */