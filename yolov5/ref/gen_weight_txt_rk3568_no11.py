import os
import re
import numpy as np
import cv2 as cv
from gen_weight_util_rk3568 import focus_addr
from gen_weight_util_rk3568 import focus_param
from gen_weight_util_rk3568 import cat_add_addr
from gen_weight_util_rk3568 import weight33_to_txt
from gen_weight_util_rk3568 import weight11_to_txt
from gen_weight_util_rk3568 import weight11_to_txt_16
from gen_weight_util_rk3568 import bias33_to_txt
from gen_weight_util_rk3568 import bias11_to_txt
from gen_weight_util_rk3568 import scale_zero_to_txt
from gen_weight_util_rk3568 import quant_to_txt
from gen_weight_util_rk3568 import img_to_txt
from gen_weight_util_rk3568 import torch_to_txt
from gen_weight_util_rk3568 import conv_addr
from gen_weight_util_rk3568 import conv11_param
from gen_weight_util_rk3568 import conv11_param_16
from gen_weight_util_rk3568 import conv33_param
from gen_weight_util_rk3568 import add_param
from gen_weight_util_rk3568 import cat_param
from gen_weight_util_rk3568 import max_addr
from gen_weight_util_rk3568 import max_param
from gen_weight_util_rk3568 import up_addr
from gen_weight_util_rk3568 import up_param
from gen_weight_util_rk3568 import txt2bin


def focus(npy_path, path):
    # 结果
    torch_path = npy_path + r"\img.int.npy"
    torch_result = np.load(torch_path)
    torch_temp = np.full((1, 4, 320, 320), 0, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)
    torch_to_txt(path + r"\focus_torch.txt", torch_result)

    # 初始图片处理
    img_path = npy_path + r"\quant.int.npy"
    img = np.load(img_path)
    img_temp = np.full((1, 1, 640, 640), 0, dtype=int)
    img = np.concatenate((img, img_temp), axis=1)
    quant_to_txt(path + r"\focus_in_data.txt", img)  # 保存特征图
    torch_to_txt(path + r"\focus_in_data_lei.txt", img)  # 竖向排列

    focus_addr(path + r"\focus_param.txt", 0x9000_0000, 0xB000_0000)
    focus_param(path + r"\focus_param.txt", img, torch_result)


def conv1(npy_path, path):
    # 未经过当前卷积层的原始特征图
    img_path = npy_path + r"\img.int.npy"
    # 图片的scale
    img_scale_path = npy_path + r"\quant.scale.npy"
    # 图片的zero
    img_zero_path = npy_path + r"\quant.zero_point.npy"

    # 经过当前卷积层的卷积后特征图
    torch_path = npy_path + r"\img_conv1.int.npy"

    # 权重
    weight_path = npy_path + r"\backbone.conv1.conv.weight.int.npy"
    # 权重的scale
    weight_scale_path = npy_path + r"\backbone.conv1.conv.weight.scale.npy"
    # 权重的zero
    weight_zero_path = npy_path + r"\backbone.conv1.conv.weight.zero_point.npy"

    # 偏置
    bias_path = npy_path + r"\backbone.conv1.conv.bias.npy"
    s3_path = npy_path + r"\backbone.conv1.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv1.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv1_in_data.txt", img)
    bias33_to_txt(path + r"\conv1_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv1_weight.txt", weight)

    conv_addr(path + r"\conv1_param.txt", 0xB000_0000, 0x8000_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv1_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv1_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv1_torch.txt", torch_result)


def conv2(npy_path, path):
    # 未经过当前卷积层的原始特征图
    img_path = npy_path + r"\img_conv1.int.npy"
    # 图片的scale
    img_scale_path = npy_path + r"\backbone.conv1.conv.scale.npy"
    # 图片的zero
    img_zero_path = npy_path + r"\backbone.conv1.conv.zero_point.npy"

    # 经过当前卷积层的卷积后特征图
    torch_path = npy_path + r"\img_conv2.int.npy"

    # 权重
    weight_path = npy_path + r"\backbone.conv2.conv.weight.int.npy"
    # 权重的scale
    weight_scale_path = npy_path + r"\backbone.conv2.conv.weight.scale.npy"
    # 权重的zero
    weight_zero_path = npy_path + r"\backbone.conv2.conv.weight.zero_point.npy"

    # 偏置
    bias_path = npy_path + r"\backbone.conv2.conv.bias.npy"
    s3_path = npy_path + r"\backbone.conv2.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv2.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv2_in_data.txt", img)
    bias33_to_txt(path + r"\conv2_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv2_weight.txt", weight)

    conv_addr(path + r"\conv2_param.txt", 0xC000_0000, 0x8010_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv2_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv2_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv2_torch.txt", torch_result)


def conv3(npy_path, path):
    img_path = npy_path + r"\img_conv2.int.npy"
    torch_path = npy_path + r"\img_conv3.int.npy"
    weight_path = npy_path + r"\backbone.conv3.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv2.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv3.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv2.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv3.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv3.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv3.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv3.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv3_in_data.txt", img)
    bias11_to_txt(path + r"\conv3_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv3_weight.txt", weight)

    conv_addr(path + r"\conv3_param.txt", 0xB000_0000, 0x8020_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv3_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv3_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv3_torch.txt", torch_result)


def conv4(npy_path, path):
    img_path = npy_path + r"\img_conv2.int.npy"
    torch_path = npy_path + r"\img_conv4.int.npy"
    weight_path = npy_path + r"\backbone.conv4.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv2.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv4.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv2.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv4.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv4.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv4.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv4.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv4_in_data.txt", img)
    bias11_to_txt(path + r"\conv4_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv4_weight.txt", weight)

    conv_addr(path + r"\conv4_param.txt", 0xB000_0000, 0x8030_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv4_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv4_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv4_torch.txt", torch_result)


def conv5(npy_path, path):
    img_path = npy_path + r"\img_conv3.int.npy"
    torch_path = npy_path + r"\img_conv5.int.npy"
    weight_path = npy_path + r"\backbone.conv5.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv3.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv5.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv3.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv5.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv5.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv5.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv5.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv5_in_data.txt", img)
    bias11_to_txt(path + r"\conv5_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv5_weight.txt", weight)

    conv_addr(path + r"\conv5_param.txt", 0xC000_0000, 0x8040_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv5_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv5_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv5_torch.txt", torch_result)


def conv6(npy_path, path):
    img_path = npy_path + r"\img_conv5.int.npy"
    torch_path = npy_path + r"\img_conv6.int.npy"
    weight_path = npy_path + r"\backbone.conv6.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv5.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv6.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv5.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv6.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv6.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv6.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv6.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv6_in_data.txt", img)
    bias33_to_txt(path + r"\conv6_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv6_weight.txt", weight)

    conv_addr(path + r"\conv6_param.txt", 0xD000_0000, 0x8050_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv6_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv6_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv6_torch.txt", torch_result)


def add0(npy_path, path):
    img_path_0 = npy_path + r"\img_conv6.int.npy"
    img_path_1 = npy_path + r"\img_conv3.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv6.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv6.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv3.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv3.conv.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add0.scale.npy"
    torch_path = npy_path + r"\add0.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add0_param.txt", 0xE000_0000, 0xC000_0000, 0xD000_0000)
    add_param(path + r"\add0_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add0_torch.txt", torch_result)


def cat0(npy_path, path):
    img_path_1 = npy_path + r"\add0.int.npy"
    img_path_0 = npy_path + r"\img_conv4.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add0.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add0.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv4.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv4.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat0.scale.npy"
    torch_path = npy_path + r"\cat0.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat0_param.txt", 0xD000_0000, 0xD000_0000, 0xC000_0000)
    cat_param(path + r"\cat0_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat0_torch.txt", torch_result)


