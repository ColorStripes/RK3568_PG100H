# -*- coding: utf-8 -*-
"""
小车主控 — 车牌实时识别 + 电机控制 + 音乐播放
线程: AI 车牌识别 / DRM 渲染
"""

import sys
import os
import time
import ctypes
import logging
import threading
import numpy as np

# 路径
PATH_CV2 = '/userdata/linaro_workspace/lib'
PATH_RKNN = '/home/linaro/.local/lib/python3.11/site-packages'
if PATH_CV2 not in sys.path:
    sys.path.insert(0, PATH_CV2)
if PATH_RKNN not in sys.path:
    sys.path.insert(0, PATH_RKNN)

import cv2
from PIL import Image, ImageDraw, ImageFont
from rknnlite.api import RKNNLite
from collections import Counter

from motor import MotorController

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("main")

# ==========================================
# 车牌识别常量
# ==========================================
CHARS = ['京', '沪', '津', '渝', '冀', '晋', '蒙', '辽', '吉', '黑',
         '苏', '浙', '皖', '闽', '赣', '鲁', '豫', '鄂', '湘', '粤',
         '桂', '琼', '川', '贵', '云', '藏', '陕', '甘', '青', '宁', '新',
         '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
         'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
         'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
         'W', 'X', 'Y', 'Z', 'I', 'O', '-',
         '使', '学', '挂', '港', '澳', '领', '临', '试', '超', '应', '警', '_']
BLANK_IDX = len(CHARS) - 1
FONT_PATH = '/home/linaro/workspace/SimHei.ttf'
CONF_THRESH = 0.4
LOGIT_THRESH = -np.log(1 / CONF_THRESH - 1)

PLATE_COLORS_BGR = {'蓝牌': (255, 0, 0), '绿牌': (0, 255, 0),
                    '黄牌': (0, 255, 255), '白牌': (255, 255, 255), '特殊牌': (255, 255, 255)}
PLATE_COLORS_RGB = {'蓝牌': (0, 0, 255), '绿牌': (0, 255, 0),
                    '黄牌': (255, 255, 0), '白牌': (255, 255, 255), '特殊牌': (255, 255, 255)}

