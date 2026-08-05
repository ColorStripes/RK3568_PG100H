# -*- coding: utf-8 -*-
import sys
import time
import ctypes

PATH_CV2 = '/userdata/linaro_workspace/lib'
PATH_RKNN = '/home/linaro/.local/lib/python3.11/site-packages'

if PATH_CV2 not in sys.path:
    sys.path.insert(0, PATH_CV2)
if PATH_RKNN not in sys.path:
    sys.path.insert(0, PATH_RKNN)
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from rknnlite.api import RKNNLite
import threading
from collections import Counter

# ==========================================
# 静态常量配置
# ==========================================
CHARS = ['京', '沪', '津', '渝', '冀', '晋', '蒙', '辽', '吉', '黑',
         '苏', '浙', '皖', '闽', '赣', '鲁', '豫', '鄂', '湘', '粤',
         '桂', '琼', '川', '贵', '云', '藏', '陕', '甘', '青', '宁', '新',
         '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
         'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
         'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
         'W', 'X', 'Y', 'Z', 'I', 'O', '-',
         '使', '学', '挂', '港', '澳', '领', '临', '试', '超', '应', 
         '警', '_']
BLANK_IDX = len(CHARS) - 1
FONT_PATH = '/home/linaro/workspace/SimHei.ttf'
CONF_THRESH = 0.6
LOGIT_THRESH = -np.log(1/CONF_THRESH - 1)

PLATE_COLORS_MAP = {0: '蓝牌', 1: '黄牌', 2: '白牌', 3: '绿牌'}
PLATE_COLORS_BGR = {'蓝牌':(255,0,0), '绿牌':(0,255,0), '黄牌':(0,255,255), '白牌':(255,255,255), '特殊牌':(255,255,255)}
PLATE_COLORS_RGB = {'蓝牌':(0,0,255), '绿牌':(0,255,0), '黄牌':(255,255,0), '白牌':(255,255,255), '特殊牌':(255,255,255)}

ANCHORS = [
    [[4, 5], [8, 10], [13, 16]],          
    [[23, 29], [43, 55], [73, 105]],      
    [[146, 217], [231, 300], [335, 433]]
]

# 统一显存尺寸常量
YOLO_SIZE = 640 * 640 * 3
HD_SIZE = 1920 * 1080 * 3

# ==========================================
# 全局共享状态字典
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
            best_iou = 0
            best_idx = -1
            
            for i, track in enumerate(self.tracked_boxes):
                ixA = max(new_box['x1'], track['x1'])
                iyA = max(new_box['y1'], track['y1'])
                ixB = min(new_box['x2'], track['x2'])
                iyB = min(new_box['y2'], track['y2'])
                interArea = max(0, ixB - ixA) * max(0, iyB - iyA)
                
                boxAArea = (new_box['x2'] - new_box['x1']) * (new_box['y2'] - new_box['y1'])
                boxBArea = (track['x2'] - track['x1']) * (track['y2'] - track['y1'])
                iou = interArea / float(boxAArea + boxBArea - interArea + 1e-5)

                if iou > best_iou:
                    best_iou = iou
                    best_idx = i

            if best_iou > self.iou_thresh:
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
# 解码函数
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
        if len(a_idx) == 0: continue
            
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

def decode_lprnet(char_logits):
    lpr_logits = np.squeeze(char_logits)
    if len(lpr_logits.shape) < 2: return ""
    
    # 维度对齐
    if lpr_logits.shape[0] == 18:
        lpr_logits = lpr_logits.T
        
    res = []
    pre_c = BLANK_IDX
    state = 0  # 状态 0: 等待省份, 状态 1: 等待字母, 状态 2: 等待后续字符
    
    PROV_IDX = set(range(0, 31))
    LETTER_IDX = set(range(40, 66))

    for t in range(lpr_logits.shape[1]):
        step_logits = lpr_logits[:, t].copy()
        
        # --- 强制状态掩膜 (Masking) ---
        if state == 0:
            # 状态0：只允许输出省份或空白
            mask = np.ones(len(CHARS), dtype=bool)
            mask[list(PROV_IDX) + [BLANK_IDX]] = False
            step_logits[mask] = -9999.0
            
        elif state == 1:
            # 状态1：只允许输出字母、空白、或连续重复的省份
            mask = np.ones(len(CHARS), dtype=bool)
            allowed = list(LETTER_IDX) + [BLANK_IDX]
            if pre_c in PROV_IDX: allowed.append(pre_c) # 允许 CTC 连续帧重复同一个省份
            mask[allowed] = False
            step_logits[mask] = -9999.0
            
        # 寻找当前帧最大概率的字符
        c = int(np.argmax(step_logits))

        # CTC 去重合并逻辑
        if c == pre_c or c == BLANK_IDX:
            if c == BLANK_IDX: pre_c = c
            continue
            
        res.append(CHARS[c])
        pre_c = c
        
        # --- 状态跃迁 ---
        if state == 0 and c in PROV_IDX:
            state = 1
        elif state == 1 and c in LETTER_IDX:
            state = 2

    return "".join(res)