def conv7(npy_path, path):
    img_path = npy_path + r"\cat0.int.npy"
    torch_path = npy_path + r"\img_conv7.int.npy"
    weight_path = npy_path + r"\backbone.conv7.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat0.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv7.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat0.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv7.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv7.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv7.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv7.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv7_in_data.txt", img)
    bias11_to_txt(path + r"\conv7_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv7_weight.txt", weight)

    conv_addr(path + r"\conv7_param.txt", 0xC000_0000, 0x8060_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv7_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv7_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv7_torch.txt", torch_result)


# F:\python\yolov5\npy
def conv8(npy_path, path):
    img_path = npy_path + r"\img_conv7.int.npy"
    torch_path = npy_path + r"\img_conv8.int.npy"
    weight_path = npy_path + r"\backbone.conv8.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv7.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv8.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv7.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv8.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv8.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv8.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv8.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv8_in_data.txt", img)
    bias33_to_txt(path + r"\conv8_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv8_weight.txt", weight)

    conv_addr(path + r"\conv8_param.txt", 0xB000_0000, 0x8070_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv8_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv8_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv8_torch.txt", torch_result)


def conv9(npy_path, path):
    img_path = npy_path + r"\img_conv8.int.npy"
    torch_path = npy_path + r"\img_conv9.int.npy"
    weight_path = npy_path + r"\backbone.conv9.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv8.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv9.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv8.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv9.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv9.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv9.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv9.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv9_in_data.txt", img)
    bias11_to_txt(path + r"\conv9_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv9_weight.txt", weight)

    conv_addr(path + r"\conv9_param.txt", 0xC000_0000, 0x8080_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv9_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv9_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv9_torch.txt", torch_result)


def conv10(npy_path, path):
    img_path = npy_path + r"\img_conv8.int.npy"
    torch_path = npy_path + r"\img_conv10.int.npy"
    weight_path = npy_path + r"\backbone.conv10.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv8.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv10.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv8.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv10.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv10.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv10.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv10.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv10_in_data.txt", img)
    bias11_to_txt(path + r"\conv10_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv10_weight.txt", weight)

    conv_addr(path + r"\conv10_param.txt", 0xC000_0000, 0x8090_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv10_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv10_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv10_torch.txt", torch_result)


def conv11(npy_path, path):
    img_path = npy_path + r"\img_conv9.int.npy"
    torch_path = npy_path + r"\img_conv11.int.npy"
    weight_path = npy_path + r"\backbone.conv11.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv9.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv11.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv9.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv11.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv11.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv11.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv11.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv11_in_data.txt", img)
    bias11_to_txt(path + r"\conv11_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv11_weight.txt", weight)

    conv_addr(path + r"\conv11_param.txt", 0xB000_0000, 0x80a0_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv11_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv11_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv11_torch.txt", torch_result)


def conv12(npy_path, path):
    img_path = npy_path + r"\img_conv11.int.npy"
    torch_path = npy_path + r"\img_conv12.int.npy"
    weight_path = npy_path + r"\backbone.conv12.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv11.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv12.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv11.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv12.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv12.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv12.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv12.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv12_in_data.txt", img)
    bias33_to_txt(path + r"\conv12_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv12_weight.txt", weight)

    conv_addr(path + r"\conv12_param.txt", 0xC000_0000, 0x80b0_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv12_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv12_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv12_torch.txt", torch_result)


def add1(npy_path, path):
    img_path_0 = npy_path + r"\img_conv12.int.npy"
    img_path_1 = npy_path + r"\img_conv9.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv12.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv12.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv9.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv9.conv.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add1.scale.npy"
    torch_path = npy_path + r"\add1.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add1_param.txt", 0xE000_0000, 0xB000_0000, 0xD000_0000)
    add_param(path + r"\add1_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add1_torch.txt", torch_result)


def conv13(npy_path, path):
    img_path = npy_path + r"\add1.int.npy"
    torch_path = npy_path + r"\img_conv13.int.npy"
    weight_path = npy_path + r"\backbone.conv13.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_add1.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv13.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_add1.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv13.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv13.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv13.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv13.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv13_in_data.txt", img)
    bias11_to_txt(path + r"\conv13_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv13_weight.txt", weight)

    conv_addr(path + r"\conv13_param.txt", 0xD000_0000, 0x80c0_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv13_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv13_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv13_torch.txt", torch_result)


def conv14(npy_path, path):
    img_path = npy_path + r"\img_conv13.int.npy"
    torch_path = npy_path + r"\img_conv14.int.npy"
    weight_path = npy_path + r"\backbone.conv14.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv13.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv14.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv13.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv14.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv14.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv14.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv14.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv14_in_data.txt", img)
    bias33_to_txt(path + r"\conv14_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv14_weight.txt", weight)

    conv_addr(path + r"\conv14_param.txt", 0xB000_0000, 0x80d0_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv14_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv14_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv14_torch.txt", torch_result)


def add2(npy_path, path):
    img_path_0 = npy_path + r"\img_conv14.int.npy"
    img_path_1 = npy_path + r"\add1.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv14.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv14.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add1.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add1.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add2.scale.npy"
    torch_path = npy_path + r"\add2.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add2_param.txt", 0xE000_0000, 0xD000_0000, 0xB000_0000)
    add_param(path + r"\add2_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add2_torch.txt", torch_result)


def cat1(npy_path, path):
    img_path_1 = npy_path + r"\add2.int.npy"
    img_path_0 = npy_path + r"\img_conv10.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add2.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add2.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv10.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv10.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat1.scale.npy"
    torch_path = npy_path + r"\cat1.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat1_param.txt",0xD000_0000 , 0xB000_0000, 0xC000_0000)
    cat_param(path + r"\cat1_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat1_torch.txt", torch_result)


def conv15(npy_path, path):
    img_path = npy_path + r"\cat1.int.npy"
    torch_path = npy_path + r"\img_conv15.int.npy"
    weight_path = npy_path + r"\backbone.conv15.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat1.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv15.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat1.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv15.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv15.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv15.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv15.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv15_in_data.txt", img)
    bias11_to_txt(path + r"\conv15_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv15_weight.txt", weight)

    conv_addr(path + r"\conv15_param.txt", 0xC000_0000, 0x80e0_0000, 0xA000_0000)
    scale_zero_to_txt(path + r"\conv15_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv15_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv15_torch.txt", torch_result)


def conv16(npy_path, path):
    img_path = npy_path + r"\img_conv15.int.npy"
    torch_path = npy_path + r"\img_conv16.int.npy"
    weight_path = npy_path + r"\backbone.conv16.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv15.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv16.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv15.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv16.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv16.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv16.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv16.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv16_in_data.txt", img)
    bias33_to_txt(path + r"\conv16_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv16_weight.txt", weight)

    conv_addr(path + r"\conv16_param.txt", 0xA000_0000, 0x80f0_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv16_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv16_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv16_torch.txt", torch_result)


def conv17(npy_path, path):
    img_path = npy_path + r"\img_conv16.int.npy"
    torch_path = npy_path + r"\img_conv17.int.npy"
    weight_path = npy_path + r"\backbone.conv17.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv16.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv17.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv16.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv17.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv17.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv17.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv17.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv17_in_data.txt", img)
    bias11_to_txt(path + r"\conv17_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv17_weight.txt", weight)

    conv_addr(path + r"\conv17_param.txt", 0xB000_0000, 0x8100_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv17_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv17_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv17_torch.txt", torch_result)


def conv18(npy_path, path):
    img_path = npy_path + r"\img_conv16.int.npy"
    torch_path = npy_path + r"\img_conv18.int.npy"
    weight_path = npy_path + r"\backbone.conv18.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv16.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv18.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv16.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv18.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv18.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv18.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv18.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv18_in_data.txt", img)
    bias11_to_txt(path + r"\conv18_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv18_weight.txt", weight)

    conv_addr(path + r"\conv18_param.txt", 0xB000_0000, 0x8110_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv18_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv18_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv18_torch.txt", torch_result)


def conv19(npy_path, path):
    img_path = npy_path + r"\img_conv17.int.npy"
    torch_path = npy_path + r"\img_conv19.int.npy"
    weight_path = npy_path + r"\backbone.conv19.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv17.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv19.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv17.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv19.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv19.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv19.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv19.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv19_in_data.txt", img)
    bias11_to_txt(path + r"\conv19_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv19_weight.txt", weight)

    conv_addr(path + r"\conv19_param.txt", 0xC000_0000, 0x8120_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv19_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv19_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv19_torch.txt", torch_result)


def conv20(npy_path, path):
    img_path = npy_path + r"\img_conv19.int.npy"
    torch_path = npy_path + r"\img_conv20.int.npy"
    weight_path = npy_path + r"\backbone.conv20.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv19.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv20.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv19.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv20.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv20.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv20.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv20.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv20_in_data.txt", img)
    bias33_to_txt(path + r"\conv20_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv20_weight.txt", weight)

    conv_addr(path + r"\conv20_param.txt", 0xB000_0000, 0x8130_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv20_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv20_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv20_torch.txt", torch_result)


def add3(npy_path, path):
    img_path_0 = npy_path + r"\img_conv20.int.npy"
    img_path_1 = npy_path + r"\img_conv17.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv20.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv20.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv17.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv17.conv.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add3.scale.npy"
    torch_path = npy_path + r"\add3.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add3_param.txt", 0xE000_0000, 0xC000_0000, 0xD000_0000)
    add_param(path + r"\add3_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add3_torch.txt", torch_result)


