# FPGA YOLO — YOLOv5n 量化部署到 RK3568 FPGA

基于 [bubbliiiing/yolov5-v6.1-pytorch](https://github.com/bubbliiiing/yolov5-v6.1-pytorch) 修改，目标是将 YOLOv5n 量化后部署到 Rockchip RK3568 的 FPGA/NPU 上，数据集为 CCPD + CRPD 中国车牌识别（4 类）。

---

## 目录结构

| 目录 / 文件 | 说明 |
|---|---|
| `nets/` | YOLOv5 网络定义：backbone、neck、head |
| `utils/` | 训练/推理工具：数据加载、bbox 编解码、mAP 计算、回调等 |
| `model_data/` | 训练产物：量化后的模型权重和类别文件 |
| `logs/` | 训练日志：checkpoint、TensorBoard events、loss/mAP 曲线 |
| `npy/` | 量化 INT8 权重，供 FPGA 工具链使用 (546 个 .npy) |
| `npy_float/` | FP32 原始权重，供对比参考 (345 个 .npy) |
| `ref/` | FPGA 逐层验证：PyTorch 参考输出、参数文件、DUT 比对脚本 |
| `ref/txt/` | 87 个子目录，每层一目录，含 `_in_data.txt`、`_param.txt`、`_torch.txt`、`_weight.txt` |
| `axi_crossbar/` | AXI 互联模块 Verilog 源码 (7x1 / 7x2 / 7x3) |
| `plate_out/` | 预测结果样例图片 |
| `zhe/` | 论文用图表生成脚本 |
| **根目录脚本** | |
| `train.py` / `train_yolov5n.py` | 训练入口 |
| `train_ddp.sh` | 分布式训练启动脚本 |
| `yolo.py` | FP32 推理主类 |
| `yolov5n_q.py` | INT8 量化推理主类 |
| `predict.py` | FP32 图片预测 |
| `predict5n_q.py` | INT8 量化图片预测 |
| `quant.py` | PyTorch 量化（QAT → INT8） |
| `export_npy.py` | 导出量化后的 npy 权重 + 中间层激活值 |
| `genPth.py` | 将原始 yolov5n 权重映射为本工程命名格式 |
| `get_weight.py` | 从量化 pth 中提取 INT8 权重/scale/zero_point |
| `summary.py` | 打印网络结构 & FLOPs/参数量 |
| `get_map.py` / `get_map_yolov5n.py` / `get_map_yolov5n_q.py` | mAP 评估 |
| `kmeans_for_anchors.py` | 对数据集标注框聚类生成 anchor |
| `make_annotation.py` | 将 CRPD/CCPD 原始标注整合为训练格式 |
| `常见问题汇总.md` | 中文 FAQ |
| `requirements.txt` | Python 依赖 |

---

## 各目录详述

### `nets/` — 网络结构

```
nets/
├── CSPdarknet.py      # CSPDarknet backbone
├── yolo.py            # YOLO head（三个检测尺度的输出层）
├── yolo_training.py   # 训练时专用 loss 计算逻辑
└── yolov5n.py         # YOLOv5n 完整模型组装
```

### `utils/` — 工具模块

```
utils/
├── dataloader.py      # 数据集加载 (VOC 格式)
├── utils.py           # 通用工具 (resize、颜色空间转换等)
├── utils_bbox.py      # bbox 编解码、NMS、IoU
├── utils_fit.py       # 训练/验证循环
├── utils_map.py       # mAP 计算
├── callbacks.py       # 训练回调 (LossHistory 等)
└── paths.py           # 数据路径配置
```

### `model_data/` — 训练产物

| 文件 | 说明 |
|---|---|
| `CCPD_CRPD_classes.txt` | 4 类标签：blue / yellow / green / special |
| `ccpd_crpd_quant.pth` | 量化后模型权重 |
| `ccpd_crpd_quant_jit.pth` | TorchScript JIT 量化模型（推理用） |

### `logs/` — 训练日志

| 文件 | 说明 |
|---|---|
| `best_epoch_weights.pth` | 验证集最优权重 |
| `last_epoch_weights.pth` | 最后一个 epoch 权重 |
| `ep300-loss0.019-val_loss0.019.pth` | epoch 300 checkpoint |
| `loss_2026_07_14_00_43_35/` | TensorBoard 日志 + loss/mAP 曲线图 |

### `npy/` — 量化 INT8 权重（FPGA 工具链输入）

命名规则：`backbone.conv{N}.conv.{weight,bias,scale,zero_point}.npy` 和 `img_conv{N}.int.npy`（中间层激活值）。

包含一个 C 头文件 `fpga_params.h`，供 FPGA 工程直接 `#include`。

### `npy_float/` — FP32 权重（对比参考）

包含 345 个 `.npy` 文件，均为 FP32 精度，用于和量化后的 INT8 结果做数值对比。

### `ref/` — FPGA 逐层验证

核心脚本：

| 脚本 | 说明 |
|---|---|
| `gen_weight_txt_rk3568.py` | 主生成脚本：从 npy 生成每层的 param/weight/torch.txt，并合成最终 `instruction_all.txt` |
| `gen_weight_util_rk3568.py` | 底层工具函数：conv/add/cat/up/max 各算子的 txt 生成、参数计算 |
| `gen_weight_txt_rk3568_no11.py` | 同上但不含 1×1 卷积的 _para 版本（用于对比） |
| `ref.py` | 单层手动验证脚本（调参 debug 用） |
| `compare.py` | FPGA DUT 输出 vs PyTorch 参考输出逐元素对比 |

`ref/txt/` 下每个子目录对应一个网络层（共 87 层），包含：

- `{layer}_in_data.txt` — 输入特征图
- `{layer}_param.txt` — 层参数（地址、量化 scale/zero、stride/padding）
- `{layer}_torch.txt` — PyTorch 参考输出
- `{layer}_weight.txt` — 量化权重/偏置
- `dut{N}_my.txt` — FPGA DUT 实际输出（部分层）
- `output_dif.txt` — 逐元素差异分析（部分层）

覆盖层类型：focus → conv1~57 → add0~6 → cat0~12 → up0~1 → out1~3 → max1~3

### `axi_crossbar/` — AXI 互联 Verilog

| 文件 | 说明 |
|---|---|
| `axi_crossbar_7x1.v` | 7 主 1 从 |
| `axi_crossbar_7x2.v` | 7 主 2 从 |
| `axi_crossbar_7x3.v` | 7 主 3 从 (903 行) |
| `axi_crossbar.py` | Python 配置/包装 |

---

## 根目录脚本速查

| 脚本 | 用途 | 何时运行 |
|---|---|---|
| `make_annotation.py` | 将 CRPD/CCPD 原始标注转为训练格式 (9:1 划分) | 数据准备阶段 |
| `kmeans_for_anchors.py` | 聚类生成 anchor | 数据集更换后 |
| `genPth.py` | 将官方 yolov5n 权重 key 映射为本工程命名 | 首次导入预训练权重 |
| `train.py` | VOC 数据集训练 | 训练入口 |
| `train_yolov5n.py` | YOLOv5n 特化训练 | 日常训练 |
| `quant.py` | QAT 量化 → INT8 模型导出 | 训练完成后 |
| `export_npy.py` | 导出量化权重 + 中间激活值为 .npy | 量化后，FPGA 部署前 |
| `get_weight.py` | 从量化 pth 中提取权重信息 | 调试/验证量化结果 |
| `get_map.py` / `get_map_yolov5n.py` / `get_map_yolov5n_q.py` | mAP 评估 | 验证模型精度 |
| `predict.py` / `predict5n_q.py` | 单张图片推理 | 测试/演示 |
| `yolo.py` / `yolov5n_q.py` | 推理主类（被 predict 调用） | — |
| `summary.py` | 打印网络 FLOPs/参数量 | 分析网络规模 |

---

## 典型工作流

```
1. make_annotation.py          → 生成 CCPD_CRPD_train.txt / val.txt
2. kmeans_for_anchors.py       → 更新 anchors（可选）
3. genPth.py                   → 转换预训练权重命名
4. train_yolov5n.py            → 训练（logs/ 下产出 .pth）
5. quant.py                    → QAT 量化 → ccpd_crpd_quant.pth
6. export_npy.py               → 导出 npy/ 下全部 INT8 权重和激活
7. cd ref/ && python gen_weight_txt_rk3568.py → 生成 FPGA 所需的 txt + instruction_all.txt
8. compare.py                  → FPGA DUT 输出 vs PyTorch 参考逐层比对
```

---

## 数据集

CCPD + CRPD 中国车牌检测，4 类：

| 类别 | 含义 |
|---|---|
| blue | 蓝牌（燃油车） |
| yellow | 黄牌（大型车） |
| green | 绿牌（新能源） |
| special | 特殊车牌 |

训练图片统一按 9:1 划分为训练集/验证集，输入尺寸 640×640。

---

## 环境依赖

见 `requirements.txt`：

```
torch
torchvision
tensorboard
numpy==1.17.0
matplotlib==3.1.2
opencv==4.1.2
tqdm==4.60.0
Pillow==8.2.0
h5py==2.10.0
```

推荐 torch ≥ 1.7.1（支持 AMP 混合精度），量化需 torch ≥ 1.8。

---

## 参考

- 上游训练框架：[bubbliiiing/yolov5-v6.1-pytorch](https://github.com/bubbliiiing/yolov5-v6.1-pytorch)
- 原始 YOLOv5：[ultralytics/yolov5](https://github.com/ultralytics/yolov5)
- 目标硬件：Rockchip RK3568