def rectify_plate_text(text):
    """
    终极字符纠偏引擎：利用中国车牌先验规则，修复 AI 的形近字混淆
    """
    if not text or len(text) < 3: return text
    
    text_list = list(text)
    
    # ==========================================
    # 车牌后缀（从第3个字符开始）绝对不可能出现 'I' 和 'O' (防 1 和 0 混淆)
    # ==========================================
    for i in range(2, len(text_list)):
        if text_list[i] == 'I': text_list[i] = '1'
        if text_list[i] == 'O': text_list[i] = '0'
        
    text = "".join(text_list)
    
    # 构建形近字字典 (易混淆字母 -> 数字)
    letter_to_digit = {
        'I': '1', 'L': '1', 'T': '7', 'Z': '2', 
        'S': '5', 'B': '8', 'A': '4', 'G': '6', 
        'E': '3', 'O': '0', 'Q': '0', 'D': '0', 'C': '0'
    }
    
    # ==========================================
    # ==========================================
    if text[-1] == '领':
        rectified = text[0] # 保留省份
        for char in text[1:-1]:
            rectified += letter_to_digit.get(char, char)
        rectified += '领'
        return rectified

    # ==========================================
    #  规则 2：大使馆车牌 (如: 使123456)
    # 后面必须全是数字
    # ==========================================
    elif text[0] == '使':
        rectified = '使'
        for char in text[1:]:
            rectified += letter_to_digit.get(char, char)
        return rectified
        
    return text

def hardware_monitor_daemon(hw_lib, sample_interval_s=5.0):
    hw_lib.pci_adc_read = getattr(hw_lib, 'pci_adc_read', lambda _: 0)
    hw_lib.pci_get_sensor_fusion = getattr(hw_lib, 'pci_get_sensor_fusion', lambda _: 0)
    while not exit_event.is_set():
        bat_mv = hw_lib.pci_adc_read(0)
        temp_c = hw_lib.pci_adc_read(1)
        time.sleep(sample_interval_s)

def emergency_shutdown(hw_lib):
    try:
        hw_lib.pci_i2c_write(ctypes.c_ubyte(0x40), ctypes.c_ubyte(0x00), None, 0)
    except AttributeError:
        pass
    hw_lib.cleanup_hardware()
    exit_event.set()

def configure_imu_stream(hw_lib):
    hw_lib.pci_imu_read = getattr(hw_lib, 'pci_imu_read', None)
    hw_lib.pci_can_send = getattr(hw_lib, 'pci_can_send', None)
    hw_lib.pci_ultrasonic_read = getattr(hw_lib, 'pci_ultrasonic_read', None)

def adc_sample_loop(hw_lib, channels, duration_s):
    hw_lib.pci_adc_read = getattr(hw_lib, 'pci_adc_read', lambda _: 0)
    start = time.perf_counter()
    samples = {ch: [] for ch in channels}
    while time.perf_counter() - start < duration_s:
        for ch in channels:
            val = hw_lib.pci_adc_read(ch)
            samples[ch].append(val)
        time.sleep(0.01)
    return samples

def can_logger_thread(hw_lib, output_file):
    hw_lib.pci_can_send = getattr(hw_lib, 'pci_can_send', None)
    with open(output_file, 'w') as f:
        f.write('timestamp,can_id,dlc,data\\n')
        f.flush()
    while not exit_event.is_set():
        time.sleep(0.1)