def conv21(npy_path, path):
    img_path = npy_path + r"\add3.int.npy"
    torch_path = npy_path + r"\img_conv21.int.npy"
    weight_path = npy_path + r"\backbone.conv21.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_add3.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv21.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_add3.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv21.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv21.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv21.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv21.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv21_in_data.txt", img)
    bias11_to_txt(path + r"\conv21_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv21_weight.txt", weight)

    conv_addr(path + r"\conv21_param.txt", 0xD000_0000, 0x8140_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv21_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv21_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv21_torch.txt", torch_result)


def conv22(npy_path, path):
    img_path = npy_path + r"\img_conv21.int.npy"
    torch_path = npy_path + r"\img_conv22.int.npy"
    weight_path = npy_path + r"\backbone.conv22.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv21.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv22.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv21.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv22.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv22.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv22.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv22.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv22_in_data.txt", img)
    bias33_to_txt(path + r"\conv22_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv22_weight.txt", weight)

    conv_addr(path + r"\conv22_param.txt", 0xC000_0000, 0x8150_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv22_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv22_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv22_torch.txt", torch_result)


def add4(npy_path, path):
    img_path_0 = npy_path + r"\img_conv22.int.npy"
    img_path_1 = npy_path + r"\add3.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv22.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv22.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add3.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add3.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add4.scale.npy"
    torch_path = npy_path + r"\add4.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add4_param.txt", 0xE000_0000, 0xD000_0000, 0xC000_0000)
    add_param(path + r"\add4_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add4_torch.txt", torch_result)


def conv23(npy_path, path):
    img_path = npy_path + r"\add4.int.npy"
    torch_path = npy_path + r"\img_conv23.int.npy"
    weight_path = npy_path + r"\backbone.conv23.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_add4.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv23.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_add4.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv23.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv23.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv23.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv23.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv23_in_data.txt", img)
    bias11_to_txt(path + r"\conv23_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv23_weight.txt", weight)

    conv_addr(path + r"\conv23_param.txt", 0xC000_0000, 0x8160_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv23_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv23_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv23_torch.txt", torch_result)


def conv24(npy_path, path):
    img_path = npy_path + r"\img_conv23.int.npy"
    torch_path = npy_path + r"\img_conv24.int.npy"
    weight_path = npy_path + r"\backbone.conv24.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv23.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv24.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv23.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv24.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv24.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv24.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv24.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv24_in_data.txt", img)
    bias33_to_txt(path + r"\conv24_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv24_weight.txt", weight)

    conv_addr(path + r"\conv24_param.txt", 0xB000_0000, 0x8170_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv24_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv24_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv24_torch.txt", torch_result)


def add5(npy_path, path):
    img_path_0 = npy_path + r"\img_conv24.int.npy"
    img_path_1 = npy_path + r"\add4.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv24.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv24.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add4.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add4.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add5.scale.npy"
    torch_path = npy_path + r"\add5.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add5_param.txt", 0xE000_0000, 0xC000_0000, 0xD000_0000)
    add_param(path + r"\add5_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add5_torch.txt", torch_result)


def cat2(npy_path, path):
    img_path_1 = npy_path + r"\add5.int.npy"
    img_path_0 = npy_path + r"\img_conv18.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add5.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add5.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv18.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv18.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat2.scale.npy"
    torch_path = npy_path + r"\cat2.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat2_param.txt", 0xD000_0000, 0xD000_0000, 0xC000_0000)
    cat_param(path + r"\cat2_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat2_torch.txt", torch_result)


def conv25(npy_path, path):
    img_path = npy_path + r"\cat2.int.npy"
    torch_path = npy_path + r"\img_conv25.int.npy"
    weight_path = npy_path + r"\backbone.conv25.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat2.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv25.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat2.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv25.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv25.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv25.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv25.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv25_in_data.txt", img)
    bias11_to_txt(path + r"\conv25_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv25_weight.txt", weight)

    conv_addr(path + r"\conv25_param.txt", 0xC000_0000, 0x8180_0000, 0xA500_0000)
    scale_zero_to_txt(path + r"\conv25_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv25_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv25_torch.txt", torch_result)


def conv26(npy_path, path):
    img_path = npy_path + r"\img_conv25.int.npy"
    torch_path = npy_path + r"\img_conv26.int.npy"
    weight_path = npy_path + r"\backbone.conv26.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv25.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv26.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv25.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv26.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv26.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv26.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv26.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv26_in_data.txt", img)
    bias33_to_txt(path + r"\conv26_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv26_weight.txt", weight)

    conv_addr(path + r"\conv26_param.txt", 0xA500_0000, 0x8190_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv26_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv26_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv26_torch.txt", torch_result)


def conv27(npy_path, path):
    img_path = npy_path + r"\img_conv26.int.npy"
    torch_path = npy_path + r"\img_conv27.int.npy"
    weight_path = npy_path + r"\backbone.conv27.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv26.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv27.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv26.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv27.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv27.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv27.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv27.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv27_in_data.txt", img)
    bias11_to_txt(path + r"\conv27_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv27_weight.txt", weight)

    conv_addr(path + r"\conv27_param.txt", 0xB000_0000, 0x81a0_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv27_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv27_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv27_torch.txt", torch_result)


def conv28(npy_path, path):
    img_path = npy_path + r"\img_conv26.int.npy"
    torch_path = npy_path + r"\img_conv28.int.npy"
    weight_path = npy_path + r"\backbone.conv28.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv26.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv28.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv26.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv28.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv28.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv28.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv28.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv28_in_data.txt", img)
    bias11_to_txt(path + r"\conv28_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv28_weight.txt", weight)

    conv_addr(path + r"\conv28_param.txt", 0xB000_0000, 0x81b0_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv28_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv28_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv28_torch.txt", torch_result)


def conv29(npy_path, path):
    img_path = npy_path + r"\img_conv27.int.npy"
    torch_path = npy_path + r"\img_conv29.int.npy"
    weight_path = npy_path + r"\backbone.conv29.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv27.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv29.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv27.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv29.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv29.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv29.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv29.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv29_in_data.txt", img)
    bias11_to_txt(path + r"\conv29_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv29_weight.txt", weight)

    conv_addr(path + r"\conv29_param.txt", 0xC000_0000, 0x81c0_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv29_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv29_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv29_torch.txt", torch_result)


def conv30(npy_path, path):
    img_path = npy_path + r"\img_conv29.int.npy"
    torch_path = npy_path + r"\img_conv30.int.npy"
    weight_path = npy_path + r"\backbone.conv30.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv29.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv30.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv29.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv30.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv30.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv30.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv30.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv30_in_data.txt", img)
    bias33_to_txt(path + r"\conv30_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv30_weight.txt", weight)

    conv_addr(path + r"\conv30_param.txt", 0xB000_0000, 0x81d0_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv30_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv30_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv30_torch.txt", torch_result)


def add6(npy_path, path):
    img_path_0 = npy_path + r"\img_conv30.int.npy"
    img_path_1 = npy_path + r"\img_conv27.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv30.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv30.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv27.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv27.conv.zero_point.npy"
    add_scale_path = npy_path + r"\backbone.float_fun_add6.scale.npy"
    torch_path = npy_path + r"\add6.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(add_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\add_in_data_0.txt", img_0)
    img_to_txt(path + r"\add_in_data_1.txt", img_1)
    cat_add_addr(path + r"\add6_param.txt", 0xE000_0000, 0xC000_0000, 0xD000_0000)
    add_param(path + r"\add6_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\add6_torch.txt", torch_result)


