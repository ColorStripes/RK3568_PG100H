import os
import re
import numpy as np
import cv2 as cv
from gen_weight_util_rk3568 import focus_addr
from gen_weight_util_rk3568 import focus_param
from gen_weight_util_rk3568 import cat_add_addr
from gen_weight_util_rk3568 import weight33_to_txt
from gen_weight_util_rk3568 import weight11_to_txt
from gen_weight_util_rk3568 import weight11_to_txt_para
from gen_weight_util_rk3568 import bias33_to_txt
from gen_weight_util_rk3568 import bias11_to_txt
from gen_weight_util_rk3568 import scale_zero_to_txt
from gen_weight_util_rk3568 import quant_to_txt
from gen_weight_util_rk3568 import img_to_txt
from gen_weight_util_rk3568 import torch_to_txt
from gen_weight_util_rk3568 import conv_addr
from gen_weight_util_rk3568 import conv11_param
from gen_weight_util_rk3568 import conv11_param_para
from gen_weight_util_rk3568 import conv33_param
from gen_weight_util_rk3568 import add_param
from gen_weight_util_rk3568 import cat_param
from gen_weight_util_rk3568 import max_addr
from gen_weight_util_rk3568 import max_param
from gen_weight_util_rk3568 import up_addr
from gen_weight_util_rk3568 import up_param
from gen_weight_util_rk3568 import txt2bin

# === FPGA 输出路径配置 ===
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NPY_DIR = os.path.join(SCRIPT_DIR, "..", "npy")                # 量化 npy 输入文件
TXT_DIR = os.path.join(SCRIPT_DIR, "txt")                      # param txt 输出 (保持现状)
NPU_DIR = os.path.join(SCRIPT_DIR, "..", "..", "npu_data")     # npu_data 根目录
INSTRUCTION_DIR = os.path.join(NPU_DIR, "instruction")         # 指令文件
# 自动创建目录
os.makedirs(TXT_DIR, exist_ok=True)
os.makedirs(INSTRUCTION_DIR, exist_ok=True)


# ---------- _para 调度 ----------
# para_conv_set 在后文 para_index 定义后计算，此处先声明占位
para_conv_set = set()


def _weight11(n, path, weight):
    """根据 n 是否在 para_conv_set 中自动选择 _para 或无后缀版本"""
    if n in para_conv_set:
        weight11_to_txt_para(path, weight)
    else:
        weight11_to_txt(path, weight)


def _conv11_param(n, path, img, torch_result, weight, pad, stride):
    """根据 n 是否在 para_conv_set 中自动选择 _para 或无后缀版本"""
    if n in para_conv_set:
        conv11_param_para(path, img, torch_result, weight, pad, stride)
    else:
        conv11_param(path, img, torch_result, weight, pad, stride)


def focus(npy_path, path):
    # 结果
    torch_path = os.path.join(npy_path, "img.int.npy")
    torch_result = np.load(torch_path)
    torch_temp = np.full((1, 4, 320, 320), 0, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)
    torch_to_txt(os.path.join(path, "focus_torch.txt"), torch_result)

    # 初始图片处理
    img_path = os.path.join(npy_path, "quant.int.npy")
    img = np.load(img_path)
    img_temp = np.full((1, 1, 640, 640), 0, dtype=int)
    img = np.concatenate((img, img_temp), axis=1)
    quant_to_txt(os.path.join(path, "focus_in_data.txt"), img)  # 保存特征图
    torch_to_txt(os.path.join(path, "focus_in_data_lei.txt"), img)  # 竖向排列

    focus_addr(os.path.join(path, "focus_param.txt"), 0x0600_0000, 0x0980_0000)
    focus_param(os.path.join(path, "focus_param.txt"), img, torch_result)


def conv1(npy_path, path):
    # 未经过当前卷积层的原始特征图
    img_path = os.path.join(npy_path, "img.int.npy")
    # 图片的scale
    img_scale_path = os.path.join(npy_path, "quant.scale.npy")
    # 图片的zero
    img_zero_path = os.path.join(npy_path, "quant.zero_point.npy")

    # 经过当前卷积层的卷积后特征图
    torch_path = os.path.join(npy_path, "img_conv1.int.npy")

    # 权重
    weight_path = os.path.join(npy_path, "backbone.conv1.conv.weight.int.npy")
    # 权重的scale
    weight_scale_path = os.path.join(npy_path, "backbone.conv1.conv.weight.scale.npy")
    # 权重的zero
    weight_zero_path = os.path.join(npy_path, "backbone.conv1.conv.weight.zero_point.npy")

    # 偏置
    bias_path = os.path.join(npy_path, "backbone.conv1.conv.bias.npy")
    s3_path = os.path.join(npy_path, "backbone.conv1.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv1.conv.zero_point.npy")

    img = np.load(img_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)
    torch_result = np.load(torch_path)  # 经过当前卷积层的卷积后特征图

    img_temp = np.full((1, 4, 320, 320), 0, dtype=int)
    img = np.concatenate((img, img_temp), axis=1)

    weight_temp = np.full((16, 4, 3, 3), 0, dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=1)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv1_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv1_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv1_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv1_param.txt"), 0x0980_0000, 0x0200_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv1_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv1_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv1_torch.txt"), torch_result)


def conv2(npy_path, path):
    # 未经过当前卷积层的原始特征图
    img_path = os.path.join(npy_path, "img_conv1.int.npy")
    # 图片的scale
    img_scale_path = os.path.join(npy_path, "backbone.conv1.conv.scale.npy")
    # 图片的zero
    img_zero_path = os.path.join(npy_path, "backbone.conv1.conv.zero_point.npy")

    # 经过当前卷积层的卷积后特征图
    torch_path = os.path.join(npy_path, "img_conv2.int.npy")

    # 权重
    weight_path = os.path.join(npy_path, "backbone.conv2.conv.weight.int.npy")
    # 权重的scale
    weight_scale_path = os.path.join(npy_path, "backbone.conv2.conv.weight.scale.npy")
    # 权重的zero
    weight_zero_path = os.path.join(npy_path, "backbone.conv2.conv.weight.zero_point.npy")

    # 偏置
    bias_path = os.path.join(npy_path, "backbone.conv2.conv.bias.npy")
    s3_path = os.path.join(npy_path, "backbone.conv2.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv2.conv.zero_point.npy")

    img = np.load(img_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)
    torch_result = np.load(torch_path)  # 经过当前卷积层的卷积后特征图

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv2_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv2_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv2_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv2_param.txt"), 0x0A00_0000, 0x0210_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv2_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv2_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv2_torch.txt"), torch_result)