# ==========================================
# 1. 后台 AI 引擎线程 
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
            
        yolo_img_input = np.expand_dims(yolo_img, axis=0)
        outputs = rknn_det.inference(inputs=[yolo_img_input])
        new_results = []
        
        if outputs is not None:
            boxes_list, scores_list = decode_yolo_fast(outputs, 1920, 1080) 
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
                    x2 = min(1920, int(x + w + pad_x))
                    y2 = min(1080, int(y + h + pad_y))
                    
                    crop = hd_img[y1:y2, x1:x2]
                    if crop.size > 0:
                        crop_bgr = cv2.cvtColor(crop, cv2.COLOR_RGB2BGR)
                        resized_crop = cv2.resize(crop_bgr, (94, 24))
                        crop_imgs.append(resized_crop)
                        valid_boxes.append((x1, y1, x2, y2))
                        
                crop_count = len(crop_imgs)
                
                if crop_count > 0:
                    char_logits_list = []
                    color_logits_list = []
                    processed_num = 0
                    
                    while processed_num < crop_count:
                        remain_num = crop_count - processed_num
                        if remain_num >= 3:
                            batch_imgs = np.zeros((4, 24, 94, 3), dtype=np.uint8)
                            take_num = min(4, remain_num) 
                            for i in range(take_num):
                                batch_imgs[i] = crop_imgs[processed_num + i]
                                
                            rec_out = rknn_rec_b4.inference(inputs=[batch_imgs])
                            for i in range(take_num):
                                char_logits_list.append(rec_out[0][i:i+1])
                                color_logits_list.append(rec_out[1][i:i+1])
                            processed_num += take_num
                        else:
                            img = crop_imgs[processed_num]
                            img_input = np.expand_dims(img, axis=0)
                            rec_out = rknn_rec_b1.inference(inputs=[img_input])
                            char_logits_list.append(rec_out[0])
                            color_logits_list.append(rec_out[1])
                            processed_num += 1
                    for i in range(crop_count):
                        raw_text = decode_lprnet(char_logits_list[i])
                        plate_text = rectify_plate_text(raw_text)
                        
                        # 1. 获取 AI 的预测概率分布 (0~1)
                        logits_sq = np.squeeze(color_logits_list[i])
                        exp_logits = np.exp(logits_sq - np.max(logits_sq))
                        ai_probs = exp_logits / np.sum(exp_logits)
                        
                        plate_type = "未知"
                        
    
                        if len(plate_text) > 0 and plate_text[-1] in ['学', '警', '领', '挂', '使', '港', '澳']:
                            plate_type = "特殊牌"
                        else:
                            # ==========================================
                            # 60% HSV + 40% AI 权重融合
                            # ==========================================
                            hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                            color_bounds = {
                                0: (np.array([100, 43, 46]), np.array([124, 255, 255])), # 蓝牌
                                1: (np.array([10, 30, 46]), np.array([35, 255, 255])),   # 黄牌
                                3: (np.array([36, 43, 46]), np.array([85, 255, 255]))    # 绿牌
                            }
                            
                            hsv_counts = np.zeros(4)
                            for cid, (lower, upper) in color_bounds.items():
                                mask = cv2.inRange(hsv, lower, upper)
                                hsv_counts[cid] = cv2.countNonZero(mask)
                                
                            # 将 HSV 像素数量转换为概率 (0~1)
                            total_hsv_pixels = np.sum(hsv_counts)
                            hsv_probs = np.zeros(4)
                            if total_hsv_pixels > 0:
                                hsv_probs = hsv_counts / total_hsv_pixels
                            
                            # 注意：如果画面全黑/全白导致 total_hsv_pixels=0，则完全听 AI 的
                            if total_hsv_pixels > 100: # 只要有一定数量的有效彩色像素
                                final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                            else:
                                final_probs = ai_probs
                                
                            # 最终结果取融合后概率最大的那一个
                            color_id = int(np.argmax(final_probs))
                            plate_type = PLATE_COLORS_MAP.get(color_id, "未知")
                        
                        display_text = f"{plate_text}({plate_type})"
                        
                        # 固定颜色框，防止闪烁
                        fixed_color_bgr = (0, 255, 0)
                        fixed_color_rgb = (0, 255, 0) 
                        x1, y1, x2, y2 = valid_boxes[i]
                        
                        new_results.append({
                            'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                            'text': display_text,
                            'color_bgr': fixed_color_bgr, 
                            'color_rgb': fixed_color_rgb
                        })
                        
        smoothed_results = smoother.update(new_results)
                        
        with state_lock:
            shared_state['latest_results'] = smoothed_results


