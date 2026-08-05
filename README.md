# YOLOv5n FPGA 硬件加速

YOLOv5n 神经网络 FPGA 硬件加速全链路工程：PyTorch 训练 → INT8 量化 → FPGA RTL 实现 → ARM Linux PCIe 推理。

**目标硬件**：紫光 PG100H FPGA + Rockchip RK3568  
**数据集**：CCPD + CRPD 中国车牌检测（4 类）

---

## 目录结构

```
github_RK/
├── yolov5/                     # PyTorch 模型训练 / INT8 量化 / 权重导出
│   ├── nets/                   # YOLOv5n 网络定义 (CSPDarknet + YOLO head)
│   ├── utils/                  # 训练/推理工具 (dataloader, bbox, NMS, mAP)
│   ├── npy/                    # INT8 量化权重 & 中间激活 (→ FPGA 输入)
│   ├── npy_float/              # FP32 原始权重 (精度对比用)
│   ├── ref/                    # FPGA 逐层验证脚本 & PyTorch 参考输出
│   │   ├── gen_weight_txt_rk3568.py   # 主生成脚本：npy → txt 参数 + instruction
│   │   ├── gen_weight_util_rk3568.py  # 底层工具函数 (各算子 txt 生成)
│   │   ├── compare.py                 # FPGA DUT vs PyTorch 逐层对比
│   │   └── txt/                       # 87层子目录 (param / weight / torch txt)
│   ├── model_data/             # 训练产物：量化模型 & 类别文件
│   ├── logs/                   # 训练日志：checkpoint & loss/mAP 曲线
│   ├── train.py                # 训练入口
│   ├── quant.py                # QAT 量化 → INT8 模型
│   ├── export_npy.py           # 导出 npy 权重 + 中间激活
│   ├── predict.py / predict5n_q.py   # FP32 / INT8 图片推理
│   ├── get_map.py              # mAP 精度评估
│   └── README.md               # 训练端详细说明
│
├── FPGA/                       # FPGA 硬件逻辑
│   ├── PG_100H/                # 紫光同创 PG100H 平台
│   │   ├── yolo_fpga_hdmi/     # HDMI 显示版本
│   │   └── yolo_fpga_ov5640/   # OV5640 摄像头版本
│   │       ├── source/npu/     # NPU RTL：conv / focus / upsample / sppf 等
│   │       ├── source/HDMI/    # HDMI 视频输出
│   │       ├── source/ov5640/  # 摄像头采集 + DDR 缓存
│   │       ├── source/axi_*/   # AXI DMA / Crossbar / PCIe 桥接
│   │       ├── ipcore/         # IP 核：DDR3、PCIe PHY、乘法器
│   │       ├── synthesize/     # 综合报告
│   │       ├── place_route/    # 布局布线
│   │       └── generate_bitstream/  # 比特流 (.sbit / .bin)
│   │
│   └── Xilinx/                 # Xilinx Vivado 平台
│       └── Yolo_top/           # Vivado 工程
│           ├── sources_1/      # RTL 源码 (conv / focus / upsample / sppf / eth)
│           ├── bd/npu_ddr/     # Block Design: NPU + DDR4 + AXI Interconnect
│           └── constrs_1/      # 约束文件 (.xdc)
│
├── RK3568/                     # ARM Linux 端软件 & 驱动
│   ├── AI_car_pro_npu/         # 车载 NPU 应用
│   │   ├── app_pcie/           # PCIe 用户态 C++ 应用
│   │   └── driver/             # 内核驱动 (.ko)
│   └── AI_NPU/                 # NPU 应用变体 (通用推理)
│       ├── app_pcie/
│       └── driver/
│
├── VS_C++/                     # C++ 上位机 Xilinx使用
│   └── Yolov5/                 # 逐层 bit-accurate 仿真
│       ├── indata_bin/         # 各层输入数据 (110 .bin)
│       ├── weight_bin/         # 权重文件 (60 .bin, conv1~57)
│       ├── instruction/        # 指令文件 (88 .txt)
│       └── outdata/            # 仿真输出, 与 ref/ 比对用
│
├── DOC/                        # 项目文档
│   ├── *.md                    # 说明文档
│   ├── *.vsdx                  # Visio 架构图
│   └── *.xlsx                  # 数据表格 (引脚分配 / 性能统计)
│
└── README.md                   # 你正在看这个
```

---

## 典型工作流

```
1. yolov5/ 训练 + 量化              → INT8 模型权重 (.pth)
2. yolov5/export_npy.py            → INT8 权重/激活 .npy
3. yolov5/ref/gen_weight_txt_rk3568.py → FPGA 所需的 txt 参数 + instruction_all.txt
4. VS_C++/ 软件仿真                 → C++ 逐层 bit-accurate 验证
5. FPGA/ 综合 → 布局布线 → 比特流   → 上板调试
6. RK3568/ + FPGA/                 → ARM Linux PCIe 端到端推理
```