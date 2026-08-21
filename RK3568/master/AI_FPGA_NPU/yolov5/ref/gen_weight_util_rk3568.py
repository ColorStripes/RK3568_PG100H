import numpy as np
import os

cha_par_in = 16

all_weight = 0
cha_par_out = 2

all_weight_para = 0
cha_par_out_para = 4

#focus的地址分配
def focus_addr(path, s_addr_0, m_addr):
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    with open(path, 'w') as f:
        f.write("s_addr_0 = " + str(s_addr_0) + "\n")
        f.write("m_addr = " + str(m_addr) + "\n")


def focus_param(path, img, touch_result):

    img = img[0]
    touch_result = touch_result[0]
    img_c, img_h, img_w = img.shape
    touch_c, touch_h, touch_w = touch_result.shape
    with open(path, 'a') as f:
        f.write("type = " + str(64) + "\n")
        f.write("stride = " + str(0) + "\n")
        f.write("in_col_channel_num = " + str(img_c * img_w) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("calculate_cout_num = " + str(touch_c // cha_par_in) + "\n")
        f.write("col_num = " + str(img_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("start = " + str(16) + "\n")


# 这个是取部分weight节省BRAM的排序方法
def weight33_to_txt(weight_path, weight):
    co, ci, _, _ = weight.shape
    with open(weight_path, 'a') as f:
        for m in range(0, co, cha_par_out):
            for k in range(0, ci, cha_par_in):
                for i in range(3):
                    for j in range(3):
                        for n in range(cha_par_out):  # 核0-7   先变核  后变前后16通道
                            s1 = 0
                            s2 = 0
                            s3 = 0
                            s4 = 0
                            s5 = 0
                            s6 = 0
                            s7 = 0
                            s8 = 0
                            for z in range(2):  # 下面是16个通道
                                s1 |= ((weight[m + n][k + z + 0][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s2 |= ((weight[m + n][k + z + 2][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s3 |= ((weight[m + n][k + z + 4][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s4 |= ((weight[m + n][k + z + 6][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s5 |= ((weight[m + n][k + z + 8][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s6 |= ((weight[m + n][k + z + 10][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s7 |= ((weight[m + n][k + z + 12][i][j] & 0xff) << (z * 8))
                            for z in range(2):
                                s8 |= ((weight[m + n][k + z + 14][i][j] & 0xff) << (z * 8))
                            hex_str1 = f"{s1:04x}"
                            hex_str2 = f"{s2:04x}"
                            hex_str3 = f"{s3:04x}"
                            hex_str4 = f"{s4:04x}"
                            hex_str5 = f"{s5:04x}"
                            hex_str6 = f"{s6:04x}"
                            hex_str7 = f"{s7:04x}"
                            hex_str8 = f"{s8:04x}"
                            f.write(
                                hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")


# #  这个是一次全部通道的weight不节省BRAM的排序方法
# def weight33_to_txt(weight_path, weight):
#     co, ci, _, _ = weight.shape
#     with open(weight_path, 'a') as f:
#         for i in range(3):
#             for j in range(3):
#                 for m in range(0, co, cha_par_out):
#                     for k in range(0, ci, cha_par_in):
#                         for n in range(cha_par_out):  # 核0-7   先变核  后变前后16通道
#                             s1 = 0
#                             s2 = 0
#                             s3 = 0
#                             s4 = 0
#                             s5 = 0
#                             s6 = 0
#                             s7 = 0
#                             s8 = 0
#                             for z in range(2):  # 下面是16个通道
#                                 s1 |= ((weight[m + n][k + z + 0][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s2 |= ((weight[m + n][k + z + 2][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s3 |= ((weight[m + n][k + z + 4][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s4 |= ((weight[m + n][k + z + 6][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s5 |= ((weight[m + n][k + z + 8][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s6 |= ((weight[m + n][k + z + 10][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s7 |= ((weight[m + n][k + z + 12][i][j] & 0xff) << (z * 8))
#                             for z in range(2):
#                                 s8 |= ((weight[m + n][k + z + 14][i][j] & 0xff) << (z * 8))
#                             hex_str1 = f"{s1:04x}"
#                             hex_str2 = f"{s2:04x}"
#                             hex_str3 = f"{s3:04x}"
#                             hex_str4 = f"{s4:04x}"
#                             hex_str5 = f"{s5:04x}"
#                             hex_str6 = f"{s6:04x}"
#                             hex_str7 = f"{s7:04x}"
#                             hex_str8 = f"{s8:04x}"
#                             f.write(
#                                 hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")

def bias33_to_txt(bias_path, weight, s1, s2, s3, z1, z2, z3, bias):
    dir_path = os.path.dirname(bias_path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    co, ci, _, _ = weight.shape
    bias_1 = np.zeros(co)
    for i in range(co):
        temp = np.zeros(ci)
        for j in range(ci):
            temp[j] = z1 * weight[i][j][0][0] + z1 * weight[i][j][0][1] + \
                      z1 * weight[i][j][0][2] + z1 * weight[i][j][1][0] + \
                      z1 * weight[i][j][1][1] + z1 * weight[i][j][1][2] + \
                      z1 * weight[i][j][2][0] + z1 * weight[i][j][2][1] + \
                      z1 * weight[i][j][2][2]
        bias_1[i] = temp.sum()  # 输入通道相加
    bias_2 = bias / s3 - (s1 * s2 / s3) * bias_1  # bias/s3 - s1*s2/s3 * (z1 * q2)
    k = bias_2 * (2 ** 16)  # 16位小数 定点数
    bias_3 = np.round((bias_2 * (2 ** 16))).astype(np.int32)  # 32位 16为整数 16位小数
    # with open(bias_path, 'a') as f:
    #     for i in range(co):
    #         hex_str1 = f"{bias_3[i] & 0xffffffff:032x}"  #转化为32位为左补0的16进制数  32个16进制数是128bit的数
    #         if i == co - 1:
    #             f.write(hex_str1)
    #         else:
    #             f.write(hex_str1 + "\n")
    with open(bias_path, 'w') as f:
        for i in range(0, co, 2):
            hex_str1 = f"{bias_3[i] & 0xffffffff:016x}"
            hex_str2 = f"{bias_3[i + 1] & 0xffffffff:016x}"
            # f.write(str(int(bias_3[i + 1])) + " " + str(int(bias_3[i])) + "\n")
            if i == co - 2:
                f.write(hex_str2 + hex_str1 + "\n")
            else:
                f.write(hex_str2 + hex_str1 + "\n")


def bias11_to_txt(bias_path, weight, s1, s2, s3, z1, z2, z3, bias):
    co, ci, _, _ = weight.shape
    bias_1 = np.zeros(co)
    for i in range(co):
        temp = np.zeros(ci)
        for j in range(ci):
            temp[j] = z1 * weight[i][j][0][0]
        bias_1[i] = temp.sum()
    bias_2 = bias / s3 - (s1 * s2 / s3) * bias_1
    k = bias_2 * (2 ** 16)  # 16位小数 定点数
    bias_3 = np.round((bias_2 * (2 ** 16))).astype(np.int32)  # 32位 16为整数 16位小数
    with open(bias_path, 'w') as f:
        for i in range(0, co, 2):
            hex_str1 = f"{bias_3[i] & 0xffffffff:016x}"
            hex_str2 = f"{bias_3[i + 1] & 0xffffffff:016x}"
            # f.write(str(int(bias_3[i + 1])) + " " + str(int(bias_3[i])) + "\n")
            if i == co - 2:
                f.write(hex_str2 + hex_str1 + "\n")
            else:
                f.write(hex_str2 + hex_str1 + "\n")

# 16并行度
def weight11_to_txt_para(weight_path, weight):
    co, ci, _, _ = weight.shape
    with open(weight_path, 'a') as f:
        for m in range(0, co, cha_par_out_para):
            for k in range(0, ci, cha_par_in):
                for n in range(cha_par_out_para):
                    s1 = 0
                    s2 = 0
                    s3 = 0
                    s4 = 0
                    s5 = 0
                    s6 = 0
                    s7 = 0
                    s8 = 0
                    for z in range(2):
                        s1 |= ((weight[m + n][k + z + 0][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s2 |= ((weight[m + n][k + z + 2][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s3 |= ((weight[m + n][k + z + 4][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s4 |= ((weight[m + n][k + z + 6][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s5 |= ((weight[m + n][k + z + 8][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s6 |= ((weight[m + n][k + z + 10][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s7 |= ((weight[m + n][k + z + 12][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s8 |= ((weight[m + n][k + z + 14][0][0] & 0xff) << (z * 8))
                    hex_str1 = f"{s1:04x}"
                    hex_str2 = f"{s2:04x}"
                    hex_str3 = f"{s3:04x}"
                    hex_str4 = f"{s4:04x}"
                    hex_str5 = f"{s5:04x}"
                    hex_str6 = f"{s6:04x}"
                    hex_str7 = f"{s7:04x}"
                    hex_str8 = f"{s8:04x}"
                    # if m == co - 1 and k == ci - 1 and n == c - 16:
                    #     f.write(
                    #         hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1)
                    # else:
                    f.write(
                        hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")


# 8并行度
def weight11_to_txt(weight_path, weight):
    co, ci, _, _ = weight.shape
    with open(weight_path, 'a') as f:
        for m in range(0, co, cha_par_out):
            for k in range(0, ci, cha_par_in):
                for n in range(cha_par_out):
                    s1 = 0
                    s2 = 0
                    s3 = 0
                    s4 = 0
                    s5 = 0
                    s6 = 0
                    s7 = 0
                    s8 = 0
                    for z in range(2):
                        s1 |= ((weight[m + n][k + z + 0][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s2 |= ((weight[m + n][k + z + 2][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s3 |= ((weight[m + n][k + z + 4][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s4 |= ((weight[m + n][k + z + 6][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s5 |= ((weight[m + n][k + z + 8][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s6 |= ((weight[m + n][k + z + 10][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s7 |= ((weight[m + n][k + z + 12][0][0] & 0xff) << (z * 8))
                    for z in range(2):
                        s8 |= ((weight[m + n][k + z + 14][0][0] & 0xff) << (z * 8))
                    hex_str1 = f"{s1:04x}"
                    hex_str2 = f"{s2:04x}"
                    hex_str3 = f"{s3:04x}"
                    hex_str4 = f"{s4:04x}"
                    hex_str5 = f"{s5:04x}"
                    hex_str6 = f"{s6:04x}"
                    hex_str7 = f"{s7:04x}"
                    hex_str8 = f"{s8:04x}"
                    # if m == co - 1 and k == ci - 1 and n == c - 16:
                    #     f.write(
                    #         hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1)
                    # else:
                    f.write(
                        hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")




def scale_zero_to_txt(path, s1, s2, s3, z1, z3):
    #追加写入
    with open(path, 'a') as f:
        f.write("scale_3 = " + str(int(np.round(((s1 * s2 / s3) * (2 ** 16))).astype(np.int32))) + "\n")  # 32位 16为整数 16位小数
        # print(int(z1))
        f.write("zero_1 = " + str(int(z1)) + "\n")
        f.write("zero_3 = " + str(int(z3)) + "\n")


def quant_to_txt(img_path, img):
    dir_path = os.path.dirname(img_path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)
    img = img[0]
    c, h, w = img.shape
    with open(img_path, 'w') as f:
        for i in range(h):
            for j in range(0, w, 4):
                s1 = 0
                s2 = 0
                s3 = 0
                s4 = 0
                s5 = 0
                s6 = 0
                s7 = 0
                s8 = 0
                for z in range(2):
                    s1 |= (img[z][i][j] << (z * 8))
                for z in range(2):
                    s2 |= (img[z + 2][i][j] << (z * 8))
                for z in range(2):
                    s3 |= (img[z][i][j + 1] << (z * 8))
                for z in range(2):
                    s4 |= (img[z + 2][i][j + 1] << (z * 8))
                for z in range(2):
                    s5 |= (img[z][i][j + 2] << (z * 8))
                for z in range(2):
                    s6 |= (img[z + 2][i][j + 2] << (z * 8))
                for z in range(2):
                    s7 |= (img[z][i][j + 3] << (z * 8))
                for z in range(2):
                    s8 |= (img[z + 2][i][j + 3] << (z * 8))
                hex_str1 = f"{s1:04x}"
                hex_str2 = f"{s2:04x}"
                hex_str3 = f"{s3:04x}"
                hex_str4 = f"{s4:04x}"
                hex_str5 = f"{s5:04x}"
                hex_str6 = f"{s6:04x}"
                hex_str7 = f"{s7:04x}"
                hex_str8 = f"{s8:04x}"
                if i == h - 1 and j == w - 1:
                    f.write(
                        hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1)
                else:
                    f.write(
                        hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")


def img_to_txt(img_path, img):
    dir_path = os.path.dirname(img_path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    img = img[0]
    c, h, w = img.shape
    zz = 0
    with open(img_path, 'w') as f:
        for i in range(h):
            for j in range(w):
                for k in range(0, c, cha_par_in):
                    zz = zz + 1
                    s1 = 0
                    s2 = 0
                    s3 = 0
                    s4 = 0
                    s5 = 0
                    s6 = 0
                    s7 = 0
                    s8 = 0
                    for z in range(2):
                        s1 |= (img[k + z][i][j] << (z * 8))
                    for z in range(2):
                        s2 |= (img[k + z + 2][i][j] << (z * 8))
                    for z in range(2):
                        s3 |= (img[k + z + 4][i][j] << (z * 8))
                    for z in range(2):
                        s4 |= (img[k + z + 6][i][j] << (z * 8))
                    for z in range(2):
                        s5 |= (img[k + z + 8][i][j] << (z * 8))
                    for z in range(2):
                        s6 |= (img[k + z + 10][i][j] << (z * 8))
                    for z in range(2):
                        s7 |= (img[k + z + 12][i][j] << (z * 8))
                    for z in range(2):
                        s8 |= (img[k + z + 14][i][j] << (z * 8))
                    hex_str1 = f"{s1:04x}"
                    hex_str2 = f"{s2:04x}"
                    hex_str3 = f"{s3:04x}"
                    hex_str4 = f"{s4:04x}"
                    hex_str5 = f"{s5:04x}"
                    hex_str6 = f"{s6:04x}"
                    hex_str7 = f"{s7:04x}"
                    hex_str8 = f"{s8:04x}"
                    if i == h - 1 and j == w - 1 and k == c - 16:
                        f.write(
                            hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1)
                    else:
                        f.write(
                            hex_str8 + hex_str7 + hex_str6 + hex_str5 + hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")


def torch_to_txt(path, img):
    # 取出目录路径
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    img = img[0]
    c, h, w = img.shape
    with open(path, "w") as f:
        for i in range(h):
            for j in range(w):
                for k in range(c):
                    if i == h - 1 and j == w - 1 and k == c - 1:
                        f.write(str(img[k][i][j]))
                    else:
                        f.write(str(img[k][i][j]) + "\n")


#conv的地址分配
def conv_addr(path, s_addr_0, weight_addr, m_addr):
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    with open(path, 'w') as f:
        f.write("s_addr_0 = " + str(s_addr_0) + "\n")
        f.write("weight_addr = " + str(weight_addr) + "\n")
        f.write("m_addr = " + str(m_addr) + "\n")


def conv33_param(path, img, touch_result, weight, stride, relu):
    img = img[0]
    touch_result = touch_result[0]
    img_c, img_h, img_w = img.shape
    touch_c, touch_h, touch_w = touch_result.shape
    co, ci, _, _ = weight.shape
    # print(co, ci)
    with open(path, 'a') as f:
        f.write("type = " + str(1) + "\n")
        f.write("stride = " + str(stride) + "\n")
        f.write("relu = " + str(relu) + "\n")
        f.write("in_col_channel_num = " + str(img_c * img_w) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("col_num = " + str(img_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_num = " + str((ci // cha_par_in) * (co // cha_par_out)) + "\n")
        f.write("calculate_cin_num = " + str(ci // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(co // cha_par_out) + "\n")
        f.write("weight_sum = " + str(ci * co * 9 + co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        if all_weight:
            f.write("weight_len = " + str(ci * co) + "\n")  # 一个点的字节数
        else:
            f.write("weight_len = " + str(co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2

        # f.write("channel_in_num = " + str(ci) + "\n")
        # f.write("channel_out_num = " + str(co) + "\n")
        ## f.write("weight_len = " + str(ci * co * 9 + co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        ## f.write("bias_len = " + str(co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        # f.write("weight_len = " + str(16 * 8 * 9) + "\n")  # 一行并了两个bias  所以co /2
        # f.write("weight_num = " + str(ci * co) + "\n")  ########## //16其实可以不要
        f.write("start = " + str(1) + "\n")


def conv11_param(path, img, touch_result, weight, stride, relu):
    img = img[0]
    touch_result = touch_result[0]
    img_c, img_h, img_w = img.shape
    touch_c, touch_h, touch_w = touch_result.shape
    co, ci, _, _ = weight.shape
    with open(path, 'a') as f:
        f.write("type = " + str(2) + "\n")
        f.write("stride = " + str(stride) + "\n")
        f.write("relu = " + str(relu) + "\n")
        f.write("in_col_channel_num = " + str(img_c * img_w) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("col_num = " + str(img_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_num = " + str((ci // cha_par_in) * (co // cha_par_out)) + "\n")
        f.write("calculate_cin_num = " + str(ci // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(co // cha_par_out) + "\n")
        f.write("weight_sum = " + str(ci * co + co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        if all_weight:
            f.write("weight_len = " + str(ci * co) + "\n")  # 一个点的字节数
        else:
            f.write("weight_len = " + str(co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        f.write("start = " + str(1) + "\n")

def conv11_param_para(path, img, touch_result, weight, stride, relu):
    img = img[0]
    touch_result = touch_result[0]
    img_c, img_h, img_w = img.shape
    touch_c, touch_h, touch_w = touch_result.shape
    co, ci, _, _ = weight.shape
    with open(path, 'a') as f:
        f.write("type = " + str(2) + "\n")
        f.write("stride = " + str(stride) + "\n")
        f.write("relu = " + str(relu) + "\n")
        f.write("in_col_channel_num = " + str(img_c * img_w) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("col_num = " + str(img_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_num = " + str((ci // cha_par_in) * (co // cha_par_out_para)) + "\n")
        f.write("calculate_cin_num = " + str(ci // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(co // cha_par_out_para) + "\n")
        f.write("weight_sum = " + str(ci * co + co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        if all_weight_para:
            f.write("weight_len = " + str(ci * co) + "\n")  # 一个点的字节数
        else:
            f.write("weight_len = " + str(co // 2 * 16) + "\n")  # 一行并了两个bias  所以co /2
        f.write("start = " + str(1) + "\n")


def cat_add_addr(path, s_addr_0, s_addr_1, m_addr):
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    with open(path, 'w') as f:
        f.write("s_addr_0 = " + str(s_addr_0) + "\n")
        f.write("s_addr_1 = " + str(s_addr_1) + "\n")
        f.write("m_addr = " + str(m_addr) + "\n")


def add_param(path, img, touch_result, s0, s1, s2, z0, z1):
    img = img[0]
    img_c, img_h, img_w = img.shape
    touch_result = touch_result[0]
    touch_c, touch_h, touch_w = touch_result.shape
    with open(path, 'a') as f:
        f.write("type = " + str(4) + "\n")
        f.write("stride = " + str(0) + "\n")
        f.write("in_col_channel_num = " + str(img_w * img_c) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        # f.write("calculate_cin_num = " + str(img_c // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(1) + "\n")
        f.write("scale_1 = " + str(int(np.round((s0 * (2 ** 15))).astype(np.int32))) + "\n")
        f.write("scale_2 = " + str(int(np.round((s1 * (2 ** 15))).astype(np.int32))) + "\n")
        f.write("scale_3 = " + str(int((np.round(((1 / s2) * (2 ** 15)))).astype(np.int32))) + "\n")
        f.write("zero_1 = " + str(z0) + "\n")
        f.write("zero_2 = " + str(z1) + "\n")
        f.write("start = " + str(2) + "\n")


def cat_param(path, img, touch_result, s0, s1, s2, z0, z1):
    img = img[0]
    img_c, img_h, img_w = img.shape
    touch_result = touch_result[0]
    touch_c, touch_h, touch_w = touch_result.shape
    with open(path, 'a') as f:
        f.write("type = " + str(8) + "\n")
        f.write("stride = " + str(0) + "\n")
        f.write("in_col_channel_num = " + str(img_w * img_c) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_cin_num = " + str(img_c // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(1) + "\n")
        f.write("scale_1 = " + str(int(np.round((s0 * (2 ** 15))).astype(np.int32))) + "\n")
        f.write("scale_2 = " + str(int(np.round((s1 * (2 ** 15))).astype(np.int32))) + "\n")
        f.write("scale_3 = " + str(int((np.round(((1 / s2) * (2 ** 15)))).astype(np.int32))) + "\n")
        f.write("zero_1 = " + str(z0) + "\n")
        f.write("zero_2 = " + str(z1) + "\n")
        f.write("start = " + str(2) + "\n")


def max_addr(path, s_addr_0, m_addr):
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    with open(path, 'w') as f:
        f.write("s_addr_0 = " + str(s_addr_0) + "\n")
        f.write("m_addr = " + str(m_addr) + "\n")


def max_param(path, img, touch_result):
    img = img[0]
    img_c, img_h, img_w = img.shape
    touch_result = touch_result[0]
    touch_c, touch_h, touch_w = touch_result.shape
    with open(path, 'a') as f:
        f.write("type = " + str(16) + "\n")
        f.write("stride = " + str(0) + "\n")
        f.write("in_col_channel_num = " + str(img_w * img_c) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("col_num = " + str(img_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_cin_num = " + str(img_c // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(touch_c // cha_par_in) + "\n")
        f.write("start = " + str(4) + "\n")


def up_addr(path, s_addr_0, m_addr):
    dir_path = os.path.dirname(path)
    # 如果目录不存在就创建（支持多级目录）
    os.makedirs(dir_path, exist_ok=True)

    with open(path, 'w') as f:
        f.write("s_addr_0 = " + str(s_addr_0) + "\n")
        f.write("m_addr = " + str(m_addr) + "\n")


def up_param(path, img, touch_result):
    img = img[0]
    img_c, img_h, img_w = img.shape
    touch_result = touch_result[0]
    touch_c, touch_h, touch_w = touch_result.shape
    with open(path, 'a') as f:
        f.write("type = " + str(32) + "\n")
        f.write("stride = " + str(0) + "\n")
        f.write("in_col_channel_num = " + str(img_w * img_c) + "\n")
        f.write("out_col_channel_num = " + str(touch_c * touch_w) + "\n")
        f.write("row_num = " + str(img_h) + "\n")
        f.write("calculate_cin_num = " + str(img_c // cha_par_in) + "\n")
        f.write("calculate_cout_num = " + str(1) + "\n")
        f.write("start = " + str(8) + "\n")


def txt2bin(txt_path, bin_path):
    print(txt_path)
    print(bin_path)
    with open(txt_path, 'r') as txt_file:
        content = txt_file.readlines()
    with open(bin_path, 'wb') as bin_file:
        for s in content:
            s = s.replace('\n', '').replace('\r', '')
            pairs = [s[i:i + 2] for i in range(0, len(s), 2)]
            # print(pairs)
            # 不翻转
            # 重新拼成一个字符串
            joined_s = ''.join(pairs)
            # print(joined_s)
            joined_s = bytes.fromhex(joined_s)
            # print("1")
            bin_file.write(joined_s)

            # # 按组进行翻转
            # reversed_pairs = pairs[::-1]
            # # 重新拼成一个字符串
            # reversed_s = ''.join(reversed_pairs)
            # reversed_s = bytes.fromhex(reversed_s)
            # bin_file.write(reversed_s)
    print("end")
    # print(bin_path)