ANCHORS = [
    [[4, 5], [8, 10], [13, 16]],
    [[23, 29], [43, 55], [73, 105]],
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
# 目标框与字符防抖平滑器
# ==========================================
class BoxSmoother:
    def __init__(self, alpha=0.7, iou_thresh=0.4, history_len=10):
        self.alpha = alpha
        self.iou_thresh = iou_thresh
        self.history_len = history_len
        self.tracked_boxes = []

    def update(self, new_boxes):
        updated_tracks = []
        for new_box in new_boxes:
            best_iou, best_idx = 0, -1
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
                    best_iou, best_idx = iou, i
            if best_iou > self.iou_thresh and best_idx >= 0:
                track = self.tracked_boxes[best_idx]
                text_history = track.get('text_history', [])
                text_history.append(new_box['text'])
                if len(text_history) > self.history_len:
                    text_history.pop(0)
                most_common_text = Counter(text_history).most_common(1)[0][0]
                smooth_box = {
                    'x1': int(self.alpha * track['x1'] + (1 - self.alpha) * new_box['x1']),
                    'y1': int(self.alpha * track['y1'] + (1 - self.alpha) * new_box['y1']),
                    'x2': int(self.alpha * track['x2'] + (1 - self.alpha) * new_box['x2']),
                    'y2': int(self.alpha * track['y2'] + (1 - self.alpha) * new_box['y2']),
                    'text': most_common_text,
                    'text_history': text_history,
                    'color_bgr': new_box['color_bgr'],
                    'color_rgb': new_box['color_rgb']
                }
                updated_tracks.append(smooth_box)
                self.tracked_boxes.pop(best_idx)
            else:
                new_box['text_history'] = [new_box['text']]
                updated_tracks.append(new_box)
        self.tracked_boxes = updated_tracks
        return updated_tracks


# ==========================================
# 车牌字符纠偏
# ==========================================
def rectify_plate_text(text):
    if not text or len(text) < 3:
        return text
    text_list = list(text)
    for i in range(2, len(text_list)):
        if text_list[i] == 'I':
            text_list[i] = '1'
        if text_list[i] == 'O':
            text_list[i] = '0'
    text = "".join(text_list)
    letter_to_digit = {'I': '1', 'L': '1', 'T': '7', 'Z': '2', 'S': '5',
                       'B': '8', 'A': '4', 'G': '6', 'E': '3', 'O': '0',
                       'Q': '0', 'D': '0', 'C': '0'}
    if text[-1] == '领':
        rectified = text[0]
        for char in text[1:-1]:
            rectified += letter_to_digit.get(char, char)
        rectified += '领'
        return rectified
    elif text[0] == '使':
        rectified = '使'
        for char in text[1:]:
            rectified += letter_to_digit.get(char, char)
        return rectified
    return text


# ==========================================
# YOLO 解码 (车牌检测)
# ==========================================
def decode_yolo_fast(outputs, img_w, img_h):
    boxes, scores = [], []
    for i, out in enumerate(outputs):
        out = np.squeeze(out)
        _, grid_h, grid_w = out.shape
        stride = 640 // grid_h
        out = out.reshape(3, 14, grid_h, grid_w)
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
        boxes.extend(np.column_stack([x_min, y_min, w_real, h_real]).astype(np.int32).tolist())
        scores.extend(conf.tolist())
    return boxes, scores


# ==========================================
# LPRNet 解码
# ==========================================
def decode_lprnet(char_logits):
    lpr_logits = np.squeeze(char_logits)
    if len(lpr_logits.shape) < 2:
        return ""
    if lpr_logits.shape[0] == 18:
        lpr_logits = lpr_logits.T
    res = []
    pre_c = BLANK_IDX
    state = 0
    PROV_IDX = set(range(0, 31))
    LETTER_IDX = set(range(40, 66))
    for t in range(lpr_logits.shape[1]):
        step_logits = lpr_logits[:, t].copy()
        if state == 0:
            mask = np.ones(len(CHARS), dtype=bool)
            mask[list(PROV_IDX) + [BLANK_IDX]] = False
            step_logits[mask] = -9999.0
        elif state == 1:
            mask = np.ones(len(CHARS), dtype=bool)
            allowed = list(LETTER_IDX) + [BLANK_IDX]
            if pre_c in PROV_IDX:
                allowed.append(pre_c)
            mask[allowed] = False
            step_logits[mask] = -9999.0
        c = int(np.argmax(step_logits))
        if c == pre_c or c == BLANK_IDX:
            if c == BLANK_IDX:
                pre_c = c
            continue
        res.append(CHARS[c])
        pre_c = c
        if state == 0 and c in PROV_IDX:
            state = 1
        elif state == 1 and c in LETTER_IDX:
            state = 2
    return "".join(res)


# ==========================================
# AI 车牌识别线程
# ==========================================
def ai_worker_thread(rknn_det, rknn_rec_b4, rknn_rec_b1):
    smoother = BoxSmoother(alpha=0.7)

    while not exit_event.is_set():
        yolo_img = None
        hd_img = None
        with state_lock:
            if shared_state['ai_ready']:
                yolo_img = shared_state['frame_for_ai']['yolo']
                hd_img = shared_state['frame_for_ai']['hd']
                shared_state['ai_ready'] = False
        if yolo_img is None:
            time.sleep(0.001)
            continue

        outputs = rknn_det.inference(inputs=[np.expand_dims(yolo_img, axis=0)])
        new_results = []

        if outputs is not None:
            boxes_list, scores_list = decode_yolo_fast(outputs, 1280, 720)
            indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, CONF_THRESH, 0.45)

            if len(indices) > 0:
                crop_imgs = []
                valid_boxes = []
                for idx in np.array(indices).flatten():
                    b = boxes_list[idx]
                    x, y, w, h = b[0], b[1], b[2], b[3]
                    pad_x, pad_y = int(w * 0.05), int(h * 0.10)
                    x1 = max(0, int(x - pad_x))
                    y1 = max(0, int(y - pad_y))
                    x2 = min(1280, int(x + w + pad_x))
                    y2 = min(720, int(y + h + pad_y))
                    crop = hd_img[y1:y2, x1:x2]
                    if crop.size > 0:
                        crop_bgr = cv2.cvtColor(crop, cv2.COLOR_RGB2BGR)
                        resized = cv2.resize(crop_bgr, (94, 24))
                        crop_imgs.append(resized)
                        valid_boxes.append((x1, y1, x2, y2))

                if crop_imgs:
                    batch = np.stack(crop_imgs, axis=0).transpose(0, 3, 1, 2).astype(np.float32)
                    rec_outputs = rknn_rec_b4.inference(inputs=[batch])
                    color_outputs = rknn_rec_b1.inference(inputs=[batch])

                    for i in range(len(valid_boxes)):
                        raw_text = decode_lprnet(rec_outputs[0][i])
                        display_text = rectify_plate_text(raw_text)
                        color_logits = np.squeeze(color_outputs[0][i])
                        color_idx = int(np.argmax(color_logits))
                        color_name = {0: '蓝牌', 1: '黄牌', 2: '白牌', 3: '绿牌'}.get(color_idx, '绿牌')
                        x1, y1, x2, y2 = valid_boxes[i]
                        new_results.append({
                            'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                            'text': display_text,
                            'color_bgr': PLATE_COLORS_BGR.get(color_name, (0, 255, 0)),
                            'color_rgb': PLATE_COLORS_RGB.get(color_name, (0, 255, 0))
                        })

        smoothed = smoother.update(new_results)
        with state_lock:
            shared_state['latest_results'] = smoothed


