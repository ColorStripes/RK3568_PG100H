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
│   ├── npy/                    # INT8 量化权重 & 中间激活 (→ FPGA 输入, ~546 .npy)
│   ├── npy_float/              # FP32 原始权重 (精度对比用, ~325 .npy)
│   ├── ref/                    # FPGA 逐层验证脚本 & PyTorch 参考输出
│   │   ├── gen_weight_txt_rk3568.py   # 主生成脚本：npy → txt 参数 + instruction
│   │   ├── gen_weight_txt_rk3568_no11.py  # 变体：不含 1×1 conv 版本
│   │   ├── gen_weight_util_rk3568.py  # 底层工具函数 (各算子 txt 生成)
│   │   ├── compare.py                 # FPGA DUT vs PyTorch 逐层对比
│   │   ├── ref.py                     # 单层手动验证脚本
│   │   └── txt/                       # 87层子目录 (param / weight / torch / dut txt)
│   ├── axi_crossbar/           # AXI Crossbar RTL (.v) + Python 生成脚本
│   ├── model_data/             # 量化模型 (ccpd_crpd_quant.pth / _jit.pth) & 类别文件
│   ├── logs/                   # 训练产物：checkpoint & loss/mAP 曲线
│   ├── plate_out/              # 推理输出示例图片
│   ├── zhe/                    # 论文折线图 & 性能对比 PDF
│   ├── train.py / train_yolov5n.py / train_ddp.sh  # 训练入口 (单卡 / DDP)
│   ├── quant.py                # QAT 量化 → INT8 模型
│   ├── export_npy.py           # 导出 npy 权重 + 中间激活
│   ├── yolo.py / yolov5n_q.py  # 推理脚本 (FP32 / INT8)
│   ├── predict.py / predict5n_q.py    # 图片预测入口
│   ├── get_map.py / get_map_yolov5n.py / get_map_yolov5n_q.py  # mAP 精度评估
│   ├── make_annotation.py      # 标注生成工具
│   ├── summary.py              # 网络结构 & FLOPS 统计
│   ├── requirements.txt        # Python 依赖
│   ├── 常见问题汇总.md
│   └── README.md               # 训练端详细说明
│
├── FPGA/                       # FPGA 硬件逻辑
│   ├── PG_100H/                # 紫光同创 PG100H 平台
│   │   ├── yolo_fpga_hdmi/     # HDMI 显示版本
│   │   │   ├── source/         # 用户 RTL
│   │   │   │   ├── npu/       # conv / focus / upsample / sppf / cat_add / out_buf / para / reg
│   │   │   │   ├── HDMI/      # HDMI 视频输出
│   │   │   │   ├── ov5640/    # 摄像头采集 + DDR 缓存
│   │   │   │   ├── axi_crossbar/  # AXI 互联
│   │   │   │   ├── axi_dma/       # AXI DMA
│   │   │   │   ├── pcie_dma/      # PCIe DMA 控制器
│   │   │   │   ├── pcie2npu/      # PCIe → NPU 桥接
│   │   │   │   └── constraints/   # 管脚约束 (.fdc)
│   │   │   └── ipcore/        # IP 核：DDR3、PCIe PHY、FIFO、乘法器、CDC
│   │   │
│   │   └── yolo_fpga_ov5640/   # OV5640 摄像头版本 (结构同 hdmi 版)
│   │       ├── source/         # 用户 RTL (npu / HDMI / ov5640 / axi_* / pcie_*)
│   │       └── ipcore/         # IP 核
│   │
│   └── Xilinx/                 # Xilinx Vivado 平台
│       └── Yolo_top/           # Vivado 工程
│           ├── yolo_top.srcs/
│           │   ├── sources_1/  # RTL: conv / focus / upsample / sppf / eth / eth2cmd / npu_top / ...
│           │   ├── constrs_1/  # 管脚约束 (.xdc)
│           │   └── bd/npu_ddr/ # Block Design: NPU + DDR4 + AXI Interconnect
│           ├── Yolo_top.ip_user_files/  # IP 封装 & 仿真脚本
│           ├── Yolo_top.sim/   # 仿真工作区
│           └── Yolo_top.hw/    # ILA 调试波形
│
├── RK3568/                     # ARM Linux 端软件 & 驱动
│   ├── image/                  # 系统镜像 (.img)
│   └── master/                 # C上位机
│       ├── AI_car_pro_npu/     # 车载 NPU 应用 (视频流 + 串口)
│       │   ├── app_pcie/       # PCIe 用户态 C++ 应用
│       │   └── driver/         # 内核驱动 (.ko)
│       └── AI_NPU/             # 通用 NPU 推理
│           ├── app_pcie/
│           └── driver/
│
├── VS_C++/                     # C++ 上位机 (Windows, VS2019)
│   └── Yolov5/                 # 逐层 bit-accurate 仿真工程
│       ├── yolo_fpga.cpp / .h  # 主仿真源码
│       ├── indata_bin/         # 各层输入数据 (110 .bin)
│       ├── weight_bin/         # 权重文件 (60 .bin, conv1~57 + out1~3)
│       ├── instruction/        # 指令文件 (88 .txt)
│       ├── outdata/            # 仿真输出, 与 ref/ 比对用 (35 .txt)
│       ├── torch_bin/          # PyTorch 参考输出 (.bin)
│       ├── img/                # 测试图片 (.jpg)
│       └── Yolov5.sln / .vcxproj  # VS 解决方案
│
├── DOC/                        # 项目文档
│   ├── FPGA算子开发.md
│   ├── SDK修改设备树（编译boot.img).md
│   ├── yolov5n网络结构.vsdx     # Visio 架构图
│   ├── 模型执行顺序.xlsx
│   ├── 算子序号.xlsx
│   └── 网络地址分配.xlsx
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