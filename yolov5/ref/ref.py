import numpy as np

# img_path = r"E:\yolov5-v6.1-pytorch-master\npy\img.int.npy"
# weight_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.weight.int.npy"
# img_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy/quant.scale.npy"
# weight_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy/backbone.conv1.conv.weight.scale.npy"
# img_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy/quant.zero_point.npy"
# weight_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy/backbone.conv1.conv.weight.zero_point.npy"
# bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.bias.npy"
#
# s3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.scale.npy"
# z3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.zero_point.npy"

img_path = r"E:\yolov5-v6.1-pytorch-master\npy\img_conv1.int.npy"
weight_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.weight.int.npy"
img_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.scale.npy"
weight_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.weight.scale.npy"
img_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv1.conv.zero_point.npy"
weight_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.weight.zero_point.npy"
bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.bias.npy"

s3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.scale.npy"
z3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv2.conv.zero_point.npy"

# img_path = r"E:\yolov5-v6.1-pytorch-master\npy\img_conv15.int.npy"
# torch_path = r"E:\yolov5-v6.1-pytorch-master\npy\img_conv16.int.npy"
# weight_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.weight.int.npy"
# img_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv15.conv.scale.npy"
# weight_scale_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.weight.scale.npy"
# img_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv15.conv.zero_point.npy"
# weight_zero_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.weight.zero_point.npy"
# bias_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.bias.npy"
#
# s3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.scale.npy"
# z3_path = r"E:\yolov5-v6.1-pytorch-master\npy\backbone.conv16.conv.zero_point.npy"

img = np.load(img_path)
weight = np.load(weight_path)
img_scale = np.load(img_scale_path)
weight_scale = np.load(weight_scale_path)
img_zero = np.load(img_zero_path)
weight_zero = np.load(weight_zero_path)
bias = np.load(bias_path)

img_f = img_scale * (img - img_zero)
weight_f = weight_scale * (weight - weight_zero)

s1 = np.load(img_scale_path)
s2 = np.load(weight_scale_path)
s3 = np.load(s3_path)
z1 = np.load(img_zero_path)
z2 = np.load(weight_zero_path)
z3 = np.load(z3_path)


# weight_f = weight


def conv33_float(img, weight, bias, cout, cin, h, w):
    img = img[0]
    img = np.pad(img, pad_width=((0, 0), (1, 1), (1, 1)), mode='constant', constant_values=0)

    # for i in range(cout):
    #     for j in range(cin):
    d = np.zeros((cin, 3, 3))
    for j in range(cin):
        for k1 in range(3):
            for k2 in range(3):
                print(img[j][k1][k2])
                d[j][k1][k2] = img[j][k1][k2] * weight[1][j][k1][k2]
        print("xxx" * 50)
    da = d.sum()
    da1 = d.sum() + bias[1]
    daa = (d.sum() + bias[1]) / s3 + z3
    print("xxx")