def cat3(npy_path, path):
    img_path_1 = npy_path + r"\add6.int.npy"
    img_path_0 = npy_path + r"\img_conv28.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.float_fun_add6.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.float_fun_add6.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv28.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv28.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat3.scale.npy"
    torch_path = npy_path + r"\cat3.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat3_param.txt", 0xD000_0000, 0xD000_0000, 0xC000_0000)
    cat_param(path + r"\cat3_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat3_torch.txt", torch_result)


def conv31(npy_path, path):
    img_path = npy_path + r"\cat3.int.npy"
    torch_path = npy_path + r"\img_conv31.int.npy"
    weight_path = npy_path + r"\backbone.conv31.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat3.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv31.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat3.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv31.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv31.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv31.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv31.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv31_in_data.txt", img)
    bias11_to_txt(path + r"\conv31_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv31_weight.txt", weight)

    conv_addr(path + r"\conv31_param.txt", 0xC000_0000, 0x81e0_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv31_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv31_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv31_torch.txt", torch_result)


def conv32(npy_path, path):
    img_path = npy_path + r"\img_conv31.int.npy"
    torch_path = npy_path + r"\img_conv32.int.npy"
    weight_path = npy_path + r"\backbone.conv32.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv31.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv32.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv31.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv32.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv32.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv32.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv32.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv32_in_data.txt", img)
    bias11_to_txt(path + r"\conv32_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv32_weight.txt", weight)

    conv_addr(path + r"\conv32_param.txt", 0xB000_0000, 0x81f0_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv32_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv32_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv32_torch.txt", torch_result)


def max1(npy_path, path):
    img_path = npy_path + r"\img_conv32.int.npy"
    torch_path = npy_path + r"\max1.int.npy"
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(path + r"\max1_in_data.txt", img)
    torch_to_txt(path + r"\max1_torch.txt", torch_result)
    max_addr(path + r"\max1_param.txt", 0xC000_0000, 0xD000_0000)
    max_param(path + r"\max1_param.txt", img, torch_result)


def max2(npy_path, path):
    img_path = npy_path + r"\max1.int.npy"
    torch_path = npy_path + r"\max2.int.npy"
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(path + r"\max2_in_data.txt", img)
    torch_to_txt(path + r"\max2_torch.txt", torch_result)
    max_addr(path + r"\max2_param.txt", 0xD000_0000, 0xE000_0000)
    max_param(path + r"\max2_param.txt", img, torch_result)


def max3(npy_path, path):
    img_path = npy_path + r"\max2.int.npy"
    torch_path = npy_path + r"\max3.int.npy"
    img = np.load(img_path)
    torch_result = np.load(torch_path)
    img_to_txt(path + r"\max3_in_data.txt", img)
    torch_to_txt(path + r"\max3_torch.txt", torch_result)
    max_addr(path + r"\max3_param.txt", 0xE000_0000, 0xF000_0000)
    max_param(path + r"\max3_param.txt", img, torch_result)


def cat4_1(npy_path, path):
    img_path_0 = npy_path + r"\max1.int.npy"
    img_path_1 = npy_path + r"\img_conv32.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv32.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv32.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv32.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv32.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat4.scale.npy"
    torch_path = npy_path + r"\cat4.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    torch_result = torch_result[:, 256:, :, :]
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat4_1_param.txt", 0xD000_0000, 0xC000_0000, 0xB000_0000)
    cat_param(path + r"\cat4_1_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat4_1_torch.txt", torch_result)


def cat4_2(npy_path, path):
    img_path_0 = npy_path + r"\max3.int.npy"
    img_path_1 = npy_path + r"\max2.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv32.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv32.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv32.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv32.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat4.scale.npy"
    torch_path = npy_path + r"\cat4.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    torch_result = torch_result[:, :256, :, :]
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat4_2_param.txt", 0xF000_0000, 0xE000_0000, 0xC000_0000)
    cat_param(path + r"\cat4_2_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat4_2_torch.txt", torch_result)


def cat4_3(npy_path, path):
    torch_path = npy_path + r"\cat4.int.npy"
    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", torch_result[:, :256, :, :])
    img_to_txt(path + r"\cat_in_data_1.txt", torch_result[:, 256:, :, :])
    cat_add_addr(path + r"\cat4_3_param.txt", 0xC000_0000, 0xB000_0000, 0xD000_0000)
    cat_param(path + r"\cat4_3_param.txt", torch_result[:, 256:, :, :], torch_result, 1, 1, 1, 0, 0)
    torch_to_txt(path + r"\cat4_3_torch.txt", torch_result)


def conv33(npy_path, path):
    img_path = npy_path + r"\cat4.int.npy"
    torch_path = npy_path + r"\img_conv33.int.npy"
    weight_path = npy_path + r"\backbone.conv33.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat4.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv33.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat4.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv33.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv33.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv33.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv33.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv33_in_data.txt", img)
    bias11_to_txt(path + r"\conv33_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv33_weight.txt", weight)

    conv_addr(path + r"\conv33_param.txt", 0xD000_0000, 0x8200_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv33_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv33_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv33_torch.txt", torch_result)


def conv34(npy_path, path):
    img_path = npy_path + r"\img_conv33.int.npy"
    torch_path = npy_path + r"\img_conv34.int.npy"
    weight_path = npy_path + r"\backbone.conv34.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv33.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv34.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv33.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv34.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv34.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv34.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv34.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv34_in_data.txt", img)
    bias11_to_txt(path + r"\conv34_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv34_weight.txt", weight)

    conv_addr(path + r"\conv34_param.txt", 0xB000_0000, 0x8210_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv34_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv34_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv34_torch.txt", torch_result)


def up0(npy_path, path):
    img_path = npy_path + r"\img_conv34.int.npy"
    torch_path = npy_path + r"\upsample_0.int.npy"

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    img_to_txt(path + r"\up0_in_data.txt", img)
    torch_to_txt(path + r"\up0_torch.txt", torch_result)
    up_addr(path + r"\up0_param.txt", 0xC000_0000, 0xD000_0000)
    up_param(path + r"\up0_param.txt", img, torch_result)


def cat5(npy_path, path):
    img_path_0 = npy_path + r"\upsample_0.int.npy"
    img_path_1 = npy_path + r"\img_conv25.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv34.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv34.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv25.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv25.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat5.scale.npy"
    torch_path = npy_path + r"\cat5.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat5_param.txt",0xD000_0000, 0xA500_0000, 0xB000_0000)
    cat_param(path + r"\cat5_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat5_torch.txt", torch_result)


