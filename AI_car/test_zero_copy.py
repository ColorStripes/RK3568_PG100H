# -*- coding: utf-8 -*-
"""
小车障碍物检测与自动启停系统
- YOLO 实时检测障碍物
- 检测到障碍物 → GPIO 低电平（停止）
- 无障碍物 → GPIO 高电平（前进）
"""
import sys
import time
import ctypes
import os

PATH_CV2 = '/userdata/linaro_workspace/lib'
PATH_RKNN = '/home/linaro/.local/lib/python3.11/site-packages'

if PATH_CV2 not in sys.path:
    sys.path.insert(0, PATH_CV2)
if PATH_RKNN not in sys.path:
    sys.path.insert(0, PATH_RKNN)
import cv2
import numpy as np
from rknnlite.api import RKNNLite
import threading

# ==========================================
# 静态常量
# ==========================================
CONF_THRESH = 0.8
LOGIT_THRESH = -np.log(1 / CONF_THRESH - 1)
NMS_THRESH = 0.45

CLEAR_FRAME_COUNT = 3

ANCHORS = [
    [[4, 5],   [8, 10],   [13, 16]],
    [[23, 29], [43, 55],  [73, 105]],
    [[146, 217], [231, 300], [335, 433]]
]

YOLO_SIZE = 640 * 640 * 3
HD_SIZE = 1280 * 720 * 3

# ==========================================
# 全局共享状态
# ==========================================
shared_state = {
    'frame_for_ai': None,
    'ai_ready': False,
    'latest_results': []
}
state_lock = threading.Lock()
exit_event = threading.Event()

render_state = {
    'hd_img': None,
    'current_results': [],
    'base_addr': 0
}
render_lock = threading.Lock()
render_event = threading.Event()


# ==========================================
# 目标框平滑器（仅坐标，无文字追踪）
# ==========================================
class ObstacleSmoother:
    def __init__(self, alpha=0.7, iou_thresh=0.4):
        self.alpha = alpha
        self.iou_thresh = iou_thresh
        self.tracked_boxes = []

    def update(self, new_boxes):
        updated_tracks = []
        for new_box in new_boxes:
            best_iou = 0
            best_idx = -1

            for i, track in enumerate(self.tracked_boxes):
                ixA = max(new_box['x1'], track['x1'])
                iyA = max(new_box['y1'], track['y1'])
                ixB = min(new_box['x2'], track['x2'])
                iyB = min(new_box['y2'], track['y2'])
                inter = max(0, ixB - ixA) * max(0, iyB - iyA)

                area_a = (new_box['x2'] - new_box['x1']) * (new_box['y2'] - new_box['y1'])
                area_b = (track['x2'] - track['x1']) * (track['y2'] - track['y1'])
                iou = inter / float(area_a + area_b - inter + 1e-5)

                if iou > best_iou:
                    best_iou = iou
                    best_idx = i

            if best_iou > self.iou_thresh and best_idx >= 0:
                track = self.tracked_boxes[best_idx]
                smooth_box = {
                    'x1': int(self.alpha * track['x1'] + (1 - self.alpha) * new_box['x1']),
                    'y1': int(self.alpha * track['y1'] + (1 - self.alpha) * new_box['y1']),
                    'x2': int(self.alpha * track['x2'] + (1 - self.alpha) * new_box['x2']),
                    'y2': int(self.alpha * track['y2'] + (1 - self.alpha) * new_box['y2']),
                }
                updated_tracks.append(smooth_box)
                self.tracked_boxes.pop(best_idx)
            else:
                updated_tracks.append(new_box)

        self.tracked_boxes = updated_tracks
        return updated_tracks


# ==========================================
# YOLO 解码（动态通道数）
# ==========================================
def decode_yolo_fast(outputs, img_w, img_h):
    boxes, scores = [], []
    for i, out in enumerate(outputs):
        out = np.squeeze(out)
        total_ch, grid_h, grid_w = out.shape
        num_anchors = 3
        num_channels = total_ch // num_anchors

        stride = 640 // grid_h
        out = out.reshape(num_anchors, num_channels, grid_h, grid_w)
        conf_raw = out[:, 4, :, :]

        a_idx, y_idx, x_idx = np.where(conf_raw > LOGIT_THRESH)
        if len(a_idx) == 0:
            continue

        valid_data = out[a_idx, :, y_idx, x_idx]
        conf = 1 / (1 + np.exp(-valid_data[:, 4]))

        anchors = np.array(ANCHORS[i])[a_idx]
        grid_xy = np.stack([x_idx, y_idx], axis=-1)

        xy = (1 / (1 + np.exp(-valid_data[:, 0:2])) * 2.0 - 0.5 + grid_xy) * stride
        wh = (1 / (1 + np.exp(-valid_data[:, 2:4])) * 2.0) ** 2 * anchors

        x_min = (xy[:, 0] - wh[:, 0] / 2) / 640.0 * img_w
        y_min = (xy[:, 1] - wh[:, 1] / 2) / 640.0 * img_h
        w_real = wh[:, 0] / 640.0 * img_w
        h_real = wh[:, 1] / 640.0 * img_h

        batch_boxes = np.column_stack([x_min, y_min, w_real, h_real]).astype(np.int32).tolist()
        batch_scores = conf.tolist()

        boxes.extend(batch_boxes)
        scores.extend(batch_scores)

    return boxes, scores