# ==========================================
# 2. 独立渲染投屏线程
# ==========================================
def render_worker_thread(hw_lib, font):
    while not exit_event.is_set():
        if render_event.wait(timeout=0.1):
            render_event.clear()
            
            with render_lock:
                if render_state['hd_img'] is None: continue
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
                roi_x2 = min(1920, x1 + text_w)
                
                if roi_y2 > roi_y1 and roi_x2 > roi_x1:
                    roi = img_hd[roi_y1:roi_y2, roi_x1:roi_x2]
                    roi_pil = Image.fromarray(roi)
                    draw = ImageDraw.Draw(roi_pil)
                    draw.text((0, 0), text, font=font, fill=color_rgb)
                    img_hd[roi_y1:roi_y2, roi_x1:roi_x2] = np.array(roi_pil)
            
            hd_ptr = base_addr + YOLO_SIZE
            hw_lib.sync_to_screen(ctypes.c_void_p(hd_ptr))


# ==========================================
# 3. 主控制线程
# ==========================================
def main():
    hw_lib = ctypes.CDLL('./libdma_rga.so')
    hw_lib.fetch_next_frame.restype = ctypes.POINTER(ctypes.c_uint8)
    hw_lib.sync_to_screen.argtypes = [ctypes.c_void_p]
    if hw_lib.init_hardware_pipeline_ex(1) != 0:
        print("硬件初始化失败！(DSI 屏幕)")
        return
    DET_MODEL_PATH = '/home/linaro/workspace/rknn/INT8_single_plate_640_0.5.rknn'
    REC_MODEL_B4_PATH = '/home/linaro/workspace/rknn/LPRNet_multi_300k_b4.rknn'  
    REC_MODEL_B1_PATH = '/home/linaro/workspace/rknn/LPRNet_color_300k.rknn'  
    rknn_det = RKNNLite()
    rknn_rec_b4 = RKNNLite()
    rknn_rec_b1 = RKNNLite()
    
    if rknn_det.load_rknn(DET_MODEL_PATH) != 0: return
    if rknn_rec_b4.load_rknn(REC_MODEL_B4_PATH) != 0: return
    if rknn_rec_b1.load_rknn(REC_MODEL_B1_PATH) != 0: return
    
    rknn_det.init_runtime()
    rknn_rec_b4.init_runtime()
    rknn_rec_b1.init_runtime()

    font = ImageFont.truetype(FONT_PATH, 32)

    ai_thread = threading.Thread(target=ai_worker_thread, args=(rknn_det, rknn_rec_b4, rknn_rec_b1), daemon=True)
    ai_thread.start()

    render_thread = threading.Thread(target=render_worker_thread, args=(hw_lib, font), daemon=True)
    render_thread.start()   
    frame_count = 0

    try:
        while True:
            t0 = time.perf_counter()

            c_ptr = hw_lib.fetch_next_frame()
            if not c_ptr: continue

            base_addr = ctypes.addressof(c_ptr.contents)
            yolo_buffer = (ctypes.c_uint8 * YOLO_SIZE).from_address(base_addr)
            hd_buffer   = (ctypes.c_uint8 * HD_SIZE).from_address(base_addr + YOLO_SIZE)

            img_yolo = np.ndarray(buffer=yolo_buffer, dtype=np.uint8, shape=(640, 640, 3))
            img_hd   = np.ndarray(buffer=hd_buffer,   dtype=np.uint8, shape=(1080, 1920, 3))

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
            fps = 1.0 / (t1 - t0)
            frame_count += 1
            
            if frame_count % 30 == 0:
                print(f"\r[{frame_count}帧] FPGA 真实抓图帧率: {fps:.1f} FPS   ", end='', flush=True)

    except KeyboardInterrupt:
        print("\n 收到终端退出信号")
        exit_event.set()
        ai_thread.join(timeout=2.0)
        render_thread.join(timeout=2.0)
        
    finally:
        print("正在释放硬件与模型资源...")
        hw_lib.cleanup_hardware()
        rknn_det.release()
        rknn_rec_b4.release()
        rknn_rec_b1.release()

if __name__ == '__main__':
    main()