def conv35(npy_path, path):
    img_path = npy_path + r"\cat5.int.npy"
    torch_path = npy_path + r"\img_conv35.int.npy"
    weight_path = npy_path + r"\backbone.conv35.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat5.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv35.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat5.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv35.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv35.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv35.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv35.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv35_in_data.txt", img)
    bias11_to_txt(path + r"\conv35_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv35_weight.txt", weight)

    conv_addr(path + r"\conv35_param.txt", 0xB000_0000, 0x8220_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv35_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv35_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv35_torch.txt", torch_result)


def conv36(npy_path, path):
    img_path = npy_path + r"\cat5.int.npy"
    torch_path = npy_path + r"\img_conv36.int.npy"
    weight_path = npy_path + r"\backbone.conv36.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat5.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv36.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat5.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv36.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv36.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv36.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv36.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv36_in_data.txt", img)
    bias11_to_txt(path + r"\conv36_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv36_weight.txt", weight)

    conv_addr(path + r"\conv36_param.txt", 0xB000_0000, 0x8230_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv36_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv36_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv36_torch.txt", torch_result)


def conv37(npy_path, path):
    img_path = npy_path + r"\img_conv35.int.npy"
    torch_path = npy_path + r"\img_conv37.int.npy"
    weight_path = npy_path + r"\backbone.conv37.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv35.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv37.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv35.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv37.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv37.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv37.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv37.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv37_in_data.txt", img)
    bias11_to_txt(path + r"\conv37_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv37_weight.txt", weight)

    conv_addr(path + r"\conv37_param.txt", 0xD000_0000, 0x8240_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv37_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv37_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv37_torch.txt", torch_result)


def conv38(npy_path, path):
    img_path = npy_path + r"\img_conv37.int.npy"
    torch_path = npy_path + r"\img_conv38.int.npy"
    weight_path = npy_path + r"\backbone.conv38.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv37.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv38.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv37.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv38.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv38.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv38.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv38.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv38_in_data.txt", img)
    bias33_to_txt(path + r"\conv38_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv38_weight.txt", weight)

    conv_addr(path + r"\conv38_param.txt", 0xB000_0000, 0x8250_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv38_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv38_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv38_torch.txt", torch_result)


def cat6(npy_path, path):
    img_path_1 = npy_path + r"\img_conv38.int.npy"
    img_path_0 = npy_path + r"\img_conv36.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv38.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv38.conv.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv36.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv36.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat6.scale.npy"
    torch_path = npy_path + r"\cat6.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat6_param.txt", 0xE000_0000, 0xD000_0000, 0xB000_0000)
    cat_param(path + r"\cat6_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat6_torch.txt", torch_result)


def conv39(npy_path, path):
    img_path = npy_path + r"\cat6.int.npy"
    torch_path = npy_path + r"\img_conv39.int.npy"
    weight_path = npy_path + r"\backbone.conv39.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat6.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv39.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat6.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv39.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv39.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv39.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv39.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv39_in_data.txt", img)
    bias11_to_txt(path + r"\conv39_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv39_weight.txt", weight)

    conv_addr(path + r"\conv39_param.txt", 0xB000_0000, 0x8260_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv39_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv39_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv39_torch.txt", torch_result)


def conv40(npy_path, path):
    img_path = npy_path + r"\img_conv39.int.npy"
    torch_path = npy_path + r"\img_conv40.int.npy"
    weight_path = npy_path + r"\backbone.conv40.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv39.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv40.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv39.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv40.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv40.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv40.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv40.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv40_in_data.txt", img)
    bias11_to_txt(path + r"\conv40_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv40_weight.txt", weight)

    conv_addr(path + r"\conv40_param.txt", 0xD000_0000, 0x8270_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv40_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv40_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv40_torch.txt", torch_result)


def up1(npy_path, path):
    img_path = npy_path + r"\img_conv40.int.npy"
    torch_path = npy_path + r"\upsample_1.int.npy"

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    img_to_txt(path + r"\up1_in_data.txt", img)
    torch_to_txt(path + r"\up1_torch.txt", torch_result)
    up_addr(path + r"\up1_param.txt", 0xB000_0000, 0xD000_0000)
    up_param(path + r"\up1_param.txt", img, torch_result)


def cat7(npy_path, path):
    img_path_1 = npy_path + r"\upsample_1.int.npy"
    img_path_0 = npy_path + r"\img_conv15.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv40.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv40.conv.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv15.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv15.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat7.scale.npy"
    torch_path = npy_path + r"\cat7.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat7_param.txt", 0xA000_0000, 0xD000_0000, 0xE000_0000)
    cat_param(path + r"\cat7_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat7_torch.txt", torch_result)


def conv41(npy_path, path):
    img_path = npy_path + r"\cat7.int.npy"
    torch_path = npy_path + r"\img_conv41.int.npy"
    weight_path = npy_path + r"\backbone.conv41.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat7.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv41.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat7.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv41.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv41.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv41.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv41.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv41_in_data.txt", img)
    bias11_to_txt(path + r"\conv41_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv41_weight.txt", weight)

    conv_addr(path + r"\conv41_param.txt", 0xE000_0000, 0x8280_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv41_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv41_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv41_torch.txt", torch_result)


def conv42(npy_path, path):
    img_path = npy_path + r"\cat7.int.npy"
    torch_path = npy_path + r"\img_conv42.int.npy"
    weight_path = npy_path + r"\backbone.conv42.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat7.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv42.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat7.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv42.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv42.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv42.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv42.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv42_in_data.txt", img)
    bias11_to_txt(path + r"\conv42_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv42_weight.txt", weight)

    conv_addr(path + r"\conv42_param.txt", 0xE000_0000, 0x8290_0000, 0xF000_0000)
    scale_zero_to_txt(path + r"\conv42_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv42_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv42_torch.txt", torch_result)


def conv43(npy_path, path):
    img_path = npy_path + r"\img_conv41.int.npy"
    torch_path = npy_path + r"\img_conv43.int.npy"
    weight_path = npy_path + r"\backbone.conv43.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv41.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv43.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv41.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv43.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv43.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv43.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv43.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv43_in_data.txt", img)
    bias11_to_txt(path + r"\conv43_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv43_weight.txt", weight)

    conv_addr(path + r"\conv43_param.txt", 0xD000_0000, 0x82a0_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv43_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv43_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv43_torch.txt", torch_result)


def conv44(npy_path, path):
    img_path = npy_path + r"\img_conv43.int.npy"
    torch_path = npy_path + r"\img_conv44.int.npy"
    weight_path = npy_path + r"\backbone.conv44.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv43.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv44.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv43.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv44.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv44.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv44.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv44.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv44_in_data.txt", img)
    bias33_to_txt(path + r"\conv44_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv44_weight.txt", weight)

    conv_addr(path + r"\conv44_param.txt", 0xE000_0000, 0x82b0_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv44_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv44_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv44_torch.txt", torch_result)


def cat8(npy_path, path):
    img_path_1 = npy_path + r"\img_conv44.int.npy"
    img_path_0 = npy_path + r"\img_conv42.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv44.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv44.conv.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv42.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv42.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat8.scale.npy"
    torch_path = npy_path + r"\cat8.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat8_param.txt", 0xF000_0000, 0xD000_0000, 0xE000_0000)
    cat_param(path + r"\cat8_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat8_torch.txt", torch_result)


def conv45(npy_path, path):
    img_path = npy_path + r"\cat8.int.npy"
    torch_path = npy_path + r"\img_conv45.int.npy"
    weight_path = npy_path + r"\backbone.conv45.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat8.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv45.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat8.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv45.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv45.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv45.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv45.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv45_in_data.txt", img)
    bias11_to_txt(path + r"\conv45_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv45_weight.txt", weight)

    conv_addr(path + r"\conv45_param.txt", 0xE000_0000, 0x82c0_0000, 0xAA00_0000)
    scale_zero_to_txt(path + r"\conv45_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv45_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv45_torch.txt", torch_result)