def conv33_int(img, weight, bias, cout, cin, h, w, s1, s2, s3, z1, z2, z3, stride=1):
    img = img[0]
    # img = img - z1
    img = np.pad(img, pad_width=((0, 0), (1, 1), (1, 1)), mode='constant', constant_values=z1)
    # img = np.pad(img, pad_width=((0, 0), (1, 1), (1, 1)), mode='constant', constant_values=0)
    c, h, w = img.shape
    h = 8
    da_result = np.zeros((h - 2, w - 2, cout))
    zz_result = np.zeros((h - 2, w - 2, cout))

    for i in range(1, h - 1):
        print(i)
        for j in range(1, w - 1):
            for co in range(cout):
                # if j == w - 2:
                #     print("xxx")
                d = np.zeros(cin)
                z = np.zeros(cin)
                # if j == 157*2:
                #     print("xxx")
                for ci in range(cin):
                    # if co == 26:
                    #     print(img[ci][i - 1][j - 1], img[ci][i - 1][j], img[ci][i - 1][j + 1])
                    #     print(img[ci][i][j - 1], img[ci][i][j], img[ci][i][j + 1])
                    #     print(img[ci][i + 1][j - 1], img[ci][i + 1][j], img[ci][i + 1][j + 1])
                    #     print("xxx")
                    #     print(weight[co][ci][0][0], weight[co][ci][0][1], weight[co][ci][0][2])
                    #     print(weight[co][ci][1][0], weight[co][ci][1][1], weight[co][ci][1][2])
                    #     print(weight[co][ci][2][0], weight[co][ci][2][1], weight[co][ci][2][2])
                    #     print("zzz")
                    #     print(img[ci][i - 1][j - 1] * weight[co][ci][0][0], img[ci][i - 1][j] * weight[co][ci][0][1],
                    #           img[ci][i - 1][j + 1] * weight[co][ci][0][2])
                    #     print(img[ci][i][j - 1] * weight[co][ci][1][0], img[ci][i][j] * weight[co][ci][1][1],
                    #           img[ci][i][j + 1] * weight[co][ci][1][2])
                    #     print(img[ci][i + 1][j - 1] * weight[co][ci][2][0], img[ci][i + 1][j] * weight[co][ci][2][1],
                    #           img[ci][i + 1][j + 1] * weight[co][ci][2][2])
                    d[ci] = img[ci][i - 1][j - 1] * weight[co][ci][0][0] + img[ci][i - 1][j] * weight[co][ci][0][1] + \
                            img[ci][i - 1][j + 1] * weight[co][ci][0][2] + img[ci][i][j - 1] * weight[co][ci][1][0] + \
                            img[ci][i][j] * weight[co][ci][1][1] + img[ci][i][j + 1] * weight[co][ci][1][2] + \
                            img[ci][i + 1][j - 1] * weight[co][ci][2][0] + img[ci][i + 1][j] * weight[co][ci][2][1] + \
                            img[ci][i + 1][j + 1] * weight[co][ci][2][2]
                    z[ci] = z1 * weight[co][ci][0][0] + z1 * weight[co][ci][0][1] + \
                            z1 * weight[co][ci][0][2] + z1 * weight[co][ci][1][0] + \
                            z1 * weight[co][ci][1][1] + z1 * weight[co][ci][1][2] + \
                            z1 * weight[co][ci][2][0] + z1 * weight[co][ci][2][1] + \
                            z1 * weight[co][ci][2][2]
                da = d.sum()
                zz = z.sum()
                da_result[i - 1][j - 1][co] = da
                zz_result[i - 1][j - 1][co] = zz

    bias_t = np.expand_dims(np.expand_dims(bias, 0).repeat(w - 2, axis=0), 0).repeat(h - 2, axis=0)
    a = (s1 * s2 / s3) * (-zz_result) + bias_t / s3
    b = da_result * (s1 * s2 / s3)
    temp_a = da_result * (s1 * s2 / s3) + (s1 * s2 / s3) * (-zz_result) + bias_t / s3
    temp_a[temp_a < 0] = 0
    temp_c = temp_a + z3
    temp_d = np.round(temp_c)
    h, w, c = temp_d.shape
    with open("cv_result.txt", 'w') as f:
        for i in range(h):
            for j in range(w):
                for k in range(c):
                    if stride == 2:
                        if i % 2 != 0 or j % 2 != 0:
                            continue
                        if i == h - 1 and j == w - 1 and k == c - 1:
                            f.write(str(int(temp_d[i][j][k])))
                        else:
                            f.write(str(int(temp_d[i][j][k])) + "\n")
    print("xxx")


