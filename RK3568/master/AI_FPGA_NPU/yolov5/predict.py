#-----------------------------------------------------------------------#
#   车牌检测预测脚本（浮点模型 yolo.py）
#-----------------------------------------------------------------------#
import os
import subprocess
import time

import cv2
import numpy as np
from PIL import Image

from yolo import YOLO
from utils.paths import DATA_ROOT, ROOT


def show_result(image, save_path):
    """SSH 下尽量弹出图片窗口；无图形界面时提示如何查看。"""
    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    image.save(save_path, quality=95)
    print(f"预测完成，结果已保存: {save_path}")

    display = os.environ.get("DISPLAY")
    if display:
        try:
            win_name = "Plate Detection (Float)"
            bgr = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            cv2.namedWindow(win_name, cv2.WINDOW_NORMAL)
            cv2.imshow(win_name, bgr)
            print("图片已弹出，按任意键或点击窗口关闭按钮退出...")
            while True:
                key = cv2.waitKey(100)
                if key != -1:
                    break
                try:
                    if cv2.getWindowProperty(win_name, cv2.WND_PROP_VISIBLE) < 1:
                        break
                except cv2.error:
                    break
            cv2.destroyAllWindows()
            return
        except cv2.error:
            pass

        try:
            import matplotlib
            matplotlib.use("TkAgg")
            import matplotlib.pyplot as plt
            fig = plt.figure("Plate Detection (Float)", figsize=(14, 8))
            plt.imshow(image)
            plt.axis("off")
            plt.tight_layout()
            print("图片已弹出，关闭窗口后程序退出...")
            plt.show(block=True)
            plt.close(fig)
            return
        except Exception:
            pass

        try:
            subprocess.Popen(["xdg-open", save_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("已用系统查看器打开图片（程序已结束）。")
            return
        except Exception:
            pass

    print("\n当前无图形界面 (DISPLAY 未设置)，无法弹窗。")
    print("可选方案:")
    print("  1) SSH 时加 X11 转发:  ssh -X user@host")
    print("  2) 在 Cursor/VSCode 左侧打开文件:", save_path)
    print("  3) 下载到本地查看:", save_path)


if __name__ == "__main__":
    yolo = YOLO()

    mode = "predict"

    # predict_image_path = os.path.join(DATA_ROOT, "CRPD_double/test/images/64_1240.jpg")
    predict_image_path = os.path.join(ROOT, "5.jpg") 
    predict_save_path  = os.path.join(ROOT, "plate_out/predict_result_float.jpg")

    crop  = False
    count = True

    video_path      = 0
    video_save_path = ""
    video_fps       = 25.0

    test_interval  = 100
    fps_image_path = os.path.join(DATA_ROOT, "CRPD_single/test/images/41_0002.jpg")

    dir_origin_path = os.path.join(DATA_ROOT, "CRPD_single/test/images")
    dir_save_path   = os.path.join(ROOT, "plate_out")

    heatmap_save_path = os.path.join(ROOT, "plate_out/heatmap.png")
    simplify          = True
    onnx_save_path    = os.path.join(ROOT, "model_data/yolov5n_plate.onnx")

    if mode == "predict":
        if not os.path.isfile(predict_image_path):
            raise FileNotFoundError(f"图片不存在: {predict_image_path}")
        image = Image.open(predict_image_path)
        r_image = yolo.detect_image(image, crop=crop, count=count)
        show_result(r_image, predict_save_path)

    elif mode == "video":
        capture = cv2.VideoCapture(video_path)
        if video_save_path != "":
            fourcc = cv2.VideoWriter_fourcc(*'XVID')
            size = (int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)), int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)))
            out = cv2.VideoWriter(video_save_path, fourcc, video_fps, size)

        ref, frame = capture.read()
        if not ref:
            raise ValueError("未能正确读取摄像头（视频），请注意是否正确安装摄像头（是否正确填写视频路径）。")

        fps = 0.0
        while True:
            t1 = time.time()
            ref, frame = capture.read()
            if not ref:
                break
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = Image.fromarray(np.uint8(frame))
            frame = np.array(yolo.detect_image(frame))
            frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

            fps = (fps + (1. / (time.time() - t1))) / 2
            print("fps= %.2f" % fps)
            frame = cv2.putText(frame, "fps= %.2f" % fps, (0, 40), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

            cv2.imshow("video", frame)
            c = cv2.waitKey(1) & 0xff
            if video_save_path != "":
                out.write(frame)

            if c == 27:
                capture.release()
                break

        print("Video Detection Done!")
        capture.release()
        if video_save_path != "":
            print("Save processed video to the path :" + video_save_path)
            out.release()
        cv2.destroyAllWindows()

    elif mode == "fps":
        if not os.path.isfile(fps_image_path):
            raise FileNotFoundError(f"图片不存在: {fps_image_path}")
        img = Image.open(fps_image_path)
        tact_time = yolo.get_FPS(img, test_interval)
        print(str(tact_time) + ' seconds, ' + str(1 / tact_time) + 'FPS, @batch_size 1')

    elif mode == "dir_predict":
        from tqdm import tqdm

        if not os.path.isdir(dir_origin_path):
            raise FileNotFoundError(f"目录不存在: {dir_origin_path}")
        os.makedirs(dir_save_path, exist_ok=True)

        img_names = sorted(os.listdir(dir_origin_path))
        for img_name in tqdm(img_names):
            if img_name.lower().endswith(('.bmp', '.dib', '.png', '.jpg', '.jpeg', '.pbm', '.pgm', '.ppm', '.tif', '.tiff')):
                image_path = os.path.join(dir_origin_path, img_name)
                image = Image.open(image_path)
                r_image = yolo.detect_image(image)
                save_name = os.path.splitext(img_name)[0] + ".jpg"
                r_image.save(os.path.join(dir_save_path, save_name), quality=95)

        print(f"批量预测完成，结果保存在: {dir_save_path}")

    elif mode == "heatmap":
        while True:
            img = input('Input image filename:')
            try:
                image = Image.open(img)
            except:
                print('Open Error! Try again!')
                continue
            else:
                yolo.detect_heatmap(image, heatmap_save_path)

    elif mode == "export_onnx":
        yolo.convert_to_onnx(simplify, onnx_save_path)

    else:
        raise AssertionError("Please specify the correct mode: 'predict', 'video', 'fps', 'heatmap', 'export_onnx', 'dir_predict'.")