def conv46(npy_path, path):
    img_path = npy_path + r"\img_conv45.int.npy"
    torch_path = npy_path + r"\img_conv46.int.npy"
    weight_path = npy_path + r"\backbone.conv46.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv45.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv46.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv45.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv46.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv46.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv46.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv46.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv46_in_data.txt", img)
    bias33_to_txt(path + r"\conv46_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv46_weight.txt", weight)

    conv_addr(path + r"\conv46_param.txt", 0xAA00_0000, 0x82d0_0000, 0xF000_0000)
    scale_zero_to_txt(path + r"\conv46_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv46_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv46_torch.txt", torch_result)


def cat9(npy_path, path):
    img_path_0 = npy_path + r"\img_conv46.int.npy"
    img_path_1 = npy_path + r"\img_conv40.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv46.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv46.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv40.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv40.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat9.scale.npy"
    torch_path = npy_path + r"\cat9.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat9_param.txt", 0xF000_0000, 0xB000_0000, 0xE000_0000)
    cat_param(path + r"\cat9_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat9_torch.txt", torch_result)


def conv47(npy_path, path):
    img_path = npy_path + r"\cat9.int.npy"
    torch_path = npy_path + r"\img_conv47.int.npy"
    weight_path = npy_path + r"\backbone.conv47.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat9.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv47.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat9.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv47.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv47.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv47.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv47.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv47_in_data.txt", img)
    bias11_to_txt(path + r"\conv47_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv47_weight.txt", weight)

    conv_addr(path + r"\conv47_param.txt", 0xE000_0000, 0x82e0_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv47_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv47_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv47_torch.txt", torch_result)


def conv48(npy_path, path):
    img_path = npy_path + r"\cat9.int.npy"
    torch_path = npy_path + r"\img_conv48.int.npy"
    weight_path = npy_path + r"\backbone.conv48.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat9.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv48.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat9.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv48.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv48.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv48.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv48.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv48_in_data.txt", img)
    bias11_to_txt(path + r"\conv48_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv48_weight.txt", weight)

    conv_addr(path + r"\conv48_param.txt", 0xE000_0000, 0x82f0_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv48_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv48_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv48_torch.txt", torch_result)


def conv49(npy_path, path):
    img_path = npy_path + r"\img_conv47.int.npy"
    torch_path = npy_path + r"\img_conv49.int.npy"
    weight_path = npy_path + r"\backbone.conv49.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv47.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv49.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv47.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv49.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv49.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv49.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv49.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv49_in_data.txt", img)
    bias11_to_txt(path + r"\conv49_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv49_weight.txt", weight)

    conv_addr(path + r"\conv49_param.txt", 0xD000_0000, 0x8300_0000, 0xE000_0000)
    scale_zero_to_txt(path + r"\conv49_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv49_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv49_torch.txt", torch_result)


def conv50(npy_path, path):
    img_path = npy_path + r"\img_conv49.int.npy"
    torch_path = npy_path + r"\img_conv50.int.npy"
    weight_path = npy_path + r"\backbone.conv50.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv49.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv50.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv49.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv50.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv50.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv50.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv50.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv50_in_data.txt", img)
    bias33_to_txt(path + r"\conv50_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv50_weight.txt", weight)

    conv_addr(path + r"\conv50_param.txt", 0xE000_0000, 0x8310_0000, 0xF000_0000)
    scale_zero_to_txt(path + r"\conv50_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv50_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv50_torch.txt", torch_result)


def cat10(npy_path, path):
    img_path_1 = npy_path + r"\img_conv50.int.npy"
    img_path_0 = npy_path + r"\img_conv48.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv50.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv50.conv.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv48.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv48.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat10.scale.npy"
    torch_path = npy_path + r"\cat10.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat10_param.txt", 0xB000_0000, 0xF000_0000, 0xE000_0000)
    cat_param(path + r"\cat10_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat10_torch.txt", torch_result)


def conv51(npy_path, path):
    img_path = npy_path + r"\cat10.int.npy"
    torch_path = npy_path + r"\img_conv51.int.npy"
    weight_path = npy_path + r"\backbone.conv51.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat10.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv51.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat10.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv51.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv51.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv51.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv51.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv51_in_data.txt", img)
    bias11_to_txt(path + r"\conv51_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv51_weight.txt", weight)

    conv_addr(path + r"\conv51_param.txt", 0xE000_0000, 0x8320_0000, 0xA500_0000)
    scale_zero_to_txt(path + r"\conv51_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv51_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv51_torch.txt", torch_result)


def conv52(npy_path, path):
    img_path = npy_path + r"\img_conv51.int.npy"
    torch_path = npy_path + r"\img_conv52.int.npy"
    weight_path = npy_path + r"\backbone.conv52.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv51.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv52.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv51.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv52.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv52.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv52.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv52.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv52_in_data.txt", img)
    bias33_to_txt(path + r"\conv52_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv52_weight.txt", weight)

    conv_addr(path + r"\conv52_param.txt", 0xA500_0000, 0x8330_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv52_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv52_param.txt", img, torch_result, weight, 1, 1)

    torch_to_txt(path + r"\conv52_torch.txt", torch_result)


def cat11(npy_path, path):
    img_path_0 = npy_path + r"\img_conv52.int.npy"
    img_path_1 = npy_path + r"\img_conv34.int.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv52.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv52.conv.zero_point.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv34.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv34.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat11.scale.npy"
    torch_path = npy_path + r"\cat11.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat11_param.txt", 0xB000_0000, 0xC000_0000, 0xE000_0000)
    cat_param(path + r"\cat11_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat11_torch.txt", torch_result)


def conv53(npy_path, path):
    img_path = npy_path + r"\cat11.int.npy"
    torch_path = npy_path + r"\img_conv53.int.npy"
    weight_path = npy_path + r"\backbone.conv53.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat11.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv53.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat11.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv53.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv53.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv53.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv53.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv53_in_data.txt", img)
    bias11_to_txt(path + r"\conv53_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv53_weight.txt", weight)

    conv_addr(path + r"\conv53_param.txt", 0xE000_0000, 0x8340_0000, 0xB000_0000)
    scale_zero_to_txt(path + r"\conv53_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv53_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv53_torch.txt", torch_result)


def conv54(npy_path, path):
    img_path = npy_path + r"\cat11.int.npy"
    torch_path = npy_path + r"\img_conv54.int.npy"
    weight_path = npy_path + r"\backbone.conv54.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat11.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv54.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat11.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv54.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv54.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv54.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv54.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv54_in_data.txt", img)
    bias11_to_txt(path + r"\conv54_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt(path + r"\conv54_weight.txt", weight)

    conv_addr(path + r"\conv54_param.txt", 0xE000_0000, 0x8350_0000, 0xC000_0000)
    scale_zero_to_txt(path + r"\conv54_param.txt", s1, s2, s3, z1, z3)
    conv11_param(path + r"\conv54_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv54_torch.txt", torch_result)


def conv55(npy_path, path):
    img_path = npy_path + r"\img_conv53.int.npy"
    torch_path = npy_path + r"\img_conv55.int.npy"
    weight_path = npy_path + r"\backbone.conv55.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv53.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv55.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv53.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv55.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv55.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv55.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv55.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv55_in_data.txt", img)
    bias11_to_txt(path + r"\conv55_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv55_weight.txt", weight)

    conv_addr(path + r"\conv55_param.txt", 0xB000_0000, 0x8360_0000, 0xD000_0000)
    scale_zero_to_txt(path + r"\conv55_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv55_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv55_torch.txt", torch_result)