def img_to_txt(img_path, img):
    img = img[0]
    c, h, w = img.shape
    with open(img_path, 'w') as f:
        for i in range(h):
            for j in range(w):
                for k in range(0, c, 16):
                    s1 = 0
                    s2 = 0
                    s3 = 0
                    s4 = 0
                    for z in range(4):
                        s1 |= (img[k + z][i][j] << (z * 8))
                    for z in range(4):
                        s2 |= (img[k + z + 4][i][j] << (z * 8))
                    for z in range(4):
                        s3 |= (img[k + z + 8][i][j] << (z * 8))
                    for z in range(4):
                        s4 |= (img[k + z + 12][i][j] << (z * 8))
                    hex_str1 = f"{s1:08x}"
                    hex_str2 = f"{s2:08x}"
                    hex_str3 = f"{s3:08x}"
                    hex_str4 = f"{s4:08x}"
                    f.write(hex_str4 + hex_str3 + hex_str2 + hex_str1 + "\n")
                    # f.write(
                    #     str(img[k + 0][i][j]) + " " + str(img[k + 1][i][j]) + " " + str(
                    #         img[k + 2][i][j]) + " " + str(
                    #         img[k + 3][i][j]) + " " + str(img[k + 4][i][j]) + " " + str(
                    #         img[k + 5][i][j]) + " " + str(
                    #         img[k + 6][i][j]) + " " + str(img[k + 7][i][j]) + " " + str(
                    #         img[k + 8][i][j]) + " " + str(
                    #         img[k + 9][i][j]) + " " + str(img[k + 10][i][j]) + " " + str(
                    #         img[k + 11][i][j]) + " " + str(
                    #         img[k + 12][i][j]) + " " + str(img[k + 13][i][j]) + " " + str(
                    #         img[k + 14][i][j]) + " " + str(
                    #         img[k + 15][i][j]) + "\n")


def weight_to_txt(weight_path, weight):
    co, ci, _, _ = weight.shape
    with open(weight_path, 'w') as f:
        for i in range(3):
            for j in range(3):
                for m in range(0, co, 8):
                    for k in range(0, ci, 16):
                        for n in range(8):
                            f.write(
                                str(weight[m + n][k + 0][i][j]) + " " + str(weight[m + n][k + 1][i][j]) + " " + str(
                                    weight[m + n][k + 2][i][j]) + " " + str(
                                    weight[m + n][k + 3][i][j]) + " " + str(weight[m + n][k + 4][i][j]) + " " + str(
                                    weight[m + n][k + 5][i][j]) + " " + str(
                                    weight[m + n][k + 6][i][j]) + " " + str(weight[m + n][k + 7][i][j]) + " " + str(
                                    weight[m + n][k + 8][i][j]) + " " + str(
                                    weight[m + n][k + 9][i][j]) + " " + str(weight[m + n][k + 10][i][j]) + " " + str(
                                    weight[m + n][k + 11][i][j]) + " " + str(
                                    weight[m + n][k + 12][i][j]) + " " + str(weight[m + n][k + 13][i][j]) + " " + str(
                                    weight[m + n][k + 14][i][j]) + " " + str(
                                    weight[m + n][k + 15][i][j]) + "\n")


def bias_to_txt(bias_path, weight, s1, s2, s3, z1, z2, z3, bias):
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
        bias_1[i] = temp.sum()
    bias_2 = bias / s3 - (s1 * s2 / s3) * bias_1
    k = bias_2 * (2 ** 16)
    bias_3 = np.round((bias_2 * (2 ** 16))).astype(np.int32)
    with open(bias_path, 'w') as f:
        for i in range(co):
            f.write(str(int(bias_3[i])) + "\n")


def scale_zero_to_txt(s1, s2, s3, z3):
    print(np.round(((s1 * s2 / s3) * (2 ** 16))).astype(np.int32))
    print(z3)


# conv33_float(img_f, weight_f, bias, 32, 16, 320, 320)
conv33_int(img, weight, bias, 32, 16, 320, 320, s1, s2, s3, z1, z2, z3, 1)
# img_to_txt("conv_in_data_m.txt", img)
# weight_to_txt("weight.txt", weight)
# bias_to_txt("bias.txt", weight, s1, s2, s3, z1, z2, z3, bias)
# scale_zero_to_txt(s1, s2, s3, z3)
print("xxx")