# ==========================================
# 后台 AI 推理线程
# ==========================================
def ai_worker_thread(rknn_det):
    smoother = ObstacleSmoother(alpha=0.7)

    while not exit_event.is_set():
        yolo_img = None
        with state_lock:
            if shared_state['ai_ready']:
                yolo_img = shared_state['frame_for_ai']['yolo']
                shared_state['ai_ready'] = False

        if yolo_img is None:
            time.sleep(0.001)
            continue

        outputs = rknn_det.inference(inputs=[yolo_img])
        new_results = []

        if outputs is not None:
            boxes_list, scores_list = decode_yolo_fast(outputs, 1280, 720)
            if len(boxes_list) > 0:
                indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, CONF_THRESH, NMS_THRESH)

                if len(indices) > 0:
                    for idx in np.array(indices).flatten():
                        b = boxes_list[idx]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        new_results.append({
                            'x1': max(0, int(x)),
                            'y1': max(0, int(y)),
                            'x2': min(1280, int(x + w)),
                            'y2': min(720, int(y + h)),
                        })

        smoothed_results = smoother.update(new_results)

        with state_lock:
            shared_state['latest_results'] = smoothed_results


# ==========================================
# 独立渲染投屏线程
# ==========================================
def render_worker_thread(hw_lib):
    while not exit_event.is_set():
        if render_event.wait(timeout=0.1):
            render_event.clear()

            with render_lock:
                if render_state['hd_img'] is None:
                    continue
                img_hd = render_state['hd_img']
                current_results = render_state['current_results']
                base_addr = render_state['base_addr']

            for res in current_results:
                x1, y1, x2, y2 = res['x1'], res['y1'], res['x2'], res['y2']
                cv2.rectangle(img_hd, (x1, y1), (x2, y2), (0, 0, 255), 3)

                label_y = max(20, y1 - 10)
                cv2.putText(img_hd, "OBSTACLE", (x1, label_y),
                            cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2)

            hd_ptr = base_addr + YOLO_SIZE
            hw_lib.sync_to_screen(ctypes.c_void_p(hd_ptr))


# ==========================================
# 主控制线程
# ==========================================
def main():
    hw_lib = ctypes.CDLL('./libdma_rga.so')
    hw_lib.fetch_next_frame.restype = ctypes.POINTER(ctypes.c_uint8)
    hw_lib.sync_to_screen.argtypes = [ctypes.c_void_p]
    if hw_lib.init_hardware_pipeline() != 0:
        print("硬件初始化失败！")
        return

    MODEL_PATH = '/home/linaro/workspace/rknn/best.rknn'
    if not os.path.exists(MODEL_PATH):
        print(f"模型文件不存在: {MODEL_PATH}")
        return

    rknn_det = RKNNLite()
    if rknn_det.load_rknn(MODEL_PATH) != 0:
        print("模型加载失败！")
        return
    rknn_det.init_runtime()
    print("障碍物检测模型加载成功。")

    ai_thread = threading.Thread(target=ai_worker_thread, args=(rknn_det,), daemon=True)
    ai_thread.start()

    render_thread = threading.Thread(target=render_worker_thread, args=(hw_lib,), daemon=True)
    render_thread.start()

    hw_lib.gpio(1)
    print("小车初始状态: 前进 (GPIO HIGH)")

    frame_count = 0
    stop_frame_count = 0
    was_stopped = False

    try:
        while True:
            t0 = time.perf_counter()

            c_ptr = hw_lib.fetch_next_frame()
            if not c_ptr:
                continue

            base_addr = ctypes.addressof(c_ptr.contents)
            yolo_buffer = (ctypes.c_uint8 * YOLO_SIZE).from_address(base_addr)
            hd_buffer = (ctypes.c_uint8 * HD_SIZE).from_address(base_addr + YOLO_SIZE)

            img_yolo = np.ndarray(buffer=yolo_buffer, dtype=np.uint8, shape=(640, 640, 3))
            img_hd = np.ndarray(buffer=hd_buffer, dtype=np.uint8, shape=(720, 1280, 3))

            current_results = []

            with state_lock:
                shared_state['frame_for_ai'] = {'yolo': img_yolo}
                shared_state['ai_ready'] = True
                current_results = shared_state['latest_results']

            obstacle_detected = len(current_results) > 0

            # ── GPIO 控制（带滞后滤波） ──
            if obstacle_detected:
                stop_frame_count = 0
                hw_lib.gpio(0)
                if not was_stopped:
                    print("\n[!!] 障碍物检测到 → STOP")
                    was_stopped = True
            else:
                stop_frame_count += 1
                if stop_frame_count >= CLEAR_FRAME_COUNT:
                    hw_lib.gpio(1)
                    if was_stopped:
                        print("\n[OK] 障碍物消失 → GO")
                        was_stopped = False

            with render_lock:
                render_state['hd_img'] = img_hd
                render_state['current_results'] = current_results
                render_state['base_addr'] = base_addr
            render_event.set()

            t1 = time.perf_counter()
            frame_count += 1

            if frame_count % 30 == 0:
                fps = 1.0 / (t1 - t0)
                status = "STOP" if was_stopped else "GO"
                print(f"\r[{frame_count:5d}帧] {fps:5.1f} FPS | 状态: {status}   ",
                      end='', flush=True)

    except KeyboardInterrupt:
        print("\n收到终端退出信号")
        exit_event.set()
        ai_thread.join(timeout=2.0)
        render_thread.join(timeout=2.0)

    finally:
        print("正在释放资源...")
        hw_lib.gpio(0)
        hw_lib.cleanup_hardware()
        rknn_det.release()
        print("系统已安全退出。")


if __name__ == '__main__':
    main()