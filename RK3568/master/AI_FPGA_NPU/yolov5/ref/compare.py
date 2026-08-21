import numpy as np


def fpga_result_compare(torch_path, dut_path, out_path):
    h, w, c = 80, 80, 32
    torch_data = []
    dut_data = []

    with open(torch_path, 'r') as f:
        data = f.read().splitlines()
        for i, k in enumerate(data):
            torch_data.append(int(k))

    with open(dut_path, 'r') as f:
        data = f.read().splitlines()
        for i, k in enumerate(data):
            dut_data.append(int(k))

    # test = np.array(torch_data).reshape((h, w, c))

    err_index = []
    err = np.zeros(len(dut_data))
    c = -1
    h = 0
    w = 0
    count = 0
    with open(out_path, "w") as f:
        for i in range(len(dut_data)):

            c = c + 1

            if c == 16:
                c = 0
                w = w + 1

            if w == 160:
                w = 0
                h = h + 1

            err[i] = dut_data[i] - torch_data[i]
            # if err[i] != 0:
            if abs(err[i]) > 0:
                count = count + 1
                line = "dut_data:{0}, torch_data:{1}, c:{2}, w:{3}, h:{4}, i+1:{5}, err:{6} \n".format(dut_data[i],
                                                                                                       torch_data[
                                                                                                           i], c, w,
                                                                                                       h,
                                                                                                       i + 1,
                                                                                                       err[i])
                f.write(line)
                # print(line, end="")
            # print(dut_data[i], torch_data[i], i)

            # if i == 5040:
            #     print(dut_data[i], torch_data[i])
            # err[i] = dut_data[i] - torch_data[i]
            # if dut_data[i] - torch_data[i] != 0:
            #     print(dut_data[i], torch_data[i], c, w, h, i)

        rate = count / len(dut_data) * 100
        qline = "err.min:{0}, err.max:{1}, rate:{2}% \n".format(err.min(), err.max(), rate)
        f.write(qline)

    print(err.min())
    print(err.max())
    print("正负超过1的误差占比 " + str(rate) + " %")
    if rate != 0.0:
        return 1
    else:
        return 0


# with open(r"F:/python/yolov5/ref/txt/error.txt", "w") as f:
#     for i in range(1, 58):
#         torch_path = r"F:/python/yolov5/ref/txt/conv" + str(i) + r"/conv" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/conv" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/conv" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error" + " " + str(i) + "\n")
#             print("error conv" + str(i))
#
#     for i in range(1, 4):
#         torch_path = r"F:/python/yolov5/ref/txt/out" + str(i) + r"/out" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/out" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/out" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error out" + " " + str(i) + "\n")
#             print("error out" + str(i))
#
#     for i in range(0, 7):
#         torch_path = r"F:/python/yolov5/ref/txt/add" + str(i) + r"/add" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/add" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/add" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error add" + " " + str(i) + "\n")
#             print("error add" + str(i))
#
#     for i in range(0, 4):
#         torch_path = r"F:/python/yolov5/ref/txt/cat" + str(i) + r"/cat" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/cat" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/cat" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error cat" + " " + str(i) + "\n")
#             print("error cat" + str(i))
#
#     for i in range(1, 4):
#         torch_path = r"F:/python/yolov5/ref/txt/cat4_" + str(i) + r"/cat4_" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/cat4_" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/cat4_" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error cat4_" + " " + str(i) + "\n")
#             print("error cat4_" + str(i))
#
#     for i in range(5, 13):
#         torch_path = r"F:/python/yolov5/ref/txt/cat" + str(i) + r"/cat" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/cat" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/cat" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error cat" + " " + str(i) + "\n")
#             print("error cat" + str(i))
#
#     for i in range(0, 2):
#         torch_path = r"F:/python/yolov5/ref/txt/up" + str(i) + r"/up" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/up" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/up" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error up" + " " + str(i) + "\n")
#             print("error up" + str(i))
#
#     for i in range(1, 4):
#         torch_path = r"F:/python/yolov5/ref/txt/max" + str(i) + r"/max" + str(i) + r"_torch.txt"
#         dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/max" + str(i) + r"_result.txt"
#         out_path = r"F:/python/yolov5/ref/txt/max" + str(i) + r"/output_dif.txt"
#
#         if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#             f.write("error max" + " " + str(i) + "\n")
#             print("error max" + str(i))
#
#     torch_path = r"F:/python/yolov5/ref/txt/focus/focus_torch.txt"
#     dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/focus_result.txt"
#     out_path = r"F:/python/yolov5/ref/txt/focus/output_dif.txt"
#
#     if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#         f.write("error focus" + " " + str(i) + "\n")
#         print("error focus" + str(i))


i = 33
torch_path = r"F:/python/yolov5/ref/txt/conv" + str(i) + r"/conv" + str(i) + r"_torch.txt"
dut_path = r"F:/python/yolov5/ref/txt/conv" + str(i) + r"/dut" + str(i) + r"_my.txt"
# dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/conv" + str(i) + r"_result.txt"
out_path = r"F:/python/yolov5/ref/txt/conv" + str(i) + r"/output_dif.txt"
if fpga_result_compare(torch_path, dut_path, out_path) == 1:
    print("error" + str(i))

# i = 2
# torch_path = r"F:/python/yolov5/ref/txt/out" + str(i) + r"/out" + str(i) + r"_torch.txt"
# # dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/out" + str(i) + r"_result.txt"
# dut_path = r"F:/python/yolov5/ref/txt/out" + str(i) + r"/dutout" + str(i) + r"_my.txt"
# out_path = r"F:/python/yolov5/ref/txt/out" + str(i) + r"/output_torch_dif.txt"
# fpga_result_compare(torch_path, dut_path, out_path)


