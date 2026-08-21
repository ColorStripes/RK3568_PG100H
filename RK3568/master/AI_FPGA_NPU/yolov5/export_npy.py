"""
导出 gen_weight_txt_rk3568.py 所需的全部 npy 文件：
  1. 权重/scale/zero_point（来自量化 pth）
  2. 中间层 int 激活（量化模型前向推理时 dump）
"""
import argparse
import os

import cv2
import numpy as np
import torch
from PIL import Image
from torch.ao.quantization import QConfig, HistogramObserver, default_weight_observer

import nets.yolov5n as yolov5n_module
from get_weight import load_state_dict, to_npy
from nets.yolov5n import YoloV5n
from utils.paths import ROOT
from utils.utils import get_anchors, get_classes, preprocess_input, resize_image

DEFAULT_ANCHORS_PATH = "model_data/yolo_anchors.txt"
ANCHORS_MASK = [[6, 7, 8], [3, 4, 5], [0, 1, 2]]
INPUT_SHAPE = (640, 640)

ACTIVATION_FILES = [
    "quant.int.npy", "img.int.npy",
    *[f"img_conv{i}.int.npy" for i in range(1, 58)],
    *[f"add{i}.int.npy" for i in range(7)],
    *[f"cat{i}.int.npy" for i in range(13)],
    "max1.int.npy", "max2.int.npy", "max3.int.npy",
    "upsample_0.int.npy", "upsample_1.int.npy",
    "out1.int.npy", "out2.int.npy", "out3.int.npy",
]


def load_quant_model(model_path, num_classes):
    yolov5n_module.SAVE_NUMPY = True
    model = YoloV5n(num_classes)
    model.eval()
    model.fuse_model()
    model.qconfig = QConfig(
        activation=HistogramObserver.with_args(reduce_range=False),
        weight=default_weight_observer,
    )
    prepared = torch.quantization.prepare(model)
    model_int8 = torch.quantization.convert(prepared)
    model_int8.load_state_dict(load_state_dict(model_path))
    model_int8.SAVE_NUMPY = True
    model_int8.backbone.SAVE_NUMPY = True
    return model_int8.eval()


def preprocess_image(path, input_shape=(640, 640), letterbox=True):
    img = cv2.imread(path)
    if img is None:
        raise FileNotFoundError(f"无法读取图片: {path}")
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = Image.fromarray(img)
    img = resize_image(img, input_shape, letterbox_image=letterbox)
    data = np.expand_dims(
        np.transpose(preprocess_input(np.array(img, dtype="float32")), (2, 0, 1)), 0
    )
    return torch.from_numpy(data)


def export_activations(model, image_path):
    os.chdir(ROOT)
    yolov5n_module.SAVE_NUMPY = True
    model.SAVE_NUMPY = True
    model.backbone.SAVE_NUMPY = True
    x = preprocess_image(image_path)
    with torch.no_grad():
        model(x)


def check_activations(out_dir):
    missing = [name for name in ACTIVATION_FILES if not os.path.isfile(os.path.join(out_dir, name))]
    return missing


def read_scalar_npy(path):
    value = np.load(path)
    return np.asarray(value).reshape(-1)[0]


def load_anchor_arrays(anchors_path):
    anchors, _ = get_anchors(anchors_path)
    anchor_w = [int(round(w)) for w, _ in anchors]
    anchor_h = [int(round(h)) for _, h in anchors]
    return anchor_w, anchor_h


def format_scaled_anchors(anchor_w, anchor_h, grid_h, grid_w, mask):
    stride_h = INPUT_SHAPE[0] / grid_h
    stride_w = INPUT_SHAPE[1] / grid_w
    aw = [f"{anchor_w[i] * 1.0 / stride_w:.17g}" for i in mask]
    ah = [f"{anchor_h[i] * 1.0 / stride_h:.17g}" for i in mask]
    return aw, ah