def conv3(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv2.int.npy")
    torch_path = os.path.join(npy_path, "img_conv3.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv3.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv2.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv3.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv2.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv3.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv3.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv3.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv3.conv.zero_point.npy")

    img = np.load(img_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)
    torch_result = np.load(torch_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv3_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv3_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(3, os.path.join(path, "conv3_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv3_param.txt"), 0x0980_0000, 0x0220_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv3_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(3, os.path.join(path, "conv3_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv3_torch.txt"), torch_result)


def conv4(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv2.int.npy")
    torch_path = os.path.join(npy_path, "img_conv4.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv4.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv2.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv4.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv2.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv4.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv4.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv4.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv4.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv4_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv4_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(4, os.path.join(path, "conv4_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv4_param.txt"), 0x0980_0000, 0x0230_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv4_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(4, os.path.join(path, "conv4_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv4_torch.txt"), torch_result)


def conv5(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv3.int.npy")
    torch_path = os.path.join(npy_path, "img_conv5.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv5.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv3.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv5.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv3.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv5.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv5.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv5.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv5.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv5_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv5_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(5, os.path.join(path, "conv5_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv5_param.txt"), 0x0A00_0000, 0x0240_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv5_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(5, os.path.join(path, "conv5_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv5_torch.txt"), torch_result)


def conv6(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv5.int.npy")
    torch_path = os.path.join(npy_path, "img_conv6.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv6.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv5.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv6.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv5.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv6.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv6.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv6.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv6.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv6_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv6_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv6_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv6_param.txt"), 0x0A80_0000, 0x0250_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv6_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv6_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv6_torch.txt"), torch_result)


def add0(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv6.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv3.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv6.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv6.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv3.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv3.conv.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add0.scale.npy")
    torch_path = os.path.join(npy_path, "add0.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add0_param.txt"), 0x0B00_0000, 0x0A00_0000, 0x0A80_0000)
    add_param(os.path.join(path, "add0_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add0_torch.txt"), torch_result)


def cat0(npy_path, path):
    img_path_1 = os.path.join(npy_path, "add0.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv4.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add0.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add0.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv4.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv4.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat0.scale.npy")
    torch_path = os.path.join(npy_path, "cat0.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat0_param.txt"), 0x0A80_0000, 0x0A80_0000, 0x0A00_0000)
    cat_param(os.path.join(path, "cat0_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat0_torch.txt"), torch_result)


def conv7(npy_path, path):
    img_path = os.path.join(npy_path, "cat0.int.npy")
    torch_path = os.path.join(npy_path, "img_conv7.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv7.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat0.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv7.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat0.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv7.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv7.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv7.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv7.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv7_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv7_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(7, os.path.join(path, "conv7_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv7_param.txt"), 0x0A00_0000, 0x0260_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv7_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(7, os.path.join(path, "conv7_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv7_torch.txt"), torch_result)


# F:\python\yolov5\npy
def conv8(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv7.int.npy")
    torch_path = os.path.join(npy_path, "img_conv8.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv8.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv7.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv8.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv7.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv8.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv8.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv8.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv8.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv8_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv8_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv8_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv8_param.txt"), 0x0980_0000, 0x0270_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv8_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv8_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv8_torch.txt"), torch_result)


def conv9(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv8.int.npy")
    torch_path = os.path.join(npy_path, "img_conv9.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv9.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv8.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv9.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv8.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv9.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv9.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv9.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv9.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv9_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv9_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(9, os.path.join(path, "conv9_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv9_param.txt"), 0x0A00_0000, 0x0280_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv9_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(9, os.path.join(path, "conv9_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv9_torch.txt"), torch_result)


def conv10(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv8.int.npy")
    torch_path = os.path.join(npy_path, "img_conv10.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv10.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv8.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv10.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv8.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv10.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv10.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv10.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv10.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv10_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv10_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(10, os.path.join(path, "conv10_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv10_param.txt"), 0x0A00_0000, 0x0290_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv10_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(10, os.path.join(path, "conv10_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv10_torch.txt"), torch_result)


def conv11(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv9.int.npy")
    torch_path = os.path.join(npy_path, "img_conv11.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv11.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv9.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv11.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv9.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv11.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv11.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv11.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv11.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv11_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv11_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(11, os.path.join(path, "conv11_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv11_param.txt"), 0x0980_0000, 0x02a0_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv11_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(11, os.path.join(path, "conv11_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv11_torch.txt"), torch_result)


def conv12(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv11.int.npy")
    torch_path = os.path.join(npy_path, "img_conv12.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv12.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv11.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv12.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv11.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv12.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv12.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv12.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv12.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv12_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv12_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv12_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv12_param.txt"), 0x0A00_0000, 0x02b0_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv12_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv12_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv12_torch.txt"), torch_result)


def add1(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv12.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv9.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv12.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv12.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv9.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv9.conv.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add1.scale.npy")
    torch_path = os.path.join(npy_path, "add1.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add1_param.txt"), 0x0B00_0000, 0x0980_0000, 0x0A80_0000)
    add_param(os.path.join(path, "add1_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add1_torch.txt"), torch_result)


def conv13(npy_path, path):
    img_path = os.path.join(npy_path, "add1.int.npy")
    torch_path = os.path.join(npy_path, "img_conv13.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv13.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_add1.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv13.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_add1.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv13.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv13.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv13.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv13.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv13_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv13_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(13, os.path.join(path, "conv13_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv13_param.txt"), 0x0A80_0000, 0x02c0_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv13_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(13, os.path.join(path, "conv13_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv13_torch.txt"), torch_result)


def conv14(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv13.int.npy")
    torch_path = os.path.join(npy_path, "img_conv14.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv14.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv13.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv14.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv13.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv14.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv14.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv14.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv14.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv14_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv14_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv14_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv14_param.txt"), 0x0980_0000, 0x02d0_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv14_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv14_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv14_torch.txt"), torch_result)


def add2(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv14.int.npy")
    img_path_1 = os.path.join(npy_path, "add1.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv14.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv14.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add1.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add1.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add2.scale.npy")
    torch_path = os.path.join(npy_path, "add2.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add2_param.txt"), 0x0B00_0000, 0x0A80_0000, 0x0980_0000)
    add_param(os.path.join(path, "add2_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add2_torch.txt"), torch_result)


def cat1(npy_path, path):
    img_path_1 = os.path.join(npy_path, "add2.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv10.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add2.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add2.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv10.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv10.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat1.scale.npy")
    torch_path = os.path.join(npy_path, "cat1.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat1_param.txt"),0x0A80_0000 , 0x0980_0000, 0x0A00_0000)
    cat_param(os.path.join(path, "cat1_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat1_torch.txt"), torch_result)


def conv15(npy_path, path):
    img_path = os.path.join(npy_path, "cat1.int.npy")
    torch_path = os.path.join(npy_path, "img_conv15.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv15.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat1.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv15.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat1.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv15.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv15.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv15.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv15.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv15_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv15_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(15, os.path.join(path, "conv15_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv15_param.txt"), 0x0A00_0000, 0x02e0_0000, 0x0680_0000)
    scale_zero_to_txt(os.path.join(path, "conv15_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(15, os.path.join(path, "conv15_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv15_torch.txt"), torch_result)


def conv16(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv15.int.npy")
    torch_path = os.path.join(npy_path, "img_conv16.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv16.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv15.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv16.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv15.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv16.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv16.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv16.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv16.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv16_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv16_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv16_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv16_param.txt"), 0x0680_0000, 0x02f0_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv16_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv16_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv16_torch.txt"), torch_result)


def conv17(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv16.int.npy")
    torch_path = os.path.join(npy_path, "img_conv17.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv17.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv16.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv17.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv16.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv17.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv17.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv17.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv17.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv17_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv17_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(17, os.path.join(path, "conv17_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv17_param.txt"), 0x0980_0000, 0x0300_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv17_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(17, os.path.join(path, "conv17_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv17_torch.txt"), torch_result)


def conv18(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv16.int.npy")
    torch_path = os.path.join(npy_path, "img_conv18.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv18.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv16.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv18.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv16.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv18.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv18.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv18.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv18.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv18_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv18_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(18, os.path.join(path, "conv18_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv18_param.txt"), 0x0980_0000, 0x0310_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv18_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(18, os.path.join(path, "conv18_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv18_torch.txt"), torch_result)


def conv19(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv17.int.npy")
    torch_path = os.path.join(npy_path, "img_conv19.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv19.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv17.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv19.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv17.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv19.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv19.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv19.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv19.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv19_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv19_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(19, os.path.join(path, "conv19_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv19_param.txt"), 0x0A00_0000, 0x0320_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv19_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(19, os.path.join(path, "conv19_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv19_torch.txt"), torch_result)


def conv20(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv19.int.npy")
    torch_path = os.path.join(npy_path, "img_conv20.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv20.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv19.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv20.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv19.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv20.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv20.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv20.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv20.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv20_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv20_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv20_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv20_param.txt"), 0x0980_0000, 0x0330_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv20_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv20_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv20_torch.txt"), torch_result)


def add3(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv20.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv17.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv20.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv20.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv17.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv17.conv.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add3.scale.npy")
    torch_path = os.path.join(npy_path, "add3.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add3_param.txt"), 0x0B00_0000, 0x0A00_0000, 0x0A80_0000)
    add_param(os.path.join(path, "add3_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add3_torch.txt"), torch_result)


def conv21(npy_path, path):
    img_path = os.path.join(npy_path, "add3.int.npy")
    torch_path = os.path.join(npy_path, "img_conv21.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv21.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_add3.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv21.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_add3.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv21.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv21.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv21.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv21.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv21_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv21_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(21, os.path.join(path, "conv21_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv21_param.txt"), 0x0A80_0000, 0x0340_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv21_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(21, os.path.join(path, "conv21_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv21_torch.txt"), torch_result)


def conv22(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv21.int.npy")
    torch_path = os.path.join(npy_path, "img_conv22.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv22.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv21.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv22.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv21.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv22.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv22.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv22.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv22.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv22_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv22_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv22_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv22_param.txt"), 0x0A00_0000, 0x0350_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv22_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv22_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv22_torch.txt"), torch_result)


def add4(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv22.int.npy")
    img_path_1 = os.path.join(npy_path, "add3.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv22.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv22.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add3.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add3.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add4.scale.npy")
    torch_path = os.path.join(npy_path, "add4.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add4_param.txt"), 0x0B00_0000, 0x0A80_0000, 0x0A00_0000)
    add_param(os.path.join(path, "add4_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add4_torch.txt"), torch_result)


def conv23(npy_path, path):
    img_path = os.path.join(npy_path, "add4.int.npy")
    torch_path = os.path.join(npy_path, "img_conv23.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv23.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_add4.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv23.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_add4.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv23.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv23.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv23.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv23.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv23_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv23_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(23, os.path.join(path, "conv23_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv23_param.txt"), 0x0A00_0000, 0x0360_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv23_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(23, os.path.join(path, "conv23_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv23_torch.txt"), torch_result)


def conv24(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv23.int.npy")
    torch_path = os.path.join(npy_path, "img_conv24.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv24.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv23.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv24.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv23.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv24.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv24.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv24.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv24.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv24_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv24_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv24_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv24_param.txt"), 0x0980_0000, 0x0370_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv24_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv24_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv24_torch.txt"), torch_result)


def add5(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv24.int.npy")
    img_path_1 = os.path.join(npy_path, "add4.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv24.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv24.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add4.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add4.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add5.scale.npy")
    torch_path = os.path.join(npy_path, "add5.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add5_param.txt"), 0x0B00_0000, 0x0A00_0000, 0x0A80_0000)
    add_param(os.path.join(path, "add5_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add5_torch.txt"), torch_result)


def cat2(npy_path, path):
    img_path_1 = os.path.join(npy_path, "add5.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv18.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add5.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add5.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv18.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv18.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat2.scale.npy")
    torch_path = os.path.join(npy_path, "cat2.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat2_param.txt"), 0x0A80_0000, 0x0A80_0000, 0x0A00_0000)
    cat_param(os.path.join(path, "cat2_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat2_torch.txt"), torch_result)


def conv25(npy_path, path):
    img_path = os.path.join(npy_path, "cat2.int.npy")
    torch_path = os.path.join(npy_path, "img_conv25.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv25.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat2.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv25.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat2.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv25.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv25.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv25.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv25.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv25_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv25_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(25, os.path.join(path, "conv25_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv25_param.txt"), 0x0A00_0000, 0x0380_0000, 0x0780_0000)
    scale_zero_to_txt(os.path.join(path, "conv25_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(25, os.path.join(path, "conv25_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv25_torch.txt"), torch_result)


def conv26(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv25.int.npy")
    torch_path = os.path.join(npy_path, "img_conv26.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv26.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv25.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv26.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv25.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv26.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv26.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv26.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv26.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv26_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv26_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv26_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv26_param.txt"), 0x0780_0000, 0x0390_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv26_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv26_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv26_torch.txt"), torch_result)


def conv27(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv26.int.npy")
    torch_path = os.path.join(npy_path, "img_conv27.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv27.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv26.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv27.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv26.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv27.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv27.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv27.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv27.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv27_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv27_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(27, os.path.join(path, "conv27_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv27_param.txt"), 0x0980_0000, 0x03a0_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv27_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(27, os.path.join(path, "conv27_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv27_torch.txt"), torch_result)


def conv28(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv26.int.npy")
    torch_path = os.path.join(npy_path, "img_conv28.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv28.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv26.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv28.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv26.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv28.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv28.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv28.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv28.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv28_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv28_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(28, os.path.join(path, "conv28_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv28_param.txt"), 0x0980_0000, 0x03b0_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv28_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(28, os.path.join(path, "conv28_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv28_torch.txt"), torch_result)


def conv29(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv27.int.npy")
    torch_path = os.path.join(npy_path, "img_conv29.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv29.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv27.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv29.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv27.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv29.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv29.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv29.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv29.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv29_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv29_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(29, os.path.join(path, "conv29_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv29_param.txt"), 0x0A00_0000, 0x03c0_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv29_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(29, os.path.join(path, "conv29_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv29_torch.txt"), torch_result)


def conv30(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv29.int.npy")
    torch_path = os.path.join(npy_path, "img_conv30.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv30.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv29.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv30.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv29.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv30.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv30.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv30.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv30.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv30_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv30_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv30_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv30_param.txt"), 0x0980_0000, 0x03d0_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv30_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv30_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv30_torch.txt"), torch_result)


def add6(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv30.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv27.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv30.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv30.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv27.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv27.conv.zero_point.npy")
    add_scale_path = os.path.join(npy_path, "backbone.float_fun_add6.scale.npy")
    torch_path = os.path.join(npy_path, "add6.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "add_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "add_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "add6_param.txt"), 0x0B00_0000, 0x0A00_0000, 0x0A80_0000)
    add_param(os.path.join(path, "add6_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "add6_torch.txt"), torch_result)


def cat3(npy_path, path):
    img_path_1 = os.path.join(npy_path, "add6.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv28.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.float_fun_add6.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.float_fun_add6.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv28.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv28.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat3.scale.npy")
    torch_path = os.path.join(npy_path, "cat3.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat3_param.txt"), 0x0A80_0000, 0x0A80_0000, 0x0A00_0000)
    cat_param(os.path.join(path, "cat3_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat3_torch.txt"), torch_result)


def conv31(npy_path, path):
    img_path = os.path.join(npy_path, "cat3.int.npy")
    torch_path = os.path.join(npy_path, "img_conv31.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv31.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat3.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv31.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat3.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv31.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv31.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv31.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv31.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv31_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv31_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(31, os.path.join(path, "conv31_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv31_param.txt"), 0x0A00_0000, 0x03e0_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv31_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(31, os.path.join(path, "conv31_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv31_torch.txt"), torch_result)


def conv32(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv31.int.npy")
    torch_path = os.path.join(npy_path, "img_conv32.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv32.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv31.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv32.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv31.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv32.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv32.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv32.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv32.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv32_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv32_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(32, os.path.join(path, "conv32_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv32_param.txt"), 0x0980_0000, 0x03f0_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv32_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(32, os.path.join(path, "conv32_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv32_torch.txt"), torch_result)


def max1(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv32.int.npy")
    torch_path = os.path.join(npy_path, "max1.int.npy")
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "max1_in_data.txt"), img)
    torch_to_txt(os.path.join(path, "max1_torch.txt"), torch_result)
    max_addr(os.path.join(path, "max1_param.txt"), 0x0A00_0000, 0x0A80_0000)
    max_param(os.path.join(path, "max1_param.txt"), img, torch_result)


def max2(npy_path, path):
    img_path = os.path.join(npy_path, "max1.int.npy")
    torch_path = os.path.join(npy_path, "max2.int.npy")
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "max2_in_data.txt"), img)
    torch_to_txt(os.path.join(path, "max2_torch.txt"), torch_result)
    max_addr(os.path.join(path, "max2_param.txt"), 0x0A80_0000, 0x0B00_0000)
    max_param(os.path.join(path, "max2_param.txt"), img, torch_result)


def max3(npy_path, path):
    img_path = os.path.join(npy_path, "max2.int.npy")
    torch_path = os.path.join(npy_path, "max3.int.npy")
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "max3_in_data.txt"), img)
    torch_to_txt(os.path.join(path, "max3_torch.txt"), torch_result)
    max_addr(os.path.join(path, "max3_param.txt"), 0x0B00_0000, 0x0B80_0000)
    max_param(os.path.join(path, "max3_param.txt"), img, torch_result)


def cat4_1(npy_path, path):
    img_path_0 = os.path.join(npy_path, "max1.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv32.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv32.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv32.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv32.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv32.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat4.scale.npy")
    torch_path = os.path.join(npy_path, "cat4.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    torch_result = torch_result[:, 256:, :, :]
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat4_1_param.txt"), 0x0A80_0000, 0x0A00_0000, 0x0980_0000)
    cat_param(os.path.join(path, "cat4_1_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat4_1_torch.txt"), torch_result)


def cat4_2(npy_path, path):
    img_path_0 = os.path.join(npy_path, "max3.int.npy")
    img_path_1 = os.path.join(npy_path, "max2.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv32.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv32.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv32.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv32.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat4.scale.npy")
    torch_path = os.path.join(npy_path, "cat4.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    torch_result = torch_result[:, :256, :, :]
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat4_2_param.txt"), 0x0B80_0000, 0x0B00_0000, 0x0A00_0000)
    cat_param(os.path.join(path, "cat4_2_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat4_2_torch.txt"), torch_result)


def cat4_3(npy_path, path):
    torch_path = os.path.join(npy_path, "cat4.int.npy")
    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), torch_result[:, :256, :, :])
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), torch_result[:, 256:, :, :])
    cat_add_addr(os.path.join(path, "cat4_3_param.txt"), 0x0A00_0000, 0x0980_0000, 0x0A80_0000)
    cat_param(os.path.join(path, "cat4_3_param.txt"), torch_result[:, 256:, :, :], torch_result, 1, 1, 1, 0, 0)
    torch_to_txt(os.path.join(path, "cat4_3_torch.txt"), torch_result)


def conv33(npy_path, path):
    img_path = os.path.join(npy_path, "cat4.int.npy")
    torch_path = os.path.join(npy_path, "img_conv33.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv33.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat4.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv33.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat4.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv33.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv33.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv33.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv33.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv33_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv33_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(33, os.path.join(path, "conv33_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv33_param.txt"), 0x0A80_0000, 0x0400_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv33_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(33, os.path.join(path, "conv33_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv33_torch.txt"), torch_result)


def conv34(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv33.int.npy")
    torch_path = os.path.join(npy_path, "img_conv34.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv34.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv33.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv34.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv33.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv34.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv34.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv34.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv34.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv34_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv34_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(34, os.path.join(path, "conv34_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv34_param.txt"), 0x0980_0000, 0x0410_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv34_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(34, os.path.join(path, "conv34_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv34_torch.txt"), torch_result)


def up0(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv34.int.npy")
    torch_path = os.path.join(npy_path, "upsample_0.int.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    img_to_txt(os.path.join(path, "up0_in_data.txt"), img)
    torch_to_txt(os.path.join(path, "up0_torch.txt"), torch_result)
    up_addr(os.path.join(path, "up0_param.txt"), 0x0A00_0000, 0x0A80_0000)
    up_param(os.path.join(path, "up0_param.txt"), img, torch_result)


def cat5(npy_path, path):
    img_path_0 = os.path.join(npy_path, "upsample_0.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv25.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv34.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv34.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv25.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv25.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat5.scale.npy")
    torch_path = os.path.join(npy_path, "cat5.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat5_param.txt"),0x0A80_0000, 0x0780_0000, 0x0980_0000)
    cat_param(os.path.join(path, "cat5_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat5_torch.txt"), torch_result)


def conv35(npy_path, path):
    img_path = os.path.join(npy_path, "cat5.int.npy")
    torch_path = os.path.join(npy_path, "img_conv35.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv35.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat5.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv35.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat5.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv35.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv35.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv35.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv35.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv35_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv35_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(35, os.path.join(path, "conv35_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv35_param.txt"), 0x0980_0000, 0x0420_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv35_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(35, os.path.join(path, "conv35_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv35_torch.txt"), torch_result)


def conv36(npy_path, path):
    img_path = os.path.join(npy_path, "cat5.int.npy")
    torch_path = os.path.join(npy_path, "img_conv36.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv36.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat5.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv36.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat5.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv36.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv36.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv36.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv36.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv36_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv36_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(36, os.path.join(path, "conv36_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv36_param.txt"), 0x0980_0000, 0x0430_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv36_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(36, os.path.join(path, "conv36_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv36_torch.txt"), torch_result)


def conv37(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv35.int.npy")
    torch_path = os.path.join(npy_path, "img_conv37.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv37.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv35.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv37.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv35.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv37.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv37.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv37.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv37.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv37_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv37_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(37, os.path.join(path, "conv37_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv37_param.txt"), 0x0A80_0000, 0x0440_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv37_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(37, os.path.join(path, "conv37_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv37_torch.txt"), torch_result)


def conv38(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv37.int.npy")
    torch_path = os.path.join(npy_path, "img_conv38.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv38.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv37.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv38.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv37.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv38.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv38.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv38.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv38.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv38_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv38_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv38_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv38_param.txt"), 0x0980_0000, 0x0450_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv38_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv38_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv38_torch.txt"), torch_result)


def cat6(npy_path, path):
    img_path_1 = os.path.join(npy_path, "img_conv38.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv36.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv38.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv38.conv.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv36.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv36.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat6.scale.npy")
    torch_path = os.path.join(npy_path, "cat6.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat6_param.txt"), 0x0B00_0000, 0x0A80_0000, 0x0980_0000)
    cat_param(os.path.join(path, "cat6_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat6_torch.txt"), torch_result)


def conv39(npy_path, path):
    img_path = os.path.join(npy_path, "cat6.int.npy")
    torch_path = os.path.join(npy_path, "img_conv39.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv39.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat6.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv39.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat6.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv39.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv39.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv39.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv39.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv39_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv39_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(39, os.path.join(path, "conv39_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv39_param.txt"), 0x0980_0000, 0x0460_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv39_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(39, os.path.join(path, "conv39_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv39_torch.txt"), torch_result)


def conv40(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv39.int.npy")
    torch_path = os.path.join(npy_path, "img_conv40.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv40.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv39.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv40.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv39.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv40.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv40.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv40.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv40.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv40_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv40_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(40, os.path.join(path, "conv40_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv40_param.txt"), 0x0A80_0000, 0x0470_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv40_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(40, os.path.join(path, "conv40_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv40_torch.txt"), torch_result)


def up1(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv40.int.npy")
    torch_path = os.path.join(npy_path, "upsample_1.int.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    img_to_txt(os.path.join(path, "up1_in_data.txt"), img)
    torch_to_txt(os.path.join(path, "up1_torch.txt"), torch_result)
    up_addr(os.path.join(path, "up1_param.txt"), 0x0980_0000, 0x0A80_0000)
    up_param(os.path.join(path, "up1_param.txt"), img, torch_result)


def cat7(npy_path, path):
    img_path_1 = os.path.join(npy_path, "upsample_1.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv15.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv40.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv40.conv.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv15.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv15.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat7.scale.npy")
    torch_path = os.path.join(npy_path, "cat7.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat7_param.txt"), 0x0680_0000, 0x0A80_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat7_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat7_torch.txt"), torch_result)


def conv41(npy_path, path):
    img_path = os.path.join(npy_path, "cat7.int.npy")
    torch_path = os.path.join(npy_path, "img_conv41.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv41.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat7.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv41.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat7.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv41.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv41.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv41.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv41.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv41_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv41_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(41, os.path.join(path, "conv41_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv41_param.txt"), 0x0B00_0000, 0x0480_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv41_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(41, os.path.join(path, "conv41_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv41_torch.txt"), torch_result)


def conv42(npy_path, path):
    img_path = os.path.join(npy_path, "cat7.int.npy")
    torch_path = os.path.join(npy_path, "img_conv42.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv42.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat7.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv42.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat7.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv42.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv42.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv42.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv42.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv42_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv42_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(42, os.path.join(path, "conv42_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv42_param.txt"), 0x0B00_0000, 0x0490_0000, 0x0B80_0000)
    scale_zero_to_txt(os.path.join(path, "conv42_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(42, os.path.join(path, "conv42_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv42_torch.txt"), torch_result)


def conv43(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv41.int.npy")
    torch_path = os.path.join(npy_path, "img_conv43.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv43.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv41.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv43.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv41.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv43.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv43.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv43.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv43.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv43_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv43_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(43, os.path.join(path, "conv43_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv43_param.txt"), 0x0A80_0000, 0x04a0_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv43_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(43, os.path.join(path, "conv43_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv43_torch.txt"), torch_result)


def conv44(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv43.int.npy")
    torch_path = os.path.join(npy_path, "img_conv44.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv44.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv43.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv44.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv43.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv44.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv44.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv44.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv44.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv44_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv44_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv44_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv44_param.txt"), 0x0B00_0000, 0x04b0_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv44_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv44_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv44_torch.txt"), torch_result)


def cat8(npy_path, path):
    img_path_1 = os.path.join(npy_path, "img_conv44.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv42.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv44.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv44.conv.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv42.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv42.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat8.scale.npy")
    torch_path = os.path.join(npy_path, "cat8.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat8_param.txt"), 0x0B80_0000, 0x0A80_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat8_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat8_torch.txt"), torch_result)


def conv45(npy_path, path):
    img_path = os.path.join(npy_path, "cat8.int.npy")
    torch_path = os.path.join(npy_path, "img_conv45.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv45.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat8.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv45.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat8.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv45.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv45.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv45.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv45.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv45_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv45_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(45, os.path.join(path, "conv45_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv45_param.txt"), 0x0B00_0000, 0x04c0_0000, 0x0880_0000)
    scale_zero_to_txt(os.path.join(path, "conv45_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(45, os.path.join(path, "conv45_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv45_torch.txt"), torch_result)


def conv46(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv45.int.npy")
    torch_path = os.path.join(npy_path, "img_conv46.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv46.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv45.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv46.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv45.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv46.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv46.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv46.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv46.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv46_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv46_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv46_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv46_param.txt"), 0x0880_0000, 0x04d0_0000, 0x0B80_0000)
    scale_zero_to_txt(os.path.join(path, "conv46_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv46_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv46_torch.txt"), torch_result)


def cat9(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv46.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv40.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv46.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv46.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv40.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv40.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat9.scale.npy")
    torch_path = os.path.join(npy_path, "cat9.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat9_param.txt"), 0x0B80_0000, 0x0980_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat9_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat9_torch.txt"), torch_result)


def conv47(npy_path, path):
    img_path = os.path.join(npy_path, "cat9.int.npy")
    torch_path = os.path.join(npy_path, "img_conv47.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv47.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat9.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv47.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat9.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv47.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv47.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv47.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv47.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv47_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv47_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(47, os.path.join(path, "conv47_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv47_param.txt"), 0x0B00_0000, 0x04e0_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv47_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(47, os.path.join(path, "conv47_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv47_torch.txt"), torch_result)


def conv48(npy_path, path):
    img_path = os.path.join(npy_path, "cat9.int.npy")
    torch_path = os.path.join(npy_path, "img_conv48.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv48.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat9.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv48.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat9.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv48.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv48.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv48.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv48.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv48_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv48_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(48, os.path.join(path, "conv48_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv48_param.txt"), 0x0B00_0000, 0x04f0_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv48_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(48, os.path.join(path, "conv48_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv48_torch.txt"), torch_result)


def conv49(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv47.int.npy")
    torch_path = os.path.join(npy_path, "img_conv49.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv49.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv47.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv49.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv47.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv49.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv49.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv49.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv49.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv49_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv49_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(49, os.path.join(path, "conv49_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv49_param.txt"), 0x0A80_0000, 0x0500_0000, 0x0B00_0000)
    scale_zero_to_txt(os.path.join(path, "conv49_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(49, os.path.join(path, "conv49_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv49_torch.txt"), torch_result)


def conv50(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv49.int.npy")
    torch_path = os.path.join(npy_path, "img_conv50.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv50.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv49.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv50.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv49.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv50.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv50.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv50.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv50.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv50_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv50_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv50_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv50_param.txt"), 0x0B00_0000, 0x0510_0000, 0x0B80_0000)
    scale_zero_to_txt(os.path.join(path, "conv50_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv50_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv50_torch.txt"), torch_result)


def cat10(npy_path, path):
    img_path_1 = os.path.join(npy_path, "img_conv50.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv48.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv50.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv50.conv.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv48.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv48.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat10.scale.npy")
    torch_path = os.path.join(npy_path, "cat10.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat10_param.txt"), 0x0980_0000, 0x0B80_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat10_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat10_torch.txt"), torch_result)


def conv51(npy_path, path):
    img_path = os.path.join(npy_path, "cat10.int.npy")
    torch_path = os.path.join(npy_path, "img_conv51.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv51.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat10.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv51.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat10.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv51.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv51.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv51.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv51.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv51_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv51_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(51, os.path.join(path, "conv51_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv51_param.txt"), 0x0B00_0000, 0x0520_0000, 0x0780_0000)
    scale_zero_to_txt(os.path.join(path, "conv51_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(51, os.path.join(path, "conv51_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv51_torch.txt"), torch_result)


def conv52(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv51.int.npy")
    torch_path = os.path.join(npy_path, "img_conv52.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv52.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv51.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv52.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv51.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv52.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv52.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv52.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv52.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv52_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv52_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv52_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv52_param.txt"), 0x0780_0000, 0x0530_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv52_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv52_param.txt"), img, torch_result, weight, 1, 1)

    torch_to_txt(os.path.join(path, "conv52_torch.txt"), torch_result)


def cat11(npy_path, path):
    img_path_0 = os.path.join(npy_path, "img_conv52.int.npy")
    img_path_1 = os.path.join(npy_path, "img_conv34.int.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv52.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv52.conv.zero_point.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv34.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv34.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat11.scale.npy")
    torch_path = os.path.join(npy_path, "cat11.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat11_param.txt"), 0x0980_0000, 0x0A00_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat11_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat11_torch.txt"), torch_result)


def conv53(npy_path, path):
    img_path = os.path.join(npy_path, "cat11.int.npy")
    torch_path = os.path.join(npy_path, "img_conv53.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv53.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat11.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv53.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat11.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv53.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv53.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv53.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv53.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv53_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv53_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(53, os.path.join(path, "conv53_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv53_param.txt"), 0x0B00_0000, 0x0540_0000, 0x0980_0000)
    scale_zero_to_txt(os.path.join(path, "conv53_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(53, os.path.join(path, "conv53_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv53_torch.txt"), torch_result)


def conv54(npy_path, path):
    img_path = os.path.join(npy_path, "cat11.int.npy")
    torch_path = os.path.join(npy_path, "img_conv54.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv54.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat11.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv54.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat11.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv54.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv54.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv54.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv54.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv54_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv54_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(54, os.path.join(path, "conv54_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv54_param.txt"), 0x0B00_0000, 0x0550_0000, 0x0A00_0000)
    scale_zero_to_txt(os.path.join(path, "conv54_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(54, os.path.join(path, "conv54_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv54_torch.txt"), torch_result)


def conv55(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv53.int.npy")
    torch_path = os.path.join(npy_path, "img_conv55.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv55.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv53.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv55.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv53.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv55.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv55.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv55.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv55.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv55_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv55_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(55, os.path.join(path, "conv55_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv55_param.txt"), 0x0980_0000, 0x0560_0000, 0x0A80_0000)
    scale_zero_to_txt(os.path.join(path, "conv55_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(55, os.path.join(path, "conv55_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv55_torch.txt"), torch_result)


def conv56(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv55.int.npy")
    torch_path = os.path.join(npy_path, "img_conv56.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv56.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv55.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv56.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv55.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv56.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv56.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv56.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv56.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv56_in_data.txt"), img)
    bias33_to_txt(os.path.join(path, "conv56_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(os.path.join(path, "conv56_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv56_param.txt"), 0x0A80_0000, 0x0570_0000, 0x0B80_0000)
    scale_zero_to_txt(os.path.join(path, "conv56_param.txt"), s1, s2, s3, z1, z3)
    conv33_param(os.path.join(path, "conv56_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv56_torch.txt"), torch_result)


def cat12(npy_path, path):
    img_path_1 = os.path.join(npy_path, "img_conv56.int.npy")
    img_path_0 = os.path.join(npy_path, "img_conv54.int.npy")
    img_scale_path_1 = os.path.join(npy_path, "backbone.conv56.conv.scale.npy")
    img_zero_path_1 = os.path.join(npy_path, "backbone.conv56.conv.zero_point.npy")
    img_scale_path_0 = os.path.join(npy_path, "backbone.conv54.conv.scale.npy")
    img_zero_path_0 = os.path.join(npy_path, "backbone.conv54.conv.zero_point.npy")
    cat_scale_path = os.path.join(npy_path, "backbone.float_fun_cat12.scale.npy")
    torch_path = os.path.join(npy_path, "cat12.int.npy")
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(os.path.join(path, "cat_in_data_0.txt"), img_0)
    img_to_txt(os.path.join(path, "cat_in_data_1.txt"), img_1)
    cat_add_addr(os.path.join(path, "cat12_param.txt"), 0x0A00_0000, 0x0B80_0000, 0x0B00_0000)
    cat_param(os.path.join(path, "cat12_param.txt"), img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(os.path.join(path, "cat12_torch.txt"), torch_result)


def conv57(npy_path, path):
    img_path = os.path.join(npy_path, "cat12.int.npy")
    torch_path = os.path.join(npy_path, "img_conv57.int.npy")
    weight_path = os.path.join(npy_path, "backbone.conv57.conv.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.float_fun_cat12.scale.npy")
    weight_scale_path = os.path.join(npy_path, "backbone.conv57.conv.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.float_fun_cat12.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "backbone.conv57.conv.weight.zero_point.npy")
    bias_path = os.path.join(npy_path, "backbone.conv57.conv.bias.npy")

    s3_path = os.path.join(npy_path, "backbone.conv57.conv.scale.npy")
    z3_path = os.path.join(npy_path, "backbone.conv57.conv.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)
    weight = np.load(weight_path)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.load(bias_path)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)

    img_to_txt(os.path.join(path, "conv57_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "conv57_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(57, os.path.join(path, "conv57_weight.txt"), weight)

    conv_addr(os.path.join(path, "conv57_param.txt"), 0x0B00_0000, 0x0580_0000, 0x0680_0000)
    scale_zero_to_txt(os.path.join(path, "conv57_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(57, os.path.join(path, "conv57_param.txt"), img, torch_result, weight, 0, 1)

    torch_to_txt(os.path.join(path, "conv57_torch.txt"), torch_result)


def out1(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv57.int.npy")
    torch_path = os.path.join(npy_path, "out1.int.npy")
    weight_path = os.path.join(npy_path, "conv1.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv57.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "conv1.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv57.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "conv1.weight.zero_point.npy")
    # bias_path = r"\conv1.bias.npy"

    s3_path = os.path.join(npy_path, "conv1.scale.npy")
    z3_path = os.path.join(npy_path, "conv1.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 256, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(weight.shape[0], dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 20, 20), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(os.path.join(path, "out1_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "out1_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(58, os.path.join(path, "out1_weight.txt"), weight)

    conv_addr(os.path.join(path, "out1_param.txt"), 0x0680_0000, 0x0590_0000, 0x0700_0000)
    scale_zero_to_txt(os.path.join(path, "out1_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(58, os.path.join(path, "out1_param.txt"), img, torch_result, weight, 0, 0)

    torch_to_txt(os.path.join(path, "out1_torch.txt"), torch_result)
    img_to_txt(os.path.join(path, "out1_torch_16.txt"), torch_result)


def out2(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv51.int.npy")
    torch_path = os.path.join(npy_path, "out2.int.npy")
    weight_path = os.path.join(npy_path, "conv2.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv51.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "conv2.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv51.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "conv2.weight.zero_point.npy")
    # bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\conv1.bias.npy"

    s3_path = os.path.join(npy_path, "conv2.scale.npy")
    z3_path = os.path.join(npy_path, "conv2.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 128, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(weight.shape[0], dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 40, 40), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(os.path.join(path, "out2_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "out2_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(59, os.path.join(path, "out2_weight.txt"), weight)

    conv_addr(os.path.join(path, "out2_param.txt"), 0x0780_0000, 0x05a0_0000, 0x0700_3200)  # = 0x07000000 + 20×20×32
    scale_zero_to_txt(os.path.join(path, "out2_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(59, os.path.join(path, "out2_param.txt"), img, torch_result, weight, 0, 0)

    torch_to_txt(os.path.join(path, "out2_torch.txt"), torch_result)
    img_to_txt(os.path.join(path, "out2_torch_16.txt"), torch_result)


def out3(npy_path, path):
    img_path = os.path.join(npy_path, "img_conv45.int.npy")
    torch_path = os.path.join(npy_path, "out3.int.npy")
    weight_path = os.path.join(npy_path, "conv3.weight.int.npy")
    img_scale_path = os.path.join(npy_path, "backbone.conv45.conv.scale.npy")
    weight_scale_path = os.path.join(npy_path, "conv3.weight.scale.npy")
    img_zero_path = os.path.join(npy_path, "backbone.conv45.conv.zero_point.npy")
    weight_zero_path = os.path.join(npy_path, "conv3.weight.zero_point.npy")
    # bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\conv1.bias.npy"

    s3_path = os.path.join(npy_path, "conv3.scale.npy")
    z3_path = os.path.join(npy_path, "conv3.zero_point.npy")

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 64, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(weight.shape[0], dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 80, 80), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(os.path.join(path, "out3_in_data.txt"), img)
    bias11_to_txt(os.path.join(path, "out3_weight.txt"), weight, s1, s2, s3, z1, z2, z3, bias)
    _weight11(60, os.path.join(path, "out3_weight.txt"), weight)

    conv_addr(os.path.join(path, "out3_param.txt"), 0x0880_0000, 0x05b0_0000, 0x0700_FA00)  # = 0x07003200 + 40×40×32
    scale_zero_to_txt(os.path.join(path, "out3_param.txt"), s1, s2, s3, z1, z3)
    _conv11_param(60, os.path.join(path, "out3_param.txt"), img, torch_result, weight, 0, 0)

    torch_to_txt(os.path.join(path, "out3_torch.txt"), torch_result)
    img_to_txt(os.path.join(path, "out3_torch_16.txt"), torch_result)


# E:\yolov5-v6.1-pytorch-master\ref\txt
def gen_fpga_weight(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)
    for i in range(1, 58):
        txt2bin(os.path.join(txt_path, "conv" + str(i), "conv" + str(i) + "_weight.txt"),
                os.path.join(bin_path, "conv" + str(i) + "_weight.bin"))
    txt2bin(os.path.join(txt_path, "out1", "out1_weight.txt"), os.path.join(bin_path, "out1_weight.bin"))
    txt2bin(os.path.join(txt_path, "out2", "out2_weight.txt"), os.path.join(bin_path, "out2_weight.bin"))
    txt2bin(os.path.join(txt_path, "out3", "out3_weight.txt"), os.path.join(bin_path, "out3_weight.bin"))


# 单步调试输入数据
def gen_fpga_in_data(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)

    # focus
    txt2bin(os.path.join(txt_path, "focus", "focus_in_data.txt"),
            os.path.join(bin_path, "focus_data.bin"))
    # conv
    for i in range(1, 58):
        txt2bin(os.path.join(txt_path, "conv" + str(i), "conv" + str(i) + "_in_data.txt"),
                os.path.join(bin_path, "conv" + str(i) + "_data.bin"))
    # out
    for i in range(1, 4):
        txt2bin(os.path.join(txt_path, "out" + str(i), "out" + str(i) + "_in_data.txt"),
                os.path.join(bin_path, "out" + str(i) + "_data.bin"))
    # add
    for i in range(0, 7):
        txt2bin(os.path.join(txt_path, "add" + str(i), "add_in_data_0.txt"),
                os.path.join(bin_path, "add" + str(i) + "_data_0.bin"))
        txt2bin(os.path.join(txt_path, "add" + str(i), "add_in_data_1.txt"),
                os.path.join(bin_path, "add" + str(i) + "_data_1.bin"))
    # cat
    for i in range(0, 4):
        txt2bin(os.path.join(txt_path, "cat" + str(i), "cat_in_data_0.txt"),
                os.path.join(bin_path, "cat" + str(i) + "_data_0.bin"))
        txt2bin(os.path.join(txt_path, "cat" + str(i), "cat_in_data_1.txt"),
                os.path.join(bin_path, "cat" + str(i) + "_data_1.bin"))
    for i in range(1, 4):
        txt2bin(os.path.join(txt_path, "cat4_" + str(i), "cat_in_data_0.txt"),
                os.path.join(bin_path, "cat4_" + str(i) + "_data_0.bin"))
        txt2bin(os.path.join(txt_path, "cat4_" + str(i), "cat_in_data_1.txt"),
                os.path.join(bin_path, "cat4_" + str(i) + "_data_1.bin"))
    for i in range(5, 13):
        txt2bin(os.path.join(txt_path, "cat" + str(i), "cat_in_data_0.txt"),
                os.path.join(bin_path, "cat" + str(i) + "_data_0.bin"))
        txt2bin(os.path.join(txt_path, "cat" + str(i), "cat_in_data_1.txt"),
                os.path.join(bin_path, "cat" + str(i) + "_data_1.bin"))
    # up
    for i in range(0, 2):
        txt2bin(os.path.join(txt_path, "up" + str(i), "up" + str(i) + "_in_data.txt"),
                os.path.join(bin_path, "up" + str(i) + "_data.bin"))
    # max
    for i in range(1, 4):
        txt2bin(os.path.join(txt_path, "max" + str(i), "max" + str(i) + "_in_data.txt"),
                os.path.join(bin_path, "max" + str(i) + "_data.bin"))


# 三个head结果
def gen_fpga_torch_data(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)
    # out的结果
    for i in range(1, 4):
        txt2bin(os.path.join(txt_path, "out" + str(i), "out" + str(i) + "_torch_16.txt"),
                os.path.join(bin_path, "out" + str(i) + "_torch_data.bin"))


# NPY_DIR: ../npy
def gen_fpga_img(npy_path, img_path):
    quant_scale_path = os.path.join(npy_path, "quant.scale.npy")
    quant_zero_path = os.path.join(npy_path, "quant.zero_point.npy")

    img = cv.imread(img_path)
    img = cv.resize(img, (640, 640), cv.INTER_CUBIC)
    img = cv.cvtColor(img, cv.COLOR_BGR2RGB)

    img = img / 255

    quant_scale = np.load(quant_scale_path)
    quant_zero = np.load(quant_zero_path)

    img = (img - quant_zero) / quant_scale

    img = np.round(img)
    img = img.astype(np.uint8)
    torch_result = np.transpose(img, (2, 0, 1))
    # torch_temp = np.full((13, 640, 640), 0, dtype=int)
    # torch_result = np.concatenate((img, torch_temp), axis=0)
    torch_result = np.expand_dims(torch_result, 0)
    torch_to_txt(os.path.join(TXT_DIR, "focus", "focus_torch_img.txt"), torch_result)
    print("xxx")


def gen_fpga_instruction(param_path, instructinon_path):
    config = {}
    with open(param_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or "=" not in line:
                continue
            key, value = line.split("=")
            key = key.strip()
            value = value.strip()
            # 尝试转成整数
            if value.isdigit():
                value = int(value)
            else:
                try:
                    value = float(value)
                except ValueError:
                    pass
            config[key] = value
    with open(instructinon_path, "w") as f:
        # f.write("01" + "\n")  //C++控制
        for key, value in config.items():
            # print(key, value)  # 打印
            if key == "s_addr_0":
                f.write("00000001" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "s_addr_1":
                f.write("00000002" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "m_addr":
                f.write("00000003" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "weight_addr":
                f.write("00000004" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "start":
                f.write("00000005" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "type":
                f.write("00000006" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "stride":
                f.write("00000007" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "relu":
                f.write("00000008" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "col_num":
                f.write("00000009" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "row_num":
                f.write("0000000a" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "calculate_num":
                f.write("0000000b" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "calculate_cin_num":
                f.write("0000000c" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "calculate_cout_num":
                f.write("0000000d" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "calculate_end":
                f.write("0000000e" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "in_col_channel_num":
                f.write("0000000f" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "out_col_channel_num":
                f.write("00000010" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "scale_1":
                f.write("00000011" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "scale_2":
                f.write("00000012" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "scale_3":
                f.write("00000013" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "zero_1":
                f.write("00000014" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "zero_2":
                f.write("00000015" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "zero_3":
                f.write("00000016" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            elif key == "weight_sum":
                f.write("00000017" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")
            # elif key == "bias_len":
            elif key == "weight_len":
                f.write("00000018" + "\n" + f"{format(value & 0xFFFFFFFF, '08X')}" + "\n")




def instruction_all(instruction_file, out_path):
    """把单个指令文件内容追加到总输出文件"""
    if not os.path.exists(instruction_file):
        print(f"❌ 未找到文件: {instruction_file}")
        return

    with open(instruction_file, 'r') as infile, open(out_path, 'a') as outfile:
        for line in infile:
            line = line.strip()
            if line:
                outfile.write(line + "\n")

    print(f"✅ 合并: {instruction_file}")


def convert_txt_to_hex(input_file, output_file):
    hex_list = []
    with open(input_file, "r") as f:
        for line in f:
            num = int(line.strip())
            hex_list.append(f"{num:02x}")

    lines = []
    for i in range(0, len(hex_list), 16):
        group = hex_list[i:i + 16]
        # 反转顺序
        group.reverse()
        hex_str = "".join(group)
        lines.append(hex_str)

    with open(output_file, "w") as f:
        for line in lines:
            f.write(line + "\n")

    print("转化完成")


# i = 3
# convert_txt_to_hex(r"F:\python\yolov5\ref\txt\out" + str(i) + r"\head" + str(i) + r".txt",
#                 r"F:\python\yolov5\ref\txt\out" + str(i) + r"\head" + str(i) + r"_16.txt")
# convert_txt_to_hex(r"F:\VSstudio\Yolov5\Yolov5\outdata1\add0_result.txt",
#                     r"F:\VSstudio\Yolov5\Yolov5\outdata_hex\add0_result.txt")

focus(NPY_DIR, os.path.join(TXT_DIR, "focus"))

add0(NPY_DIR, os.path.join(TXT_DIR, "add0"))
add1(NPY_DIR, os.path.join(TXT_DIR, "add1"))
add2(NPY_DIR, os.path.join(TXT_DIR, "add2"))
add3(NPY_DIR, os.path.join(TXT_DIR, "add3"))
add4(NPY_DIR, os.path.join(TXT_DIR, "add4"))
add5(NPY_DIR, os.path.join(TXT_DIR, "add5"))
add6(NPY_DIR, os.path.join(TXT_DIR, "add6"))

cat0(NPY_DIR, os.path.join(TXT_DIR, "cat0"))
cat1(NPY_DIR, os.path.join(TXT_DIR, "cat1"))
cat2(NPY_DIR, os.path.join(TXT_DIR, "cat2"))
cat3(NPY_DIR, os.path.join(TXT_DIR, "cat3"))
cat4_1(NPY_DIR, os.path.join(TXT_DIR, "cat4_1"))
cat4_2(NPY_DIR, os.path.join(TXT_DIR, "cat4_2"))
cat4_3(NPY_DIR, os.path.join(TXT_DIR, "cat4_3"))
cat5(NPY_DIR, os.path.join(TXT_DIR, "cat5"))
cat6(NPY_DIR, os.path.join(TXT_DIR, "cat6"))
cat7(NPY_DIR, os.path.join(TXT_DIR, "cat7"))
cat8(NPY_DIR, os.path.join(TXT_DIR, "cat8"))
cat9(NPY_DIR, os.path.join(TXT_DIR, "cat9"))
cat10(NPY_DIR, os.path.join(TXT_DIR, "cat10"))
cat11(NPY_DIR, os.path.join(TXT_DIR, "cat11"))
cat12(NPY_DIR, os.path.join(TXT_DIR, "cat12"))

up0(NPY_DIR, os.path.join(TXT_DIR, "up0"))
up1(NPY_DIR, os.path.join(TXT_DIR, "up1"))

max1(NPY_DIR, os.path.join(TXT_DIR, "max1"))
max2(NPY_DIR, os.path.join(TXT_DIR, "max2"))
max3(NPY_DIR, os.path.join(TXT_DIR, "max3"))

conv1(NPY_DIR, os.path.join(TXT_DIR, "conv1"))
conv2(NPY_DIR, os.path.join(TXT_DIR, "conv2"))
conv3(NPY_DIR, os.path.join(TXT_DIR, "conv3"))
conv4(NPY_DIR, os.path.join(TXT_DIR, "conv4"))
conv5(NPY_DIR, os.path.join(TXT_DIR, "conv5"))
conv6(NPY_DIR, os.path.join(TXT_DIR, "conv6"))
conv7(NPY_DIR, os.path.join(TXT_DIR, "conv7"))
conv8(NPY_DIR, os.path.join(TXT_DIR, "conv8"))
conv9(NPY_DIR, os.path.join(TXT_DIR, "conv9"))
conv10(NPY_DIR, os.path.join(TXT_DIR, "conv10"))
conv11(NPY_DIR, os.path.join(TXT_DIR, "conv11"))
conv12(NPY_DIR, os.path.join(TXT_DIR, "conv12"))
conv13(NPY_DIR, os.path.join(TXT_DIR, "conv13"))
conv14(NPY_DIR, os.path.join(TXT_DIR, "conv14"))
conv15(NPY_DIR, os.path.join(TXT_DIR, "conv15"))
conv16(NPY_DIR, os.path.join(TXT_DIR, "conv16"))
conv17(NPY_DIR, os.path.join(TXT_DIR, "conv17"))
conv18(NPY_DIR, os.path.join(TXT_DIR, "conv18"))
conv19(NPY_DIR, os.path.join(TXT_DIR, "conv19"))
conv20(NPY_DIR, os.path.join(TXT_DIR, "conv20"))
conv21(NPY_DIR, os.path.join(TXT_DIR, "conv21"))
conv22(NPY_DIR, os.path.join(TXT_DIR, "conv22"))
conv23(NPY_DIR, os.path.join(TXT_DIR, "conv23"))
conv24(NPY_DIR, os.path.join(TXT_DIR, "conv24"))
conv25(NPY_DIR, os.path.join(TXT_DIR, "conv25"))
conv26(NPY_DIR, os.path.join(TXT_DIR, "conv26"))
conv27(NPY_DIR, os.path.join(TXT_DIR, "conv27"))
conv28(NPY_DIR, os.path.join(TXT_DIR, "conv28"))
conv29(NPY_DIR, os.path.join(TXT_DIR, "conv29"))
conv30(NPY_DIR, os.path.join(TXT_DIR, "conv30"))
conv31(NPY_DIR, os.path.join(TXT_DIR, "conv31"))
conv32(NPY_DIR, os.path.join(TXT_DIR, "conv32"))
conv33(NPY_DIR, os.path.join(TXT_DIR, "conv33"))
conv34(NPY_DIR, os.path.join(TXT_DIR, "conv34"))
conv35(NPY_DIR, os.path.join(TXT_DIR, "conv35"))
conv36(NPY_DIR, os.path.join(TXT_DIR, "conv36"))
conv37(NPY_DIR, os.path.join(TXT_DIR, "conv37"))
conv38(NPY_DIR, os.path.join(TXT_DIR, "conv38"))
conv39(NPY_DIR, os.path.join(TXT_DIR, "conv39"))
conv40(NPY_DIR, os.path.join(TXT_DIR, "conv40"))
conv41(NPY_DIR, os.path.join(TXT_DIR, "conv41"))
conv42(NPY_DIR, os.path.join(TXT_DIR, "conv42"))
conv43(NPY_DIR, os.path.join(TXT_DIR, "conv43"))
conv44(NPY_DIR, os.path.join(TXT_DIR, "conv44"))
conv45(NPY_DIR, os.path.join(TXT_DIR, "conv45"))
conv46(NPY_DIR, os.path.join(TXT_DIR, "conv46"))
conv47(NPY_DIR, os.path.join(TXT_DIR, "conv47"))
conv48(NPY_DIR, os.path.join(TXT_DIR, "conv48"))
conv49(NPY_DIR, os.path.join(TXT_DIR, "conv49"))
conv50(NPY_DIR, os.path.join(TXT_DIR, "conv50"))
conv51(NPY_DIR, os.path.join(TXT_DIR, "conv51"))
conv52(NPY_DIR, os.path.join(TXT_DIR, "conv52"))
conv53(NPY_DIR, os.path.join(TXT_DIR, "conv53"))
conv54(NPY_DIR, os.path.join(TXT_DIR, "conv54"))
conv55(NPY_DIR, os.path.join(TXT_DIR, "conv55"))
conv56(NPY_DIR, os.path.join(TXT_DIR, "conv56"))
conv57(NPY_DIR, os.path.join(TXT_DIR, "conv57"))
out1(NPY_DIR, os.path.join(TXT_DIR, "out1"))
out2(NPY_DIR, os.path.join(TXT_DIR, "out2"))
out3(NPY_DIR, os.path.join(TXT_DIR, "out3"))

gen_fpga_in_data(TXT_DIR, os.path.join(NPU_DIR, "indata_bin"))
gen_fpga_torch_data(TXT_DIR, os.path.join(NPU_DIR, "torch_bin"))
gen_fpga_weight(TXT_DIR, os.path.join(NPU_DIR, "weight_bin"))

index = [
    0, 1, 2, 3, 5, 6, 61, 4, 68, 7, 8, 9, 11, 12, 62, 13, 14, 63, 10, 69, 15, 16, 17, 19,
    20, 64, 21, 22, 65, 23, 24, 66, 18, 70, 25, 26, 27, 29, 30, 67, 28, 71, 31, 32, 85, 72, 86, 87,
    73, 74, 33, 34, 83, 75, 35, 37, 38, 36, 76, 39, 40, 84, 77, 41, 43, 44, 42, 78, 45, 60, 46, 79,
    47, 49, 50, 48, 80, 51, 59, 52, 81, 53, 55, 56, 54, 82, 57, 58
]

# 单独的conv1*1算子用para算子加
conv_para_index = [
    3, 9, 15, 17, 25, 27, 35, 41, 45, 47, 51, 53, 59, 60
]

#每拆开一组双算子 VS层数+1
para_index = [
    5, 6,     7, 8,     11, 12,   13, 14,
    19, 20,   21, 22,   23, 24,   29, 30,   31, 32,
    33, 34,   37, 38,   39, 40,   43, 44,
    49, 50,   55, 56,   57, 58
]

# conv_para_index ∪ para_index 中奇数位(第1,3,5...个) → 统一使用 _para 后缀
para_conv_set = set(conv_para_index) | {para_index[i] for i in range(0, len(para_index), 2)}


# 用到cat_add算子的并行
san_index = [
    4,  68,   6,  61,   10, 69,   12, 62,   14, 63,  18, 70,  20, 64,   22, 65,   24, 66,
    28, 71,   30, 67,   87, 73,   83, 75,   36, 76,  42, 78,  46, 79,   48, 80,   52, 81,
    54, 82
]


para_base = TXT_DIR
base = INSTRUCTION_DIR


hit_count = 0
#用并行conv算子计算
for n in index:

    if n == 0:
        param_path = os.path.join(para_base, "focus/focus_param.txt")
    elif 0 < n < 58:
        param_path = os.path.join(para_base, f"conv{n}/conv{n}_param.txt")
    elif 58 <= n <= 60:
        param_path = os.path.join(para_base, f"out{n - 57}/out{n - 57}_param.txt")
    elif 61 <= n <= 67:
        param_path = os.path.join(para_base, f"add{n - 61}/add{n - 61}_param.txt")
    elif 68 <= n <= 71:
        param_path = os.path.join(para_base, f"cat{n - 68}/cat{n - 68}_param.txt")
    elif 72 <= n <= 74:
        param_path = os.path.join(para_base, f"cat4_{n - 71}/cat4_{n - 71}_param.txt")
    elif 75 <= n <= 82:
        param_path = os.path.join(para_base, f"cat{n - 70}/cat{n - 70}_param.txt")
    elif 83 <= n <= 84:
        param_path = os.path.join(para_base, f"up{n - 83}/up{n - 83}_param.txt")
    elif 85 <= n <= 87:
        param_path = os.path.join(para_base, f"max{n - 84}/max{n - 84}_param.txt")
    else:
        print(f"⚠️ 未定义路径: n = {n}")
        continue

    # --- 2. 核心修改逻辑 ---
    if n in conv_para_index:
       if os.path.exists(param_path):
           hit_count += 1  # 命中次数加 1
           try:
               with open(param_path, 'r', encoding='utf-8') as f:
                   lines = f.readlines()

               new_lines = []

               for line in lines:
                   # 1. 匹配 start = 数字 的逻辑
                   match_start = re.search(r'(start\s*=\s*)(\d+)', line)

                   if match_start:
                       prefix = match_start.group(1)
                       original_val = int(match_start.group(2))

                       # 奇数次直接覆盖为 64
                       new_val = 64

                       new_lines.append(f"{prefix}{new_val}\n")
                       file_modified = True

                       status_msg = f"原有值{original_val} 覆盖为{new_val}"
                       print(f"✅ 利用para算子单次运算,第 {hit_count} 次命中 (n={n}): start {status_msg}")

                   else:
                       # 不匹配任何规则的行，保持原样
                       new_lines.append(line)

                # 如果文件内容发生了任何修改，写回磁盘
               if file_modified:
                   with open(param_path, 'w', encoding='utf-8') as f:
                       f.writelines(new_lines)

           except Exception as e:
               print(f"❌ 处理 {param_path} 出错: {e}")

       else:
           print(f"🚫 文件不存在: {param_path}")



# 双算子修改
skip_next = False # 用于标记是否跳过下一次命中
hit_count = 0  # 记录命中 para_index 的次数
for n in index:

    if n == 0:
        param_path = os.path.join(para_base, "focus/focus_param.txt")
    elif 0 < n < 58:
        param_path = os.path.join(para_base, f"conv{n}/conv{n}_param.txt")
    elif 58 <= n <= 60:
        param_path = os.path.join(para_base, f"out{n - 57}/out{n - 57}_param.txt")
    elif 61 <= n <= 67:
        param_path = os.path.join(para_base, f"add{n - 61}/add{n - 61}_param.txt")
    elif 68 <= n <= 71:
        param_path = os.path.join(para_base, f"cat{n - 68}/cat{n - 68}_param.txt")
    elif 72 <= n <= 74:
        param_path = os.path.join(para_base, f"cat4_{n - 71}/cat4_{n - 71}_param.txt")
    elif 75 <= n <= 82:
        param_path = os.path.join(para_base, f"cat{n - 70}/cat{n - 70}_param.txt")
    elif 83 <= n <= 84:
        param_path = os.path.join(para_base, f"up{n - 83}/up{n - 83}_param.txt")
    elif 85 <= n <= 87:
        param_path = os.path.join(para_base, f"max{n - 84}/max{n - 84}_param.txt")
    else:
        print(f"⚠️ 未定义路径: n = {n}")
        continue

    # --- 2. 核心修改逻辑 ---
    if n in para_index:
       if os.path.exists(param_path):
           hit_count += 1  # 命中次数加 1




           # --- 预检查逻辑 ---
           # 找到当前 n 在 para_index 中的位置，看下一个命中值是多少
           current_pos = para_index.index(n)
           has_next = current_pos + 1 < len(para_index)
           if has_next:
               next_n = para_index[current_pos + 1]
               # 条件：即将发生的命中是奇数次 (hit_count + 1)，且下一个 n 在 61-82
               if hit_count % 2 == 1 and 61 <= next_n <= 82:
                   print(f"⚠️ 触发CAT逻辑：当前 n={n} (奇数次预备) 且 下一个命中 n={next_n} 在 61-82。CAT操作start+1。")
                   skip_next = True  # 标记让下一个命中也跳过


           try:
               with open(param_path, 'r', encoding='utf-8') as f:
                   lines = f.readlines()

               new_lines = []
               found_start = False

               for line in lines:
                   # 1. 匹配 start = 数字 的逻辑
                   match_start = re.search(r'(start\s*=\s*)(\d+)', line)
                   # # 2. 匹配 type = 数字 的逻辑 (新增)
                   # match_type = re.search(r'(type\s*=\s*)(\d+)', line)

                   if match_start:
                       prefix = match_start.group(1)
                       original_val = int(match_start.group(2))

                       # if skip_next:
                       #     # 奇数次直接覆盖为 original_val，偶数次原有值 + 1
                       #     new_val = original_val if hit_count % 2 == 1 else original_val + 1
                       #
                       #     new_lines.append(f"{prefix}{new_val}\n")
                       #     file_modified = True
                       #
                       #     status_msg = "保持不变" if hit_count % 2 == 1 else f"原有值{original_val}+1={new_val}"
                       #     print(f"✅ 第 {hit_count} 次命中 (n={n}): start {status_msg}")
                       #
                       # else:
                       # 奇数次直接覆盖为 32，偶数次原有值 + 32
                       new_val = 32 if hit_count % 2 == 1 else original_val + 32

                       new_lines.append(f"{prefix}{new_val}\n")
                       file_modified = True

                       status_msg = "覆盖为32" if hit_count % 2 == 1 else f"原有值{original_val}+32={new_val}"
                       print(f"✅ 第 {hit_count} 次命中 (n={n}): start {status_msg}")

                   else:
                       # 不匹配任何规则的行，保持原样
                       new_lines.append(line)

                # 如果文件内容发生了任何修改，写回磁盘
               if file_modified:
                   with open(param_path, 'w', encoding='utf-8') as f:
                       f.writelines(new_lines)

           except Exception as e:
               print(f"❌ 处理 {param_path} 出错: {e}")

           # # --- 预检查逻辑 ---
           # # 如果上一轮标记了跳过，则重置标记并跳过当前 n
           # if hit_count % 2 == 0 and skip_next:
           #     print(f"⏭️ 跳过处理 (特殊区间后续): n = {n}")
           #     skip_next = False

       else:
           print(f"🚫 文件不存在: {param_path}")





before_val = 0
hit_count = 0
for n in index:

    if n == 0:
        param_path = os.path.join(para_base, "focus/focus_param.txt")
        instruction_path = os.path.join(base, "focus_instruction.txt")
    elif 0 < n < 58:
        param_path = os.path.join(para_base, f"conv{n}/conv{n}_param.txt")
        instruction_path = os.path.join(base, f"conv{n}_instruction.txt")
    elif 58 <= n <= 60:
        param_path = os.path.join(para_base, f"out{n - 57}/out{n - 57}_param.txt")
        instruction_path = os.path.join(base, f"out{n - 57}_instruction.txt")
    elif 61 <= n <= 67:
        param_path = os.path.join(para_base, f"add{n - 61}/add{n - 61}_param.txt")
        instruction_path = os.path.join(base, f"add{n - 61}_instruction.txt")
    elif 68 <= n <= 71:
        param_path = os.path.join(para_base, f"cat{n - 68}/cat{n - 68}_param.txt")
        instruction_path = os.path.join(base, f"cat{n - 68}_instruction.txt")
    elif 72 <= n <= 74:
        param_path = os.path.join(para_base, f"cat4_{n - 71}/cat4_{n - 71}_param.txt")
        instruction_path = os.path.join(base, f"cat4_{n - 71}_instruction.txt")
    elif 75 <= n <= 82:
        param_path = os.path.join(para_base, f"cat{n - 70}/cat{n - 70}_param.txt")
        instruction_path = os.path.join(base, f"cat{n - 70}_instruction.txt")
    elif 83 <= n <= 84:
        param_path = os.path.join(para_base, f"up{n - 83}/up{n - 83}_param.txt")
        instruction_path = os.path.join(base, f"up{n - 83}_instruction.txt")
    elif 85 <= n <= 87:
        param_path = os.path.join(para_base, f"max{n - 84}/max{n - 84}_param.txt")
        instruction_path = os.path.join(base, f"max{n - 84}_instruction.txt")
    else:
        print(f"⚠️ 未定义路径: n = {n}")
        continue

    # --- 2. 核心修改逻辑 ---
    if n in san_index:
       if os.path.exists(param_path):
           hit_count += 1  # 命中次数加 1
           try:
               with open(param_path, 'r', encoding='utf-8') as f:
                   lines = f.readlines()

               new_lines = []
               found_start = False


               for line in lines:
                   # 1. 匹配 start = 数字 的逻辑
                   match_start = re.search(r'(start\s*=\s*)(\d+)', line)
                   # 2. 匹配 type = 数字 的逻辑 (新增)
                   match_type = re.search(r'(type\s*=\s*)(\d+)', line)

                   if match_start:
                       prefix = match_start.group(1)
                       original_val = int(match_start.group(2))
                       #记录值
                       if hit_count % 2 == 1:
                           before_val = original_val

                       # 奇数次直接覆盖为 original_val，偶数次原有值 + before_val
                       new_val = original_val if hit_count % 2 == 1 else original_val + before_val

                       new_lines.append(f"{prefix}{new_val}\n")
                       file_modified = True

                       status_msg = "原有值不动" if hit_count % 2 == 1 else f"原有值{original_val}+{before_val}={new_val}"
                       print(f"san✅ 第 {hit_count} 次命中 (n={n}): start {status_msg}")





                   elif match_type :
                       # --- 新增功能：当 n 在 [61, 82] 范围内时修改 type ---
                       prefix = match_type.group(1)
                       original_type_val = int(match_type.group(2))
                       new_type_val = original_type_val + 128

                       new_lines.append(f"{prefix}{new_type_val}\n")
                       file_modified = True
                       print(f"✨ type命中 (n={n}): type 从 {original_type_val} 加上 128 变为 {new_type_val}")

                   else:
                       # 不匹配任何规则的行，保持原样
                       new_lines.append(line)

                # 如果文件内容发生了任何修改，写回磁盘
               if file_modified:
                   with open(param_path, 'w', encoding='utf-8') as f:
                       f.writelines(new_lines)

           except Exception as e:
               print(f"❌ 处理 {param_path} 出错: {e}")

           # --- 预检查逻辑 ---
           # 如果上一轮标记了跳过，则重置标记并跳过当前 n
           if hit_count % 2 == 0 and skip_next:
               print(f"⏭️ 跳过处理 (特殊区间后续): n = {n}")
               skip_next = False

       else:
           print(f"🚫 文件不存在: {param_path}")


    gen_fpga_instruction(param_path, instruction_path)





print("全部生成完成！")







output_file = os.path.join(NPU_DIR, "instruction_all.txt")
# 清空旧输出文件
if os.path.exists(output_file):
    os.remove(output_file)

with open(output_file, 'a') as outfile:
    outfile.write("0000000E\n")
    outfile.write("00000000\n")
for n in index:
    if n == 0:
        instruction_path = os.path.join(base, "focus_instruction.txt")
    elif 0 < n < 58:
        instruction_path = os.path.join(base, f"conv{n}_instruction.txt")
    elif 58 <= n <= 60:
        instruction_path = os.path.join(base, f"out{n - 57}_instruction.txt")
    elif 61 <= n <= 67:
        instruction_path = os.path.join(base, f"add{n - 61}_instruction.txt")
    elif 68 <= n <= 71:
        instruction_path = os.path.join(base, f"cat{n - 68}_instruction.txt")
    elif 72 <= n <= 74:
        instruction_path = os.path.join(base, f"cat4_{n - 71}_instruction.txt")
    elif 75 <= n <= 82:
        instruction_path = os.path.join(base, f"cat{n - 70}_instruction.txt")
    elif 83 <= n <= 84:
        instruction_path = os.path.join(base, f"up{n - 83}_instruction.txt")
    elif 85 <= n <= 87:
        instruction_path = os.path.join(base, f"max{n - 84}_instruction.txt")
    else:
        print(f"⚠️ 未定义路径: n = {n}")
        continue

    instruction_all(instruction_path, output_file)

with open(output_file, 'a') as outfile:
    outfile.write("0000000E\n")
    outfile.write("00000001\n")

print(f"\n✅ 所有文件合并完成，末尾已追加结束指令 → {output_file}")