# i = 1
# torch_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/conv2_result.txt"
# dut_path = r"F:/VSstudio/Yolov5/Yolov5/outdata san/conv2_result.txt"
# out_path = r"F:/VSstudio/Yolov5/Yolov5/outdata/diff_conv2.txt"
# fpga_result_compare(torch_path, dut_path, out_path)


# index = [
#     0, 1, 2, 3, 5, 6, 61, 4, 68, 7, 8, 9, 11, 12, 62, 13, 14, 63, 10, 69, 15, 16, 17, 19,
#     20, 64, 21, 22, 65, 23, 24, 66, 18, 70, 25, 26, 27, 29, 30, 67, 28, 71, 31, 32, 85, 86, 87, 72,
#     73, 74, 33, 34, 83, 75, 35, 37, 38, 36, 76, 39, 40, 84, 77, 41, 43, 44, 42, 78, 45, 60, 46, 79,
#     47, 49, 50, 48, 80, 51, 59, 52, 81, 53, 55, 56, 54, 82, 57, 58
# ]
#
# para_index = [
#     1, 5, 4, 7, 11, 13, 10, 19,
#     21, 23, 18, 29, 28, 31, 33,
#     37, 36, 39, 43, 42, 46,
#     49, 48, 52, 55, 54, 57
# ]
#
# # 假设变量 n 已经定义
# n = 0  # 示例值
#
# # torch_base_path = "F:/python/yolov5/ref/txt/"
# torch_base_path = "F:/VSstudio/Yolov5/Yolov5/outdata1/"
# dut_base_path = "F:/VSstudio/Yolov5/Yolov5/outdata/"
# out_base_path = "F:/VSstudio/Yolov5/Yolov5/outdata_error/"
#
# for n in index:
#     found_n = False
#     for m in para_index:
#         if n == m:
#             found_n = True
#             break
#
#     if found_n:
#         continue
#
#     if n == 0:
#         torch_path = f"{torch_base_path}focus_result.txt"
#         # torch_path = f"{torch_base_path}focus/focus_torch.txt"
#         dut_path = f"{dut_base_path}focus_result.txt"
#         out_path = f"{dut_base_path}focus_error.txt"
#     elif 0 < n < 58:
#         torch_path = f"{torch_base_path}conv{n}_result.txt"
#         # torch_path = f"{torch_base_path}conv{n}/conv{n}_torch.txt"
#         dut_path = f"{dut_base_path}conv{n}_result.txt"
#         out_path = f"{dut_base_path}conv{n}_error.txt"
#     elif 58 <= n <= 60:
#         torch_path = f"{torch_base_path}out{n - 57}_result.txt"
#         # torch_path = f"{torch_base_path}out{n - 57}/out{n - 57}_torch.txt"
#         dut_path = f"{dut_base_path}out{n - 57}_result.txt"
#         out_path = f"{dut_base_path}out{n - 57}_error.txt"
#     elif 61 <= n <= 67:
#         torch_path = f"{torch_base_path}add{n - 61}_result.txt"
#         # torch_path = f"{torch_base_path}add{n - 61}/add{n - 61}_torch.txt"
#         dut_path = f"{dut_base_path}add{n - 61}_result.txt"
#         out_path = f"{dut_base_path}add{n - 61}_error.txt"
#     elif 68 <= n <= 71:
#         torch_path = f"{torch_base_path}cat{n - 68}_result.txt"
#         # torch_path = f"{torch_base_path}cat{n - 68}/cat{n - 68}_torch.txt"
#         dut_path = f"{dut_base_path}cat{n - 68}_result.txt"
#         out_path = f"{dut_base_path}cat{n - 68}_error.txt"
#     elif 72 <= n <= 74:
#         torch_path = f"{torch_base_path}cat4_{n - 71}_result.txt"
#         # torch_path = f"{torch_base_path}cat4_{n - 71}/cat4_{n - 71}_torch.txt"
#         dut_path = f"{dut_base_path}cat4_{n - 71}_result.txt"
#         out_path = f"{dut_base_path}cat4_{n - 71}_error.txt"
#     elif 75 <= n <= 82:
#         torch_path = f"{torch_base_path}cat{n - 70}_result.txt"
#         # torch_path = f"{torch_base_path}cat{n - 70}/cat{n - 70}_torch.txt"
#         dut_path = f"{dut_base_path}cat{n - 70}_result.txt"
#         out_path = f"{dut_base_path}cat{n - 70}_error.txt"
#     elif 83 <= n <= 84:
#         torch_path = f"{torch_base_path}up{n - 83}_result.txt"
#         # torch_path = f"{torch_base_path}up{n - 83}/up{n - 83}_torch.txt"
#         dut_path = f"{dut_base_path}up{n - 83}_result.txt"
#         out_path = f"{dut_base_path}up{n - 83}_error.txt"
#     elif 85 <= n <= 87:
#         torch_path = f"{torch_base_path}max{n - 84}_result.txt"
#         # torch_path = f"{torch_base_path}max{n - 84}/max{n - 84}_torch.txt"
#         dut_path = f"{dut_base_path}max{n - 84}_result.txt"
#         out_path = f"{dut_base_path}max{n - 84}_error.txt"
#     else:
#         torch_path = None  # 或者处理 n 超出范围的情况
#         dut_path = None
#         out_path = None
#
#     print(torch_path)
#     print(dut_path)
#     fpga_result_compare(torch_path, dut_path, out_path)
#
#     if fpga_result_compare(torch_path, dut_path, out_path) == 1:
#         print("error")