def build_fpga_param_lines(out_dir, anchors_path):
    """生成 FPGA / NMS 头文件可直接粘贴的 C++ 参数行。"""
    quant_scale = float(read_scalar_npy(os.path.join(out_dir, "quant.scale.npy")))
    quant_zero = int(read_scalar_npy(os.path.join(out_dir, "quant.zero_point.npy")))

    # conv1/conv2/conv3 对应 20x20 / 40x40 / 80x80 三个检测头
    head_names = ("conv1", "conv2", "conv3")
    nms_scale = []
    nms_zero = []
    for name in head_names:
        nms_scale.append(float(read_scalar_npy(os.path.join(out_dir, f"{name}.scale.npy"))))
        nms_zero.append(int(read_scalar_npy(os.path.join(out_dir, f"{name}.zero_point.npy"))))

    anchor_w, anchor_h = load_anchor_arrays(anchors_path)

    lines = [
        f"double quant_scale = {quant_scale:.8f};",
        f"int quant_zero = {quant_zero};",
        "",
        "double nms_scale[3] = { "
        + ", ".join(f"{v:.17g}" for v in nms_scale)
        + " };",
        "double nms_zero[3]  = { " + ", ".join(str(v) for v in nms_zero) + " };",
        "",
        "int anchor_w[9] = { " + ", ".join(str(v) for v in anchor_w) + " };",
        "int anchor_h[9] = { " + ", ".join(str(v) for v in anchor_h) + " };",
    ]

    grid_sizes = ((20, 20), (40, 40), (80, 80))
    for idx, (grid_h, grid_w) in enumerate(grid_sizes):
        aw, ah = format_scaled_anchors(anchor_w, anchor_h, grid_h, grid_w, ANCHORS_MASK[idx])
        lines.append(
            f"double anchor_w_{idx}[3] = {{ {', '.join(aw)} }};"
        )
        lines.append(
            f"double anchor_h_{idx}[3] = {{ {', '.join(ah)} }};"
        )

    return lines, head_names, nms_scale, nms_zero, anchor_w, anchor_h


def print_fpga_quant_params(out_dir, anchors_path, save_path=None):
    """打印 FPGA / NMS 常用的反量化参数（来自量化 pth 的 observer + anchors）。"""
    lines, head_names, nms_scale, nms_zero, anchor_w, anchor_h = build_fpga_param_lines(
        out_dir, anchors_path
    )
    head_labels = ("out1 (20x20)", "out2 (40x40)", "out3 (80x80)")

    print("\n========== FPGA 量化参数（写入 C/RTL）==========")
    for line in lines:
        print(line)
    print("\n对应 npy 文件:")
    print("  quant_scale  <- quant.scale.npy")
    print("  quant_zero   <- quant.zero_point.npy")
    for label, name, scale, zero in zip(head_labels, head_names, nms_scale, nms_zero):
        print(f"  nms [{name}] {label}: scale={scale:.17g}, zero={zero}")
    print(f"  anchor_w/h   <- {anchors_path}")
    print("================================================\n")

    if save_path:
        with open(save_path, "w", encoding="utf-8") as f:
            f.write("// Auto-generated by export_npy.py\n")
            f.write("\n".join(lines) + "\n")
        print(f"已保存到: {save_path}\n")


def main():
    parser = argparse.ArgumentParser(
        description="导出 FPGA 对齐验证所需的 npy（权重 + 中间层激活）"
    )
    parser.add_argument(
        "--model-path",
        default="model_data/ccpd_crpd_quant.pth",
        help="量化模型 pth 路径",
    )
    parser.add_argument(
        "--image",
        default="1.jpg",
        help="用于 dump 中间层激活的校准图片",
    )
    parser.add_argument(
        "--out-dir",
        default="./npy",
        help="npy 输出目录（须与 gen_weight_txt_rk3568.py 中 npy_path 一致）",
    )
    parser.add_argument(
        "--anchors-path",
        default=DEFAULT_ANCHORS_PATH,
        help="anchor 文件路径（写入 anchor_w/anchor_h）",
    )
    parser.add_argument(
        "--save-params",
        default="",
        help="将 C++ 参数保存到指定文件，默认保存到 <out-dir>/fpga_params.h",
    )
    args = parser.parse_args()

    model_path = os.path.join(ROOT, args.model_path)
    image_path = os.path.join(ROOT, args.image)
    out_dir = os.path.join(ROOT, args.out_dir)
    anchors_path = os.path.join(ROOT, args.anchors_path)
    save_params = args.save_params or os.path.join(out_dir, "fpga_params.h")

    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"找不到权重: {model_path}")
    if not os.path.isfile(image_path):
        raise FileNotFoundError(f"找不到图片: {image_path}")
    if not os.path.isfile(anchors_path):
        raise FileNotFoundError(f"找不到 anchor 文件: {anchors_path}")

    os.makedirs(out_dir, exist_ok=True)

    weight_count = to_npy(load_state_dict(model_path), out_dir)
    print(f"[1/2] 权重 npy: {weight_count} 个 -> {out_dir}")

    _, num_classes = get_classes(os.path.join(ROOT, "model_data/CCPD_CRPD_classes.txt"))
    model = load_quant_model(model_path, num_classes)
    export_activations(model, image_path)
    print(f"[2/2] 中间层激活 npy 已导出（图片: {args.image}）")

    missing = check_activations(out_dir)
    if missing:
        print(f"警告: 仍缺少 {len(missing)} 个激活文件:")
        for name in missing[:10]:
            print(f"  - {name}")
        if len(missing) > 10:
            print(f"  ... 共 {len(missing)} 个")
    else:
        print(f"全部 {len(ACTIVATION_FILES)} 个激活 npy 已就绪，可供 gen_weight_txt_rk3568.py 使用")

    print_fpga_quant_params(out_dir, anchors_path, save_path=save_params)


if __name__ == "__main__":
    main()