def conv56(npy_path, path):
    img_path = npy_path + r"\img_conv55.int.npy"
    torch_path = npy_path + r"\img_conv56.int.npy"
    weight_path = npy_path + r"\backbone.conv56.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv55.conv.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv56.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv55.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv56.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv56.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv56.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv56.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv56_in_data.txt", img)
    bias33_to_txt(path + r"\conv56_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight33_to_txt(path + r"\conv56_weight.txt", weight)

    conv_addr(path + r"\conv56_param.txt", 0xD000_0000, 0x8370_0000, 0xF000_0000)
    scale_zero_to_txt(path + r"\conv56_param.txt", s1, s2, s3, z1, z3)
    conv33_param(path + r"\conv56_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv56_torch.txt", torch_result)


def cat12(npy_path, path):
    img_path_1 = npy_path + r"\img_conv56.int.npy"
    img_path_0 = npy_path + r"\img_conv54.int.npy"
    img_scale_path_1 = npy_path + r"\backbone.conv56.conv.scale.npy"
    img_zero_path_1 = npy_path + r"\backbone.conv56.conv.zero_point.npy"
    img_scale_path_0 = npy_path + r"\backbone.conv54.conv.scale.npy"
    img_zero_path_0 = npy_path + r"\backbone.conv54.conv.zero_point.npy"
    cat_scale_path = npy_path + r"\backbone.float_fun_cat12.scale.npy"
    torch_path = npy_path + r"\cat12.int.npy"
    img_0 = np.load(img_path_0)
    img_1 = np.load(img_path_1)
    s0 = np.load(img_scale_path_0)
    s1 = np.load(img_scale_path_1)
    s2 = np.load(cat_scale_path)
    z0 = np.load(img_zero_path_0)
    z1 = np.load(img_zero_path_1)

    torch_result = np.load(torch_path)
    img_to_txt(path + r"\cat_in_data_0.txt", img_0)
    img_to_txt(path + r"\cat_in_data_1.txt", img_1)
    cat_add_addr(path + r"\cat12_param.txt", 0xC000_0000, 0xF000_0000, 0xE000_0000)
    cat_param(path + r"\cat12_param.txt", img_0, torch_result, s0, s1, s2, z0, z1)
    torch_to_txt(path + r"\cat12_torch.txt", torch_result)


def conv57(npy_path, path):
    img_path = npy_path + r"\cat12.int.npy"
    torch_path = npy_path + r"\img_conv57.int.npy"
    weight_path = npy_path + r"\backbone.conv57.conv.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.float_fun_cat12.scale.npy"
    weight_scale_path = npy_path + r"\backbone.conv57.conv.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.float_fun_cat12.zero_point.npy"
    weight_zero_path = npy_path + r"\backbone.conv57.conv.weight.zero_point.npy"
    bias_path = npy_path + r"\backbone.conv57.conv.bias.npy"

    s3_path = npy_path + r"\backbone.conv57.conv.scale.npy"
    z3_path = npy_path + r"\backbone.conv57.conv.zero_point.npy"

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

    img_to_txt(path + r"\conv57_in_data.txt", img)
    bias11_to_txt(path + r"\conv57_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\conv57_weight.txt", weight)

    conv_addr(path + r"\conv57_param.txt", 0xE000_0000, 0x8380_0000, 0xA000_0000)
    scale_zero_to_txt(path + r"\conv57_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\conv57_param.txt", img, torch_result, weight, 0, 1)

    torch_to_txt(path + r"\conv57_torch.txt", torch_result)


def out1(npy_path, path):
    img_path = npy_path + r"\img_conv57.int.npy"
    torch_path = npy_path + r"\out1.int.npy"
    weight_path = npy_path + r"\conv1.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv57.conv.scale.npy"
    weight_scale_path = npy_path + r"\conv1.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv57.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\conv1.weight.zero_point.npy"
    # bias_path = r"\conv1.bias.npy"

    s3_path = npy_path + r"\conv1.scale.npy"
    z3_path = npy_path + r"\conv1.zero_point.npy"

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 256, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(80, dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 20, 20), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(path + r"\out1_in_data.txt", img)
    bias11_to_txt(path + r"\out1_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\out1_weight.txt", weight)

    conv_addr(path + r"\out1_param.txt", 0xA000_0000, 0x8390_0000, 0XA300_0000)
    scale_zero_to_txt(path + r"\out1_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\out1_param.txt", img, torch_result, weight, 0, 0)

    torch_to_txt(path + r"\out1_torch.txt", torch_result)
    img_to_txt(path + r"\out1_torch_16.txt", torch_result)


def out2(npy_path, path):
    img_path = npy_path + r"\img_conv51.int.npy"
    torch_path = npy_path + r"\out2.int.npy"
    weight_path = npy_path + r"\conv2.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv51.conv.scale.npy"
    weight_scale_path = npy_path + r"\conv2.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv51.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\conv2.weight.zero_point.npy"
    # bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\conv1.bias.npy"

    s3_path = npy_path + r"\conv2.scale.npy"
    z3_path = npy_path + r"\conv2.zero_point.npy"

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 128, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(80, dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 40, 40), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(path + r"\out2_in_data.txt", img)
    bias11_to_txt(path + r"\out2_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\out2_weight.txt", weight)

    conv_addr(path + r"\out2_param.txt", 0xA500_0000, 0x83a0_0000, 0XA800_0000)
    scale_zero_to_txt(path + r"\out2_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\out2_param.txt", img, torch_result, weight, 0, 0)

    torch_to_txt(path + r"\out2_torch.txt", torch_result)
    img_to_txt(path + r"\out2_torch_16.txt", torch_result)


def out3(npy_path, path):
    img_path = npy_path + r"\img_conv45.int.npy"
    torch_path = npy_path + r"\out3.int.npy"
    weight_path = npy_path + r"\conv3.weight.int.npy"
    img_scale_path = npy_path + r"\backbone.conv45.conv.scale.npy"
    weight_scale_path = npy_path + r"\conv3.weight.scale.npy"
    img_zero_path = npy_path + r"\backbone.conv45.conv.zero_point.npy"
    weight_zero_path = npy_path + r"\conv3.weight.zero_point.npy"
    # bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\conv1.bias.npy"

    s3_path = npy_path + r"\conv3.scale.npy"
    z3_path = npy_path + r"\conv3.zero_point.npy"

    img = np.load(img_path)
    torch_result = np.load(torch_path)

    weight = np.load(weight_path)
    weight_temp = np.zeros((5, 64, 1, 1), dtype=int)
    weight = np.concatenate((weight, weight_temp), axis=0)
    img_scale = np.load(img_scale_path)
    weight_scale = np.load(weight_scale_path)
    img_zero = np.load(img_zero_path)
    weight_zero = np.load(weight_zero_path)
    bias = np.zeros(80, dtype=int)

    s1 = np.load(img_scale_path)
    s2 = np.load(weight_scale_path)
    s3 = np.load(s3_path)
    z1 = np.load(img_zero_path)
    z2 = np.load(weight_zero_path)
    z3 = np.load(z3_path)
    torch_temp = np.full((1, 5, 80, 80), z3, dtype=int)
    torch_result = np.concatenate((torch_result, torch_temp), axis=1)

    img_to_txt(path + r"\out3_in_data.txt", img)
    bias11_to_txt(path + r"\out3_weight.txt", weight, s1, s2, s3, z1, z2, z3, bias)
    weight11_to_txt_16(path + r"\out3_weight.txt", weight)

    conv_addr(path + r"\out3_param.txt", 0xAA00_0000, 0x83b0_0000, 0XAC00_0000)
    scale_zero_to_txt(path + r"\out3_param.txt", s1, s2, s3, z1, z3)
    conv11_param_16(path + r"\out3_param.txt", img, torch_result, weight, 0, 0)

    torch_to_txt(path + r"\out3_torch.txt", torch_result)
    img_to_txt(path + r"\out3_torch_16.txt", torch_result)


# E:\yolov5-v6.1-pytorch-master\ref\txt
def gen_fpga_weight(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)
    for i in range(1, 58):
        txt2bin(txt_path + r"\conv" + str(i) + r"\conv" + str(i) + r"_weight.txt",
                bin_path + r"\conv" + str(i) + r"_weight.bin")
    txt2bin(txt_path + r"\out1\out1_weight.txt", bin_path + r"\out1_weight.bin")
    txt2bin(txt_path + r"\out2\out2_weight.txt", bin_path + r"\out2_weight.bin")
    txt2bin(txt_path + r"\out3\out3_weight.txt", bin_path + r"\out3_weight.bin")


# 单步调试输入数据
def gen_fpga_in_data(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)

    # focus
    txt2bin(txt_path + r"\focus\focus_in_data.txt",
            bin_path + r"\focus_data.bin")
    # conv
    for i in range(1, 58):
        txt2bin(txt_path + r"\conv" + str(i) + r"\conv" + str(i) + r"_in_data.txt",
                bin_path + r"\conv" + str(i) + r"_data.bin")
    # out
    for i in range(1, 4):
        txt2bin(txt_path + r"\out" + str(i) + r"\out" + str(i) + r"_in_data.txt",
                bin_path + r"\out" + str(i) + r"_data.bin")
    # add
    for i in range(0, 7):
        txt2bin(txt_path + r"\add" + str(i) + r"\add_in_data_" + str(0) + r".txt",
                bin_path + r"\add" + str(i) + r"_data_" + str(0) + r".bin")
        txt2bin(txt_path + r"\add" + str(i) + r"\add_in_data_" + str(1) + r".txt",
                bin_path + r"\add" + str(i) + r"_data_" + str(1) + r".bin")
    # cat
    for i in range(0, 4):
        txt2bin(txt_path + r"\cat" + str(i) + r"\cat_in_data_" + str(0) + r".txt",
                bin_path + r"\cat" + str(i) + r"_data_" + str(0) + r".bin")
        txt2bin(txt_path + r"\cat" + str(i) + r"\cat_in_data_" + str(1) + r".txt",
                bin_path + r"\cat" + str(i) + r"_data_" + str(1) + r".bin")
    for i in range(1, 4):
        txt2bin(txt_path + r"\cat4_" + str(i) + r"\cat_in_data_" + str(0) + r".txt",
                bin_path + r"\cat4_" + str(i) + r"_data_" + str(0) + r".bin")
        txt2bin(txt_path + r"\cat4_" + str(i) + r"\cat_in_data_" + str(1) + r".txt",
                bin_path + r"\cat4_" + str(i) + r"_data_" + str(1) + r".bin")
    for i in range(5, 13):
        txt2bin(txt_path + r"\cat" + str(i) + r"\cat_in_data_" + str(0) + r".txt",
                bin_path + r"\cat" + str(i) + r"_data_" + str(0) + r".bin")
        txt2bin(txt_path + r"\cat" + str(i) + r"\cat_in_data_" + str(1) + r".txt",
                bin_path + r"\cat" + str(i) + r"_data_" + str(1) + r".bin")
    # up
    for i in range(0, 2):
        txt2bin(txt_path + r"\up" + str(i) + r"\up" + str(i) + r"_in_data.txt",
                bin_path + r"\up" + str(i) + r"_data.bin")
    # max
    for i in range(1, 4):
        txt2bin(txt_path + r"\max" + str(i) + r"\max" + str(i) + r"_in_data.txt",
                bin_path + r"\max" + str(i) + r"_data.bin")


# 三个head结果
def gen_fpga_torch_data(txt_path, bin_path):
    os.makedirs(bin_path, exist_ok=True)
    # out的结果
    for i in range(1, 4):
        txt2bin(txt_path + r"\out" + str(i) + r"\out" + str(i) + r"_torch_16.txt",
                bin_path + r"\out" + str(i) + r"_torch_data.bin")


# E:\yolov5-v6.1-pytorch-master\npy
def gen_fpga_img(npy_path, img_path):
    quant_scale_path = npy_path + r"\quant.scale.npy"
    quant_zero_path = npy_path + r"\quant.zero_point.npy"

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
    torch_to_txt(r"E:\yolov5-v6.1-pytorch-master\ref\txt\focus" + r"\focus_torch_img.txt", torch_result)
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

focus(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\focus")

add0(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add0")
add1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add1")
add2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add2")
add3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add3")
add4(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add4")
add5(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add5")
add6(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\add6")

cat0(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat0")
cat1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat1")
cat2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat2")
cat3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat3")
cat4_1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat4_1")
cat4_2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat4_2")
cat4_3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat4_3")
cat5(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat5")
cat6(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat6")
cat7(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat7")
cat8(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat8")
cat9(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat9")
cat10(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat10")
cat11(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat11")
cat12(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\cat12")

up0(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\up0")
up1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\up1")

max1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\max1")
max2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\max2")
max3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\max3")

conv1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv1")
conv2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv2")
conv3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv3")
conv4(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv4")
conv5(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv5")
conv6(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv6")
conv7(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv7")
conv8(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv8")
conv9(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv9")
conv10(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv10")
conv11(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv11")
conv12(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv12")
conv13(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv13")
conv14(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv14")
conv15(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv15")
conv16(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv16")
conv17(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv17")
conv18(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv18")
conv19(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv19")
conv20(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv20")
conv21(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv21")
conv22(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv22")
conv23(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv23")
conv24(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv24")
conv25(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv25")
conv26(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv26")
conv27(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv27")
conv28(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv28")
conv29(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv29")
conv30(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv30")
conv31(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv31")
conv32(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv32")
conv33(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv33")
conv34(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv34")
conv35(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv35")
conv36(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv36")
conv37(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv37")
conv38(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv38")
conv39(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv39")
conv40(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv40")
conv41(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv41")
conv42(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv42")
conv43(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv43")
conv44(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv44")
conv45(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv45")
conv46(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv46")
conv47(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv47")
conv48(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv48")
conv49(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv49")
conv50(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv50")
conv51(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv51")
conv52(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv52")
conv53(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv53")
conv54(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv54")
conv55(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv55")
conv56(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv56")
conv57(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\conv57")
out1(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\out1")
out2(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\out2")
out3(r"F:\python\yolov5\npy", r"F:\python\yolov5\ref\txt\out3")

gen_fpga_in_data(r"F:\python\yolov5\ref\txt", r"F:\VSstudio\Yolov5\Yolov5\indata_bin")
gen_fpga_torch_data(r"F:\python\yolov5\ref\txt", r"F:\VSstudio\Yolov5\Yolov5\torch_bin")
gen_fpga_weight(r"F:\python\yolov5\ref\txt", r"F:\VSstudio\Yolov5\Yolov5\weight_bin")

index = [
    0, 1, 2, 3, 5, 6, 61, 4, 68, 7, 8, 9, 11, 12, 62, 13, 14, 63, 10, 69, 15, 16, 17, 19,
    20, 64, 21, 22, 65, 23, 24, 66, 18, 70, 25, 26, 27, 29, 30, 67, 28, 71, 31, 32, 85, 72, 86, 87,
    73, 74, 33, 34, 83, 75, 35, 37, 38, 36, 76, 39, 40, 84, 77, 41, 43, 44, 42, 78, 45, 60, 46, 79,
    47, 49, 50, 48, 80, 51, 59, 52, 81, 53, 55, 56, 54, 82, 57, 58
]

#
conv16_index = [
    3, 9, 15, 17, 25, 27, 35, 41, 45, 47, 51, 53, 59, 60, 57, 58, 39, 40, 33, 34, 31, 32
]

para_index = [
    5, 6,     7, 8,     11, 12,   13, 14,
    19, 20,   21, 22,   23, 24,   29, 30,
    37, 38,   43, 44,   49, 50,   55, 56
]


# 用到cat_add算子的并行
san_index = [
    4,  68,   6,  61,   10, 69,   12, 62,   14, 63,  18, 70,  20, 64,   22, 65,   24, 66,
    28, 71,   30, 67,   87, 73,   83, 75,   36, 76,  42, 78,  46, 79,   48, 80,   52, 81,
    54, 82
]


para_base = r"F:/python/yolov5/ref/txt"
base = r"F:/VSstudio/Yolov5/Yolov5/instruction"


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
    if n in conv16_index:
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







output_file = r"F:/VSstudio/Yolov5/Yolov5/instruction_all.txt"
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