# ==========================================
# DRM 渲染线程
# ==========================================
def render_worker_thread(hw_lib, font):
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
                color_bgr, color_rgb = res['color_bgr'], res['color_rgb']
                text = res['text']

                cv2.rectangle(img_hd, (x1, y1), (x2, y2), color_bgr, 3)
                text_w, text_h = 360, 40
                roi_y1 = max(0, y1 - text_h)
                roi_y2 = y1
                roi_x1 = max(0, x1)
                roi_x2 = min(1280, x1 + text_w)
                if roi_y2 > roi_y1 and roi_x2 > roi_x1:
                    roi = img_hd[roi_y1:roi_y2, roi_x1:roi_x2]
                    roi_pil = Image.fromarray(roi)
                    draw = ImageDraw.Draw(roi_pil)
                    draw.text((0, 0), text, font=font, fill=color_rgb)
                    img_hd[roi_y1:roi_y2, roi_x1:roi_x2] = np.array(roi_pil)

            hd_ptr = base_addr + YOLO_SIZE
            hw_lib.sync_to_screen(ctypes.c_void_p(hd_ptr))


# ==========================================
# 主程序
# ==========================================
def main():
    # ── 1. 初始化硬件流水线 ──
    hw_lib = ctypes.CDLL('./libdma_rga.so')
    hw_lib.fetch_next_frame.restype = ctypes.POINTER(ctypes.c_uint8)
    hw_lib.sync_to_screen.argtypes = [ctypes.c_void_p]
    if hw_lib.init_hardware_pipeline() != 0:
        logger.error("硬件初始化失败！")
        return

    # ── 2. 初始化电机 ──
    motor = MotorController(hw_lib)
    motor.init()
    motor.forward()
    logger.info("电机就绪，小车前进中")

    # ── 3. 加载车牌模型 ──
    DET_MODEL = '/home/linaro/workspace/rknn/INT8_single_plate_640_0.5.rknn'
    REC_B4_MODEL = '/home/linaro/workspace/rknn/LPRNet_multi_300k_b4.rknn'
    REC_B1_MODEL = '/home/linaro/workspace/rknn/LPRNet_color_300k.rknn'

    for path in [DET_MODEL, REC_B4_MODEL, REC_B1_MODEL]:
        if not os.path.exists(path):
            logger.error("模型不存在: %s", path)
            motor.cleanup()
            hw_lib.cleanup_hardware()
            return

    rknn_det = RKNNLite()
    rknn_rec_b4 = RKNNLite()
    rknn_rec_b1 = RKNNLite()
    if rknn_det.load_rknn(DET_MODEL) != 0:
        logger.error("检测模型加载失败")
        motor.cleanup()
        hw_lib.cleanup_hardware()
        return
    if rknn_rec_b4.load_rknn(REC_B4_MODEL) != 0:
        logger.error("识别模型 B4 加载失败")
        motor.cleanup()
        hw_lib.cleanup_hardware()
        return
    if rknn_rec_b1.load_rknn(REC_B1_MODEL) != 0:
        logger.error("识别模型 B1 加载失败")
        motor.cleanup()
        hw_lib.cleanup_hardware()
        return
    rknn_det.init_runtime()
    rknn_rec_b4.init_runtime()
    rknn_rec_b1.init_runtime()
    logger.info("车牌识别模型加载成功")

    # ── 4. 字体 ──
    try:
        font = ImageFont.truetype(FONT_PATH, 32)
    except Exception:
        font = ImageFont.load_default()
        logger.warning("中文字体加载失败，使用默认字体")

    # ── 5. 启动线程 ──
    ai_thread = threading.Thread(
        target=ai_worker_thread,
        args=(rknn_det, rknn_rec_b4, rknn_rec_b1),
        daemon=True)
    ai_thread.start()

    render_thread = threading.Thread(
        target=render_worker_thread,
        args=(hw_lib, font),
        daemon=True)
    render_thread.start()

    frame_count = 0
    logger.info("系统就绪 — 车牌识别 + 电机控制")

    # ── 6. 主循环 ──
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
                shared_state['frame_for_ai'] = {'yolo': img_yolo, 'hd': img_hd}
                shared_state['ai_ready'] = True
                current_results = shared_state['latest_results']

            with render_lock:
                render_state['hd_img'] = img_hd
                render_state['current_results'] = current_results
                render_state['base_addr'] = base_addr
            render_event.set()

            t1 = time.perf_counter()
            frame_count += 1
            if frame_count % 30 == 0:
                fps = 1.0 / (t1 - t0) if t1 > t0 else 0
                plate_count = len(current_results)
                print(f"\r[{frame_count:5d}帧] {fps:5.1f} FPS | 车牌: {plate_count}个   ",
                      end='', flush=True)

    except KeyboardInterrupt:
        logger.info("收到终端退出信号")
    finally:
        exit_event.set()
        ai_thread.join(timeout=2.0)
        render_thread.join(timeout=2.0)
        motor.cleanup()
        hw_lib.cleanup_hardware()
        rknn_det.release()
        rknn_rec_b4.release()
        rknn_rec_b1.release()
        logger.info("系统已安全退出")


if __name__ == '__main__':
    main()