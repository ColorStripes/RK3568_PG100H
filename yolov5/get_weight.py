import argparse
import os

import numpy as np
import torch


def is_quantized_weight(v):
    return isinstance(v, torch.Tensor) and v.is_quantized


def save_tensor(path, v):
    if isinstance(v, torch.Tensor):
        arr = v.detach().cpu().numpy()
    else:
        arr = np.asarray(v)
    np.save(path, arr)


def to_npy(state_dict, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    saved = 0

    for k, v in state_dict.items():
        if v is None:
            continue

        if is_quantized_weight(v):
            save_tensor(os.path.join(out_dir, k + ".scale"), v.q_scale())
            save_tensor(os.path.join(out_dir, k + ".zero_point"), v.q_zero_point())
            save_tensor(os.path.join(out_dir, k + ".int"), v.int_repr())
            save_tensor(os.path.join(out_dir, k), v.dequantize())
            saved += 4
            continue

        if isinstance(v, torch.Tensor):
            save_tensor(os.path.join(out_dir, k), v)
            saved += 1

    return saved


def load_state_dict(model_path):
    checkpoint = torch.load(model_path, map_location="cpu")
    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        return checkpoint["state_dict"]
    if isinstance(checkpoint, dict):
        return checkpoint
    raise TypeError(f"不支持的权重格式: {type(checkpoint)}")


def main():
    parser = argparse.ArgumentParser(description="将 YoloV5n 的 pth 权重导出为 npy")
    parser.add_argument(
        "--model-path",
        default="model_data/ccpd_crpd_quant.pth",
        help="输入 pth 路径（支持量化模型和 float 模型）",
    )
    parser.add_argument(
        "--out-dir",
        default="./npy",
        help="npy 输出目录",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.model_path):
        raise FileNotFoundError(f"找不到权重文件: {args.model_path}")

    state_dict = load_state_dict(args.model_path)
    count = to_npy(state_dict, args.out_dir)
    print(f"已从 {args.model_path} 导出 {count} 个 npy 文件到 {args.out_dir}")


if __name__ == "__main__":
    main()
