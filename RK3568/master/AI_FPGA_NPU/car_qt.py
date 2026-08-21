# -*- coding: utf-8 -*-
"""
car_qt.py  —  车牌识别 + HDMI推流 + WiFi小车遥控
基于 plate_qt.py 扩展，新增"小车遥控"Tab：
  - D-pad 方向按钮 (↑↓←→) + 停止
  - 键盘 WASD / 方向键 实时操控
  - TCP Socket 服务器，WiFi 客户端可发送指令远程控制
  - 速度滑块调节
  - 集成 MotorOverPCIe (gpio/pwm 通过 PCIe ioctl)
"""
import os
import sys
import cv2
import ctypes
import numpy as np
import time
import threading
import socket
import json
import subprocess
import traceback
from collections import Counter

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTabWidget, QLabel, QPushButton, QLineEdit,
    QComboBox, QSpinBox, QSlider, QCheckBox,
    QSplitter, QGroupBox, QFileDialog, QMessageBox,
    QScrollArea, QGridLayout, QFrame
)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QImage, QPixmap, QFont

from PIL import Image, ImageDraw, ImageFont
from rknnlite.api import RKNNLite

# =====================================================================
# FPGA NPU 启动初始化 (程序最开始执行):
#   npu_init -> npu_configure_layers -> npu_upload_weights -> npu_upload_instructions
# =====================================================================
from npu_bridge import FpgaNpu

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
NPU_WEIGHT_DIR = os.path.join(_BASE_DIR, 'npu_data', 'weight_bin')
NPU_INSTR_FILE = os.path.join(_BASE_DIR, 'npu_data', 'instruction_all.txt')

_npu_lib = ctypes.CDLL(os.path.join(_BASE_DIR, 'libdma_rga.so'))
_npu = FpgaNpu(_npu_lib)   # 单一动态库: NPU/相机/HDMI/小车控制共用同一 .so 实例, 共享 fd/DMA 映射

if _npu.init() < 0:
    print('[FPGA NPU] npu_init FAILED', file=sys.stderr)
    sys.exit(1)
print('[FPGA NPU] npu_init OK')

if _npu.configure_layers() < 0:
    print('[FPGA NPU] layer configure FAILED', file=sys.stderr)
    sys.exit(1)
print('[FPGA NPU] layers configured')

if _npu.upload_weights(NPU_WEIGHT_DIR) < 0:
    print('[FPGA NPU] weight upload FAILED', file=sys.stderr)
    sys.exit(1)
print('[FPGA NPU] weights uploaded: %s' % NPU_WEIGHT_DIR)

if _npu.upload_instructions(NPU_INSTR_FILE) < 0:
    print('[FPGA NPU] instruction upload FAILED', file=sys.stderr)
    sys.exit(1)
print('[FPGA NPU] instructions uploaded: %s' % NPU_INSTR_FILE)








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

PLATE_COLORS_MAP = {0: '蓝牌', 1: '黄牌', 2: '白牌', 3: '绿牌'}
PLATE_COLORS_BGR = {
    '蓝牌': (255, 0, 0), '绿牌': (0, 255, 0),
    '黄牌': (0, 255, 255), '白牌': (255, 255, 255)
}
PLATE_COLORS_RGB = {
    '蓝牌': (0, 0, 255), '绿牌': (0, 255, 0),
    '黄牌': (255, 255, 0), '白牌': (255, 255, 255)
}

CONF_THRESH = 0.6           # objectness 初筛阈值（LOGIT_THRESH 基于此）
LOGIT_THRESH = -np.log(1 / CONF_THRESH - 1)
NMS_SCORE_THRESH = 0.4      # NMS 阈值：作用于 objectness × class_score 的乘积分数

# ── 车牌几何软过滤参数 ──
PLATE_ASPECT_MIN = 1.5      # 宽高比下限（真牌约 3.1~3.4，放宽到只砍明显正方形/竖长）
PLATE_ASPECT_MAX = 6.0      # 宽高比上限（放宽到只砍明显细长条）
PLATE_MIN_AREA = 160        # 最小像素面积，物理上不可能识别出车牌
PLATE_WHITELIST_SCORE = 0.85  # 乘积分数高于此值直接保留，跳过几何过滤

ANCHORS = [
    [[4, 5], [8, 10], [13, 16]],
    [[23, 29], [43, 55], [73, 105]],
    [[146, 217], [231, 300], [335, 433]]
]

# ── 双类别检测：0 车牌 / 1 行人违法；检测头输出 = nc + 5 + 8 通道/锚点 ──
CLASS_NAMES = ['plate', 'pedestrian_violation']
NO = len(CLASS_NAMES) + 5 + 8          # 15
CLS_OFFSET = 5 + 8                      # 类别分数起始通道 = 13

# ── 单类别行人违法检测：nc=1，检测头输出 = 1 + 5 + 8 = 14 通道/锚点 ──
PEDESTRIAN_NO = 1 + 5 + 8               # 14
PEDESTRIAN_CLS_OFFSET = 5 + 8           # 13（保留 8 个关键点通道，与双类别一致）

DEFAULT_DET_MODEL = '/home/linaro/workspace/rknn/plate_pedestrian_INT8_15.rknn'
DEFAULT_PEDESTRIAN_DET_MODEL = '/home/linaro/workspace/rknn/pedestrian_INT8_8.19.rknn'
DEFAULT_REC_MODEL_B4 = '/userdata/rknn/LPRNet_multi_300k_b4.rknn'
DEFAULT_REC_MODEL_B1 = '/home/linaro/workspace/rknn/LPRNet_color_300k.rknn'
DEFAULT_FONT_PATH = '/home/linaro/workspace/SimHei.ttf'
# ── 单一动态库: 相机/HDMI/FPGA_NPU/小车控制全部共用 libdma_rga.so,
#    分辨率由 set_pipeline_resolution 运行时切换 (相机 1280×720 / HDMI 1920×1080) ──
DEFAULT_HW_LIB = os.path.join(_BASE_DIR, 'libdma_rga.so')
DEFAULT_HDMI_LIB = os.path.join(_BASE_DIR, 'libdma_rga.so')

# ── 小车控制库默认路径 ──
DEFAULT_CAR_LIB = os.path.join(_BASE_DIR, 'libdma_rga.so')
DEFAULT_CAR_PORT = 8888

HW_YOLO_SIZE = 640 * 640 * 3
HW_HD_SIZE = 1280 * 720 * 3        # 相机模式 hd 帧
HW_HDMI_SIZE = 1920 * 1080 * 3     # HDMI 模式 hd 帧

DARK_STYLE = """
QMainWindow { background-color: #1e1e2e; }
QWidget { background-color: #1e1e2e; color: #cdd6f4; font-family: "Noto Sans CJK SC", "SimHei", sans-serif; font-size: 14px; }
QGroupBox { border: 1px solid #45475a; border-radius: 8px; margin-top: 12px; padding-top: 18px; font-weight: bold; font-size: 14px; color: #89b4fa; }
QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top center; padding: 0 12px; font-size: 14px; }
QTabWidget::pane { border: 1px solid #45475a; border-radius: 6px; background-color: #181825; }
QTabBar::tab { background-color: #313244; color: #a6adc8; padding: 8px 20px; margin-right: 2px; border-top-left-radius: 6px; border-top-right-radius: 6px; font-weight: bold; min-width: 100px; }
QTabBar::tab:selected { background-color: #89b4fa; color: #1e1e2e; }
QTabBar::tab:hover:!selected { background-color: #45475a; color: #cdd6f4; }
QPushButton { background-color: #45475a; color: #cdd6f4; border: 1px solid #585b70; border-radius: 6px; padding: 6px 16px; font-weight: bold; min-height: 28px; }
QPushButton:hover { background-color: #585b70; border-color: #89b4fa; }
QPushButton:pressed { background-color: #89b4fa; color: #1e1e2e; }
QPushButton:disabled { background-color: #313244; color: #585b70; border-color: #313244; }
QPushButton#loadBtn { background-color: #a6e3a1; color: #1e1e2e; border: none; font-size: 14px; min-height: 34px; }
QPushButton#loadBtn:hover { background-color: #94e2d4; }
QPushButton#loadBtn:disabled { background-color: #313244; color: #585b70; }
QPushButton#releaseBtn { background-color: #f38ba8; color: #1e1e2e; border: none; font-size: 14px; min-height: 34px; }
QPushButton#releaseBtn:hover { background-color: #eba0ac; }
QPushButton#releaseBtn:disabled { background-color: #313244; color: #585b70; }
QPushButton#startBtn { background-color: #89b4fa; color: #1e1e2e; border: none; min-height: 30px; }
QPushButton#startBtn:hover { background-color: #74c7ec; }
QPushButton#startBtn:disabled { background-color: #313244; color: #585b70; }
QPushButton#stopBtn { background-color: #fab387; color: #1e1e2e; border: none; min-height: 30px; }
QPushButton#stopBtn:hover { background-color: #f9e2af; }
QPushButton#stopBtn:disabled { background-color: #313244; color: #585b70; }
QPushButton#dirBtn { font-size: 24px; min-height: 50px; min-width: 50px; background-color: #45475a; border: 2px solid #585b70; border-radius: 8px; }
QPushButton#dirBtn:hover { background-color: #89b4fa; color: #1e1e2e; border-color: #89b4fa; }
QPushButton#dirBtn:pressed { background-color: #74c7ec; color: #1e1e2e; }
QPushButton#stopCarBtn { background-color: #f38ba8; color: #1e1e2e; font-size: 18px; font-weight: bold; border: none; border-radius: 8px; min-height: 50px; min-width: 120px; }
QPushButton#stopCarBtn:hover { background-color: #eba0ac; }
QLineEdit { background-color: #313244; color: #cdd6f4; border: 1px solid #45475a; border-radius: 4px; padding: 4px 8px; min-height: 24px; }
QLineEdit:focus { border-color: #89b4fa; }
QComboBox { background-color: #313244; color: #cdd6f4; border: 1px solid #45475a; border-radius: 4px; padding: 4px 8px; min-height: 24px; }
QComboBox::drop-down { border: none; width: 20px; }
QComboBox QAbstractItemView { background-color: #313244; color: #cdd6f4; selection-background-color: #89b4fa; selection-color: #1e1e2e; }
QSpinBox { background-color: #313244; color: #cdd6f4; border: 1px solid #45475a; border-radius: 4px; padding: 4px 8px; min-height: 24px; }
QSlider::groove:horizontal { height: 6px; background: #45475a; border-radius: 3px; }
QSlider::handle:horizontal { background: #89b4fa; width: 16px; height: 16px; margin: -5px 0; border-radius: 8px; }
QSlider::sub-page:horizontal { background: #89b4fa; border-radius: 3px; }
QTextEdit { background-color: #11111b; color: #a6e3a1; border: 1px solid #45475a; border-radius: 6px; font-family: "Courier New", monospace; font-size: 12px; padding: 4px; }
QProgressBar { background-color: #313244; border: 1px solid #45475a; border-radius: 4px; text-align: center; color: #cdd6f4; min-height: 18px; }
QProgressBar::chunk { background-color: #89b4fa; border-radius: 3px; }
QStatusBar { background-color: #181825; color: #a6adc8; border-top: 1px solid #313244; font-size: 12px; }
QSplitter::handle { background-color: #45475a; }
QSplitter::handle:horizontal { width: 3px; }
QSplitter::handle:vertical { height: 3px; }
QScrollArea { border: none; }
QLabel#imageLabel { background-color: #11111b; border: 1px solid #313244; border-radius: 6px; }
QLabel#plateLabel { color: #f9e2af; font-size: 16px; font-weight: bold; padding: 6px; }
QLabel#fpsLabel { color: #a6e3a1; font-size: 14px; font-weight: bold; font-family: "Courier New", monospace; }
QLabel#modelStatusLabel { font-size: 13px; font-weight: bold; padding: 6px; border-radius: 4px; }
QLabel#carStatusLabel { font-size: 16px; font-weight: bold; padding: 8px; border-radius: 6px; }
QLabel#carIPLabel { font-size: 13px; font-family: "Courier New", monospace; color: #a6e3a1; padding: 4px; }
"""


# ==========================================
# MotorOverPCIe — 通过 PCIe GPIO/PWM 控制 TB6612
# ==========================================
class MotorOverPCIe:
    """通过 PCIe 驱动的 GPIO/PWM ioctl 控制 TB6612 双路电机"""

    # ── TB6612 引脚 → Linux GPIO 编号 ──
    AIN1 = 88   # 左电机 IN1
    AIN2 = 89   # 左电机 IN2
    BIN1 = 90   # 右电机 IN1
    BIN2 = 91   # 右电机 IN2
    STBY = 74   # 芯片使能/待机

    # ── PWM 通道 ──
    PWM_CH_LEFT  = 2   # 左电机
    PWM_CH_RIGHT = 3   # 右电机

    # ── PWM 参数 ──
    PWM_PERIOD_NS = 200000   # 5 kHz
    DEFAULT_DUTY  = 15       # 默认占空比 15%

    # ── 速度上限（供电能力限制，UI 100% 映射到实际 85%）──
    SPEED_CAP = 0.85

    def __init__(self, hw_lib):
        self._lib = hw_lib
        self._duty = self.DEFAULT_DUTY
        self._active = False

    def init(self):
        for pin in (self.AIN1, self.AIN2, self.BIN1, self.BIN2, self.STBY):
            self._lib.gpio(pin, 0)
        self._lib.pwm(self.PWM_CH_LEFT,  0, 0, 0)
        self._lib.pwm(self.PWM_CH_RIGHT, 0, 0, 0)
        print("[Car] 电机初始化完成")

    def go(self, duty=None):
        s = duty if duty is not None else self._duty
        s = int(s * self.SPEED_CAP)
        self._lib.gpio(self.STBY, 1)
        self._lib.gpio(self.AIN1, 0); self._lib.gpio(self.AIN2, 1)
        self._lib.gpio(self.BIN1, 0); self._lib.gpio(self.BIN2, 1)
        self._lib.pwm(self.PWM_CH_LEFT,  1, self.PWM_PERIOD_NS, s)
        self._lib.pwm(self.PWM_CH_RIGHT, 1, self.PWM_PERIOD_NS, s)
        self._active = True

    def backward(self, duty=None):
        s = duty if duty is not None else self._duty
        s = int(s * self.SPEED_CAP)
        self._lib.gpio(self.STBY, 1)
        self._lib.gpio(self.AIN1, 1); self._lib.gpio(self.AIN2, 0)
        self._lib.gpio(self.BIN1, 1); self._lib.gpio(self.BIN2, 0)
        self._lib.pwm(self.PWM_CH_LEFT,  1, self.PWM_PERIOD_NS, s)
        self._lib.pwm(self.PWM_CH_RIGHT, 1, self.PWM_PERIOD_NS, s)
        self._active = True

    def turn_left(self, duty=None):
        s = duty if duty is not None else self._duty
        s = int(s * self.SPEED_CAP)
        self._lib.gpio(self.STBY, 1)
        self._lib.gpio(self.AIN1, 1); self._lib.gpio(self.AIN2, 0)
        self._lib.gpio(self.BIN1, 0); self._lib.gpio(self.BIN2, 1)
        self._lib.pwm(self.PWM_CH_LEFT,  1, self.PWM_PERIOD_NS, s)
        self._lib.pwm(self.PWM_CH_RIGHT, 1, self.PWM_PERIOD_NS, s)
        self._active = True

    def turn_right(self, duty=None):
        s = duty if duty is not None else self._duty
        s = int(s * self.SPEED_CAP)
        self._lib.gpio(self.STBY, 1)
        self._lib.gpio(self.AIN1, 0); self._lib.gpio(self.AIN2, 1)
        self._lib.gpio(self.BIN1, 1); self._lib.gpio(self.BIN2, 0)
        self._lib.pwm(self.PWM_CH_LEFT,  1, self.PWM_PERIOD_NS, s)
        self._lib.pwm(self.PWM_CH_RIGHT, 1, self.PWM_PERIOD_NS, s)
        self._active = True

    def stop(self):
        self._lib.gpio(self.AIN1, 0); self._lib.gpio(self.AIN2, 0)
        self._lib.gpio(self.BIN1, 0); self._lib.gpio(self.BIN2, 0)
        self._lib.pwm(self.PWM_CH_LEFT,  0, 0, 0)
        self._lib.pwm(self.PWM_CH_RIGHT, 0, 0, 0)
        self._lib.gpio(self.STBY, 0)
        self._active = False

    def set_speed(self, duty):
        self._duty = max(5, min(100, int(duty * self.SPEED_CAP)))

    def cleanup(self):
        self.stop()


# ==========================================
# WiFi 遥控 TCP 请求处理器
# ==========================================
class CarCommandHandler:
    """在独立线程中运行的 TCP 服务器，接收单行文本指令"""

    CMD_MAP = {
        'forward':  'go',
        'w':        'go',
        'backward': 'backward',
        's':        'backward',
        'left':     'turn_left',
        'a':        'turn_left',
        'right':    'turn_right',
        'd':        'turn_right',
        'stop':     'stop',
        ' ':        'stop',
    }

    def __init__(self, motor, host='0.0.0.0', port=8888):
        self._motor = motor
        self._host = host
        self._port = port
        self._running = False
        self._server_socket = None

    def start(self):
        if self._running:
            return
        self._running = True
        self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server_socket.settimeout(1.0)
        try:
            self._server_socket.bind((self._host, self._port))
            self._server_socket.listen(5)
        except OSError as e:
            print(f"[Car] 服务器绑定失败: {e}")
            self._server_socket.close()
            self._server_socket = None
            self._running = False
            return
        self._thread = threading.Thread(target=self._serve, daemon=True)
        self._thread.start()
        print(f"[Car] TCP 服务器启动: {self._host}:{self._port}")

    def _serve(self):
        while self._running:
            try:
                client, addr = self._server_socket.accept()
                client.settimeout(5.0)
                t = threading.Thread(target=self._handle, args=(client, addr), daemon=True)
                t.start()
            except socket.timeout:
                continue
            except OSError:
                break

    def _handle(self, client, addr):
        try:
            data = client.recv(1024).decode('utf-8', errors='ignore').strip().lower()
            if not data:
                client.close()
                return

            # 支持 speed:N 格式
            if data.startswith('speed:') or data.startswith('speed='):
                try:
                    val = int(data.split(':')[-1] if ':' in data else data.split('=')[-1])
                    self._motor.set_speed(val)
                    client.sendall(b'OK speed=%d\n' % val)
                except ValueError:
                    client.sendall(b'ERROR bad speed\n')
                client.close()
                return

            cmd = self.CMD_MAP.get(data)
            if cmd is None:
                client.sendall(b'ERROR unknown command: %s\n' % data.encode())
                client.close()
                return

            getattr(self._motor, cmd)()
            print(f"[Car] 指令: {data} 来自 {addr[0]}")
            client.sendall(b'OK %s\n' % data.encode())
        except Exception as e:
            print(f"[Car] 客户端异常: {e}")
        finally:
            try:
                client.close()
            except Exception:
                pass

    def stop(self):
        self._running = False
        if self._server_socket:
            try:
                self._server_socket.close()
            except Exception:
                pass
            self._server_socket = None
        print("[Car] TCP 服务器已停止")


def decode_yolo_fast(outputs, img_w, img_h, no=NO, cls_offset=CLS_OFFSET):
    boxes, scores, class_ids = [], [], []
    for i, out in enumerate(outputs):
        out = np.squeeze(out)
        _, grid_h, grid_w = out.shape
        stride = 640 // grid_h
        out = out.reshape(3, no, grid_h, grid_w)
        conf_raw = out[:, 4, :, :]
        a_idx, y_idx, x_idx = np.where(conf_raw > LOGIT_THRESH)
        if len(a_idx) == 0:
            continue
        valid_data = out[a_idx, :, y_idx, x_idx]
        conf = 1 / (1 + np.exp(-valid_data[:, 4]))
        # 类别分数在通道 cls_offset:，sigmoid 后取 argmax 得到类别 id
        cls_scores = 1 / (1 + np.exp(-valid_data[:, cls_offset:]))
        cls_id = np.argmax(cls_scores, axis=1)
        # 最终置信度 = objectness × 类别分数，避免 objectness 高但类别不确定的误检
        cls_score = cls_scores[np.arange(len(cls_id)), cls_id]
        anchors = np.array(ANCHORS[i])[a_idx]
        grid_xy = np.stack([x_idx, y_idx], axis=-1)
        xy = (1 / (1 + np.exp(-valid_data[:, 0:2])) * 2.0 - 0.5 + grid_xy) * stride
        wh = (1 / (1 + np.exp(-valid_data[:, 2:4])) * 2.0) ** 2 * anchors
        x_min = (xy[:, 0] - wh[:, 0] / 2) / 640.0 * img_w
        y_min = (xy[:, 1] - wh[:, 1] / 2) / 640.0 * img_h
        w_real = wh[:, 0] / 640.0 * img_w
        h_real = wh[:, 1] / 640.0 * img_h
        for j in range(len(conf)):
            boxes.append([int(x_min[j]), int(y_min[j]), int(w_real[j]), int(h_real[j])])
            scores.append(float(conf[j] * cls_score[j]))
            class_ids.append(int(cls_id[j]))
    return boxes, scores, class_ids


def filter_plate_boxes(boxes, scores, class_ids, indices):
    """对 NMS 后的检测结果做车牌几何软过滤（尽量不误杀真牌）。

    - 行人违法(class_id != 0)不套车牌几何约束，直接保留。
    - 车牌(class_id == 0)：
        * 置信度 >= PLATE_WHITELIST_SCORE → 白名单直接保留，跳过几何过滤；
        * 宽高比超出 [PLATE_ASPECT_MIN, PLATE_ASPECT_MAX] → 丢弃（明显正方形/细长条）；
        * 面积 < PLATE_MIN_AREA → 丢弃（物理上无法识别出车牌）。
    返回过滤后的索引列表。
    """
    kept = []
    for idx in np.array(indices).flatten():
        i = int(idx)
        if class_ids[i] != 0:
            kept.append(i)
            continue
        if scores[i] >= PLATE_WHITELIST_SCORE:
            kept.append(i)
            continue
        x, y, w, h = boxes[i]
        if w <= 0 or h <= 0:
            continue
        aspect = w / h
        if not (PLATE_ASPECT_MIN <= aspect <= PLATE_ASPECT_MAX):
            continue
        if w * h < PLATE_MIN_AREA:
            continue
        kept.append(i)
    return kept


PROV_IDX = set(range(0, 31))
LETTER_IDX = set(range(40, 66))


def decode_lprnet_v2(char_logits):
    lpr_logits = np.squeeze(char_logits)
    if len(lpr_logits.shape) < 2:
        return ""
    if lpr_logits.shape[0] == 18:
        lpr_logits = lpr_logits.T
    res = []
    pre_c = BLANK_IDX
    state = 0
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
    letter_to_digit = {
        'I': '1', 'L': '1', 'T': '7', 'Z': '2',
        'S': '5', 'B': '8', 'A': '4', 'G': '6',
        'E': '3', 'O': '0', 'Q': '0', 'D': '0', 'C': '0'
    }
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
                    'color_rgb': new_box['color_rgb'],
                    'crop': new_box.get('crop', track.get('crop', None)),
                }
                updated_tracks.append(smooth_box)
                self.tracked_boxes.pop(best_idx)
            else:
                new_box['text_history'] = [new_box['text']]
                updated_tracks.append(new_box)
        self.tracked_boxes = updated_tracks
        return updated_tracks


class PlateSlotTracker:
    """车牌槽位追踪器：基于空间位置（IoU）+ 文本相似度双重匹配，文本聚合取最高频结果"""

    def __init__(self, max_slots=8, confirm_frames=5, iou_thresh=0.2):
        self.max_slots = max_slots
        self.confirm_frames = confirm_frames
        self.iou_thresh = iou_thresh
        # 槽位：{track_id, text, crop}
        self.slots = [None] * max_slots
        self.write_idx = 0
        # 空间追踪: {track_id: {box, texts:Counter, crop, count, absent}}
        self.tracks = {}
        self._next_tid = 0  # track id 计数器

    @staticmethod
    def _box_iou(a, b):
        """两个 (x1,y1,x2,y2) 框的 IoU"""
        ix1 = max(a[0], b[0]); iy1 = max(a[1], b[1])
        ix2 = min(a[2], b[2]); iy2 = min(a[3], b[3])
        inter = max(0, ix2 - ix1) * max(0, iy2 - iy1)
        area_a = (a[2] - a[0]) * (a[3] - a[1])
        area_b = (b[2] - b[0]) * (b[3] - b[1])
        return inter / (area_a + area_b - inter + 1e-5)

    @staticmethod
    def _text_core(full_text):
        """提取车牌核心号牌（去掉颜色后缀如 '(蓝牌)'）"""
        if '(' in full_text and full_text.endswith(')'):
            return full_text[:full_text.rindex('(')]
        return full_text

    @staticmethod
    def _text_similar(a, b):
        """两个车牌核心号是否足够相似。
        严格要求前2位（省份+城市字母）完全一致，剩余部分允许 ≤1 个字符差异。
        防止 \"京A12345\" 和 \"京B12345\" 这种不同车辆被错误合并或抑制播报。"""
        if not a or not b:
            return False
        a = a.replace(' ', '')
        b = b.replace(' ', '')
        if len(a) != len(b):
            return False
        if len(a) < 4:       # 太短不具辨别力
            return False
        # 前2位（省份+城市字母）必须完全一致，否则肯定是不同车辆
        if a[:2] != b[:2]:
            return False
        # 剩余部分允许 ≤1 个字符差异（容忍 OCR 抖动）
        tail_a, tail_b = a[2:], b[2:]
        mismatches = sum(1 for ca, cb in zip(tail_a, tail_b) if ca != cb)
        return mismatches <= 1

    def _find_best_match(self, det_box, det_text):
        """双重匹配：先 IoU，IoU 不够时用文本兜底"""
        best_tid = None
        best_iou = 0.0
        det_core = self._text_core(det_text).replace(' ', '')

        for tid, t in self.tracks.items():
            iou = self._box_iou(t['box'], det_box)
            if iou > best_iou:
                best_iou = iou
                best_tid = tid
            # 文本兜底：IoU >= 0.08（部分重叠）且车牌核心号完全相同 → 强制匹配
            elif iou >= 0.08 and best_iou < self.iou_thresh:
                best_existing = t['texts'].most_common(1)
                if best_existing:
                    existing_core = self._text_core(best_existing[0][0]).replace(' ', '')
                    if existing_core == det_core and len(existing_core) >= 5:
                        best_iou = iou
                        best_tid = tid

        if best_iou >= self.iou_thresh:
            return (best_tid, best_iou)
        return (None, best_iou)

    @staticmethod
    def _smooth_box(old, new, alpha=0.6):
        return (
            int(alpha * old[0] + (1 - alpha) * new[0]),
            int(alpha * old[1] + (1 - alpha) * new[1]),
            int(alpha * old[2] + (1 - alpha) * new[2]),
            int(alpha * old[3] + (1 - alpha) * new[3]),
        )

    def update(self, detections):
        """
        detections: list of (text, crop, x1, y1, x2, y2)
        返回: list of 8 dicts {text, crop} or None
        """
        matched_tids = set()
        for det in detections:
            text, crop, dx1, dy1, dx2, dy2 = det
            if not text:
                continue
            best_tid, best_iou = self._find_best_match((dx1, dy1, dx2, dy2), text)
            if best_tid is not None:
                t = self.tracks[best_tid]
                t['count'] += 1
                t['box'] = self._smooth_box(t['box'], (dx1, dy1, dx2, dy2))
                t['texts'][text] += 1
                t['absent'] = 0
                # 每 5 帧更新一次 crop，选质量最好的那张
                if t['count'] % 5 == 0:
                    t['crop'] = crop
                matched_tids.add(best_tid)
            else:
                # ── 文字去重：无空间匹配时，检查是否与已有 track 的车牌号相似 ──
                det_core = self._text_core(text).replace(' ', '')
                merged_tid = None
                for tid, t in self.tracks.items():
                    if tid in matched_tids:
                        continue
                    best_existing = t['texts'].most_common(1)
                    if best_existing:
                        existing_core = self._text_core(best_existing[0][0]).replace(' ', '')
                        if PlateSlotTracker._text_similar(existing_core, det_core):
                            merged_tid = tid
                            break
                    # track 尚未积累足够文本时，用已记录的第一个文本比对
                    elif t['texts']:
                        first_text = list(t['texts'].keys())[0]
                        if PlateSlotTracker._text_similar(
                                self._text_core(first_text).replace(' ', ''), det_core):
                            merged_tid = tid
                            break

                if merged_tid is not None:
                    t = self.tracks[merged_tid]
                    t['count'] += 1
                    t['box'] = self._smooth_box(t['box'], (dx1, dy1, dx2, dy2))
                    t['texts'][text] += 1
                    t['absent'] = 0
                    if t['count'] % 5 == 0:
                        t['crop'] = crop
                    matched_tids.add(merged_tid)
                else:
                    tid = self._next_tid
                    self._next_tid += 1
                    self.tracks[tid] = {
                        'box': (dx1, dy1, dx2, dy2),
                        'texts': Counter({text: 1}),
                        'crop': crop,
                        'count': 1,
                        'absent': 0,
                    }
                    matched_tids.add(tid)

        # 超时清理未匹配的 track
        for tid in list(self.tracks.keys()):
            if tid not in matched_tids:
                self.tracks[tid]['absent'] += 1
                if self.tracks[tid]['absent'] > 30:
                    # 清除对应的槽位，防止残留数据触发 TTS 重复播报
                    for i, slot in enumerate(self.slots):
                        if slot is not None and slot.get('track_id') == tid:
                            self.slots[i] = None
                            break
                    del self.tracks[tid]

        # 确认的 track → 写入槽位（按 track_id 原地更新，避免重复占槽）
        for tid, t in list(self.tracks.items()):
            if t['count'] >= self.confirm_frames:
                best_text = t['texts'].most_common(1)[0][0]
                existing_idx = None
                for i, slot in enumerate(self.slots):
                    if slot is not None and slot.get('track_id') == tid:
                        existing_idx = i
                        break
                if existing_idx is not None:
                    self.slots[existing_idx]['crop'] = t['crop']
                    self.slots[existing_idx]['text'] = best_text
                else:
                    self.slots[self.write_idx] = {
                        'track_id': tid,
                        'text': best_text,
                        'crop': t['crop'].copy(),
                    }
                    self.write_idx = (self.write_idx + 1) % self.max_slots
                # 不删除 track，持续追踪更新

        return self.slots

    @staticmethod
    def _validate_and_format(full_text):
        """校验中国车牌规则，返回 (格式化文本, 是否合法)。
        蓝牌7位、绿牌8位、黄牌7位、白牌等，不符合规则返回 ("", False) 过滤掉。"""
        # 解析 "京A12345(蓝牌)"
        ptype = ""
        core = full_text
        if '(' in full_text and full_text.endswith(')'):
            ptype = full_text[full_text.rindex('(') + 1:-1]
            core = full_text[:full_text.rindex('(')]
        if not core:
            return ("", False)

        PROVINCES = set('京津沪渝冀晋蒙辽吉黑苏浙皖闽赣鲁豫鄂湘粤桂琼川贵云藏陕甘青宁新')
        LETTERS  = set('ABCDEFGHJKLMNPQRSTUVWXYZ')
        DIGITS   = set('0123456789')

        valid = False
        formatted = core

        if ptype in ('蓝牌', '黄牌', '白牌'):
            # 7位: [省][市字母][5位数字/字母]
            if len(core) == 7 and core[0] in PROVINCES and core[1] in LETTERS:
                tail = core[2:]
                if all(c in DIGITS or c in LETTERS for c in tail):
                    formatted = core[:2] + '·' + tail
                    valid = True
        elif ptype == '绿牌':
            # 8位: [省][市字母][6位数字/字母]
            if len(core) == 8 and core[0] in PROVINCES and core[1] in LETTERS:
                tail = core[2:]
                if all(c in DIGITS or c in LETTERS for c in tail):
                    formatted = core[:2] + '·' + tail
                    valid = True
        elif ptype == '特殊牌':
            # 警牌、使牌、领牌等 → 放宽校验，至少省份正确 + 长度>=5
            if len(core) >= 5 and core[0] in PROVINCES:
                valid = True
                formatted = core
        else:
            # 未知类型：宽松校验，长度 7~8 且省份正确
            if 7 <= len(core) <= 8 and core[0] in PROVINCES:
                valid = True
                formatted = core[:2] + '·' + core[2:] if len(core) >= 3 else core

        return (formatted, valid)


class ImageLabel(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("imageLabel")
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumSize(320, 240)
        self._pixmap = None

    def set_cv_image(self, cv_img, is_rgb=False):
        try:
            if not is_rgb:
                rgb_img = cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB)
            else:
                rgb_img = cv_img
            rgb_img = np.ascontiguousarray(rgb_img)
            h, w, ch = rgb_img.shape
            bytes_per_line = ch * w
            q_img = QImage(rgb_img.data, w, h, bytes_per_line, QImage.Format_RGB888).copy()
            self._pixmap = QPixmap.fromImage(q_img)
            self._update_display()
        except Exception:
            pass

    def _update_display(self):
        if self._pixmap is None:
            return
        scaled = self._pixmap.scaled(self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
        super().setPixmap(scaled)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._update_display()


class PlateRecognitionWindow(QMainWindow):
    fps_signal = pyqtSignal(float)
    camera_status_signal = pyqtSignal(str, str)
    run_on_main = pyqtSignal(object)
    car_status_signal = pyqtSignal(str, str)  # (消息, 颜色)

    # ── TTS 播报参数 ──
    TTS_MIN_CONSECUTIVE = 5    # 连续出现 N 帧后才播报（过滤 OCR 抖动，提高到5帧更稳定）
    TTS_FUZZY_WINDOW = 30.0    # 编辑距离去重的回溯窗口（秒）

    def __init__(self):
        super().__init__()
        self.rknn_det = None
        self.det_no = NO
        self.rknn_rec_b4 = None
        self.rknn_rec_b1 = None
        self.rknn_det_pedestrian = None
        self.models_loaded = False
        self.font = None
        self.camera_running = False
        self._stop_camera_flag = False
        self._camera_hard_stop = False
        self.hdmi_running = False
        self._stop_hdmi_flag = False
        self.sdcard_running = False
        self._stop_sdcard_flag = False
        self.pedestrian_running = False
        self._stop_pedestrian_flag = False
        self._tts_enabled = False               # TTS 播报开关
        self._tts_last_announced = {}            # plate_text → timestamp 防抖
        self._tts_queue = []                     # 待播报车牌队列 (plate_text, enqueue_time)
        self._tts_speaking = False               # 当前是否正在播报
        self._tts_current_plate = None           # 当前正在播报的车牌号
        self._tts_consecutive = {}               # plate_text → 连续出现帧数
        self._tts_warm_start_ts = 0.0            # 上次 warm-start 时间戳，防止频繁触发
        self._camera_retry_needed = False        # 摄像头 FPS 不达标需要自动重试
        self._camera_last_fps = 0.0              # 上次测得的 FPS（用于重试判断）
        self._camera_suppress_status = False     # 重试期间抑制状态栏消息
        self._hw_screen_map = {}
        self._hdmi_screen_map = {}

        # ── 小车遥控状态 ──
        self._car_lib = None
        self._motor = None
        self._pressed_keys = set()
        self._car_server = None
        self._car_server_running = False
        self._camera_hw_lib = None  # 存储 C++ 库句柄，供 closeEvent 应急清理
        self._hdmi_hw_lib = None

        self._load_font()
        self._init_ui()
        self._connect_signals()

    def _load_font(self):
        try:
            self.font = ImageFont.truetype(DEFAULT_FONT_PATH, 28)
        except IOError:
            self.font = ImageFont.load_default()

    def _init_ui(self):
        self.setWindowTitle("车牌识别 + 小车遥控 - RKNN 推理平台 (Qt5)")
        self.setGeometry(50, 50, 1280, 800)
        self.setMinimumSize(1024, 680)
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(8, 8, 8, 8)
        main_layout.setSpacing(8)

        left_panel = self._build_left_panel()
        left_scroll = QScrollArea()
        left_scroll.setWidget(left_panel)
        left_scroll.setWidgetResizable(True)
        left_scroll.setFixedWidth(240)
        left_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        main_layout.addWidget(left_scroll)

        right_panel = self._build_right_panel()
        main_layout.addWidget(right_panel, 1)

        self._build_status_bar()

    def _build_left_panel(self):
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(8)

        det_group = QGroupBox("检测模型 (YOLO)")
        det_layout = QVBoxLayout(det_group)
        self.det_model_edit = QLineEdit(DEFAULT_DET_MODEL)
        det_layout.addWidget(self.det_model_edit)
        det_browse = QPushButton("浏览...")
        det_browse.clicked.connect(lambda: self._browse_file(self.det_model_edit, "选择检测模型"))
        det_layout.addWidget(det_browse)
        det_layout.addWidget(QLabel("检测类别数:"))
        self.det_nc_combo = QComboBox()
        self.det_nc_combo.addItem("双类 (车牌+行人违法)", 2)
        self.det_nc_combo.addItem("单类 (仅车牌)", 1)
        det_layout.addWidget(self.det_nc_combo)
        layout.addWidget(det_group)

        ped_group = QGroupBox("行人违法检测模型 (YOLO)")
        ped_layout = QVBoxLayout(ped_group)
        self.pedestrian_det_model_edit = QLineEdit(DEFAULT_PEDESTRIAN_DET_MODEL)
        ped_layout.addWidget(self.pedestrian_det_model_edit)
        ped_browse = QPushButton("浏览...")
        ped_browse.clicked.connect(lambda: self._browse_file(self.pedestrian_det_model_edit, "选择行人违法检测模型"))
        ped_layout.addWidget(ped_browse)
        layout.addWidget(ped_group)

        rec_group = QGroupBox("识别模型 (LPRNet)")
        rec_layout = QVBoxLayout(rec_group)
        rec_layout.addWidget(QLabel("Batch4 模型 (多车牌批量):"))
        self.rec_model_b4_edit = QLineEdit(DEFAULT_REC_MODEL_B4)
        rec_layout.addWidget(self.rec_model_b4_edit)
        rec_b4_browse = QPushButton("浏览...")
        rec_b4_browse.clicked.connect(lambda: self._browse_file(self.rec_model_b4_edit, "选择B4识别模型"))
        rec_layout.addWidget(rec_b4_browse)
        rec_layout.addWidget(QLabel("Batch1 模型 (单车牌/颜色):"))
        self.rec_model_b1_edit = QLineEdit(DEFAULT_REC_MODEL_B1)
        rec_layout.addWidget(self.rec_model_b1_edit)
        rec_b1_browse = QPushButton("浏览...")
        rec_b1_browse.clicked.connect(lambda: self._browse_file(self.rec_model_b1_edit, "选择B1识别模型"))
        rec_layout.addWidget(rec_b1_browse)
        layout.addWidget(rec_group)

        btn_layout = QHBoxLayout()
        self.load_btn = QPushButton("加载模型")
        self.load_btn.setObjectName("loadBtn")
        self.load_btn.clicked.connect(self._load_models)
        btn_layout.addWidget(self.load_btn)
        self.release_btn = QPushButton("释放模型")
        self.release_btn.setObjectName("releaseBtn")
        self.release_btn.setEnabled(False)
        self.release_btn.clicked.connect(self._release_models)
        btn_layout.addWidget(self.release_btn)
        layout.addLayout(btn_layout)

        self.model_status_label = QLabel("模型状态: 未加载")
        self.model_status_label.setObjectName("modelStatusLabel")
        self.model_status_label.setStyleSheet("color: #f38ba8; background-color: #313244; padding: 6px; border-radius: 4px;")
        self.model_status_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.model_status_label)

        layout.addStretch()
        return panel

    def _build_right_panel(self):
        self.tab_widget = QTabWidget()
        self.tab_widget.addTab(self._build_camera_tab(), "摄像头输入源")
        self.tab_widget.addTab(self._build_hdmi_tab(), "HDMI输入源")
        self.tab_widget.addTab(self._build_sdcard_tab(), "SD卡文件")
        self.tab_widget.addTab(self._build_pedestrian_tab(), "行人违法识别")
        self.tab_widget.addTab(self._build_car_tab(), "小车遥控")
        return self.tab_widget

    # ────────────────────────────────
    # 小车遥控 Tab
    # ────────────────────────────────
    def _build_car_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        # ── 库路径 ──
        lib_group = QGroupBox("控制库配置")
        lib_layout = QHBoxLayout(lib_group)
        lib_layout.addWidget(QLabel("libdma_rga.so:"))
        self.car_lib_edit = QLineEdit(DEFAULT_CAR_LIB)
        lib_layout.addWidget(self.car_lib_edit, 1)
        car_browse = QPushButton("浏览...")
        car_browse.clicked.connect(lambda: self._browse_file(
            self.car_lib_edit, "选择小车控制库", "动态库 (*.so);;所有文件 (*.*)"))
        lib_layout.addWidget(car_browse)
        layout.addWidget(lib_group)

        # ── 服务器控制 ──
        server_group = QGroupBox("WiFi 遥控服务器")
        server_layout = QVBoxLayout(server_group)
        server_row1 = QHBoxLayout()
        server_row1.addWidget(QLabel("端口:"))
        self.car_port_spin = QSpinBox()
        self.car_port_spin.setRange(1024, 65535)
        self.car_port_spin.setValue(DEFAULT_CAR_PORT)
        server_row1.addWidget(self.car_port_spin)
        server_row1.addStretch()
        self.car_start_btn = QPushButton("启动服务器")
        self.car_start_btn.setObjectName("startBtn")
        self.car_start_btn.clicked.connect(self._start_car_server)
        server_row1.addWidget(self.car_start_btn)
        self.car_stop_btn = QPushButton("停止服务器")
        self.car_stop_btn.setObjectName("stopBtn")
        self.car_stop_btn.setEnabled(False)
        self.car_stop_btn.clicked.connect(self._stop_car_server)
        server_row1.addWidget(self.car_stop_btn)
        server_layout.addLayout(server_row1)

        server_row2 = QHBoxLayout()
        server_row2.addWidget(QLabel("本机IP:"))
        self.car_ip_label = QLabel(self._get_local_ip())
        self.car_ip_label.setObjectName("carIPLabel")
        server_row2.addWidget(self.car_ip_label)
        server_row2.addStretch()
        self.car_status_label = QLabel("未启动")
        self.car_status_label.setObjectName("carStatusLabel")
        self.car_status_label.setStyleSheet("color: #f38ba8; background-color: #313244;")
        self.car_status_label.setAlignment(Qt.AlignCenter)
        server_row2.addWidget(self.car_status_label)
        server_layout.addLayout(server_row2)
        layout.addWidget(server_group)

        # ── 速度控制 ──
        speed_group = QGroupBox("速度控制")
        speed_layout = QVBoxLayout(speed_group)
        speed_row = QHBoxLayout()
        speed_row.addWidget(QLabel("慢"))
        self.car_speed_slider = QSlider(Qt.Horizontal)
        self.car_speed_slider.setRange(5, 100)
        self.car_speed_slider.setValue(15)
        self.car_speed_slider.valueChanged.connect(self._on_car_speed_changed)
        speed_row.addWidget(self.car_speed_slider, 1)
        speed_row.addWidget(QLabel("快"))
        self.car_speed_label = QLabel("15%")
        self.car_speed_label.setStyleSheet("color: #89b4fa; font-weight: bold; min-width: 40px;")
        speed_row.addWidget(self.car_speed_label)
        speed_layout.addLayout(speed_row)
        layout.addWidget(speed_group)

        # ── 键盘控制开关 ──
        kb_row = QHBoxLayout()
        kb_row.addWidget(QLabel("键盘控制:"))
        self.keyboard_checkbox = QCheckBox("启用 (↑↓←→/WASD 驾驶, Space 刹车)")
        self.keyboard_checkbox.setChecked(False)
        self.keyboard_enabled = False
        self.keyboard_checkbox.toggled.connect(self._on_keyboard_toggled)
        kb_row.addWidget(self.keyboard_checkbox)
        kb_row.addStretch()
        layout.addLayout(kb_row)

        # ── D-Pad 方向按钮 ──
        dpad_frame = QFrame()
        dpad_frame.setStyleSheet("QFrame { background-color: #181825; border-radius: 10px; }")
        dpad_layout = QVBoxLayout(dpad_frame)
        dpad_layout.setAlignment(Qt.AlignCenter)

        # 上排: 前进
        up_row = QHBoxLayout()
        up_row.setAlignment(Qt.AlignCenter)
        self.btn_forward = QPushButton("▲  前进")
        self.btn_forward.setObjectName("dirBtn")
        self.btn_forward.setMinimumSize(120, 56)
        self.btn_forward.clicked.connect(lambda: self._car_cmd('forward'))
        up_row.addWidget(self.btn_forward)
        dpad_layout.addLayout(up_row)

        # 中排: 左转  停止  右转
        mid_row = QHBoxLayout()
        mid_row.setAlignment(Qt.AlignCenter)
        self.btn_left = QPushButton("◀  左转")
        self.btn_left.setObjectName("dirBtn")
        self.btn_left.setMinimumSize(120, 56)
        self.btn_left.clicked.connect(lambda: self._car_cmd('left'))
        mid_row.addWidget(self.btn_left)

        self.btn_stop = QPushButton("■ STOP")
        self.btn_stop.setObjectName("stopCarBtn")
        self.btn_stop.clicked.connect(lambda: self._car_cmd('stop'))
        mid_row.addWidget(self.btn_stop)

        self.btn_right = QPushButton("右转  ▶")
        self.btn_right.setObjectName("dirBtn")
        self.btn_right.setMinimumSize(120, 56)
        self.btn_right.clicked.connect(lambda: self._car_cmd('right'))
        mid_row.addWidget(self.btn_right)
        dpad_layout.addLayout(mid_row)

        # 下排: 后退
        down_row = QHBoxLayout()
        down_row.setAlignment(Qt.AlignCenter)
        self.btn_backward = QPushButton("▼  后退")
        self.btn_backward.setObjectName("dirBtn")
        self.btn_backward.setMinimumSize(120, 56)
        self.btn_backward.clicked.connect(lambda: self._car_cmd('backward'))
        down_row.addWidget(self.btn_backward)
        dpad_layout.addLayout(down_row)

        layout.addWidget(dpad_frame)

        # ── 提示 ──
        hint = QLabel("键盘: ↑↓←→ 或 WASD 驾驶 · Space 刹车 · 组合键可转向")
        hint.setStyleSheet("color: #a6adc8; font-size: 12px;")
        hint.setAlignment(Qt.AlignCenter)
        layout.addWidget(hint)

        layout.addStretch()
        return tab

    def _get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "未连接WiFi"

    def _on_car_speed_changed(self, val):
        self.car_speed_label.setText(f"{val}%")
        if self._motor:
            self._motor.set_speed(val)

    def _car_cmd(self, cmd):
        if not self._motor:
            QMessageBox.warning(self, "提示", "请先启动小车遥控服务器！")
            return
        speed = self.car_speed_slider.value()
        if cmd == 'forward':
            self._motor.go(speed)
        elif cmd == 'backward':
            self._motor.backward(speed)
        elif cmd == 'left':
            self._motor.turn_left(speed)
        elif cmd == 'right':
            self._motor.turn_right(speed)
        elif cmd == 'stop':
            self._motor.stop()

    def _start_car_server(self):
        car_path = self.car_lib_edit.text()
        if not os.path.isfile(car_path):
            QMessageBox.critical(self, "错误", f"控制库文件不存在:\n{car_path}")
            return

        try:
            self._car_lib = ctypes.CDLL(car_path)
            self._car_lib.gpio.argtypes = [ctypes.c_int, ctypes.c_int]
            self._car_lib.gpio.restype = ctypes.c_int
            self._car_lib.pwm.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
            self._car_lib.pwm.restype = ctypes.c_int
        except OSError as e:
            QMessageBox.critical(self, "加载失败", f"无法加载控制库:\n{e}")
            self._car_lib = None
            return

        self._motor = MotorOverPCIe(self._car_lib)
        self._motor.init()

        port = self.car_port_spin.value()
        self._car_server = CarCommandHandler(self._motor, port=port)
        self._car_server.start()
        self._car_server_running = True

        self.car_start_btn.setEnabled(False)
        self.car_stop_btn.setEnabled(True)
        self.car_status_label.setText("运行中")
        self.car_status_label.setStyleSheet("color: #a6e3a1; background-color: #313244;")
        self.car_ip_label.setText(self._get_local_ip())
        self.statusBar().showMessage(f"WiFi 遥控已启动 | telnet {self._get_local_ip()} {port}  发送指令: forward/backward/left/right/stop/speed:N")

    def _stop_car_server(self):
        if self._car_server:
            self._car_server.stop()
            self._car_server = None
        if self._motor:
            self._motor.cleanup()
            self._motor = None
        self._car_lib = None
        self._car_server_running = False

        self.car_start_btn.setEnabled(True)
        self.car_stop_btn.setEnabled(False)
        self.car_status_label.setText("已停止")
        self.car_status_label.setStyleSheet("color: #f38ba8; background-color: #313244;")
        self.statusBar().showMessage("WiFi 遥控已停止")

    def _on_keyboard_toggled(self, checked):
        self.keyboard_enabled = checked

    # ────────────────────────────────
    # 键盘事件 — 驾驶控制（组合键支持）
    # ────────────────────────────────
    def _car_keys_to_cmd(self, keys):
        """根据当前按下的方向键集合，计算应执行的指令和对应按钮"""
        has_u = Qt.Key_Up in keys or Qt.Key_W in keys
        has_d = Qt.Key_Down in keys or Qt.Key_S in keys
        has_l = Qt.Key_Left in keys or Qt.Key_A in keys
        has_r = Qt.Key_Right in keys or Qt.Key_D in keys

        if has_u and has_r and not has_d and not has_l:
            return 'right', self.btn_right
        if has_u and has_l and not has_d and not has_r:
            return 'left', self.btn_left
        if has_d and has_r and not has_u and not has_l:
            return 'right', self.btn_right
        if has_d and has_l and not has_u and not has_r:
            return 'left', self.btn_left
        if has_u:
            return 'forward', self.btn_forward
        if has_d:
            return 'backward', self.btn_backward
        if has_l:
            return 'left', self.btn_left
        if has_r:
            return 'right', self.btn_right
        return 'stop', self.btn_stop

    def keyPressEvent(self, event):
        if not self._motor or not self.keyboard_enabled:
            super().keyPressEvent(event)
            return

        key = event.key()
        if key in (Qt.Key_Up, Qt.Key_W, Qt.Key_Down, Qt.Key_S,
                   Qt.Key_Left, Qt.Key_A, Qt.Key_Right, Qt.Key_D, Qt.Key_Space):
            self._pressed_keys.add(key)
            if key == Qt.Key_Space:
                self._pressed_keys.clear()
                self._exec_car_cmd('stop', self.btn_stop)
            else:
                self._apply_key_cmd()
        else:
            super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        if self._motor and self.keyboard_enabled:
            key = event.key()
            self._pressed_keys.discard(key)
            self._apply_key_cmd()
        super().keyReleaseEvent(event)

    def _apply_key_cmd(self):
        cmd, btn = self._car_keys_to_cmd(self._pressed_keys)
        self._exec_car_cmd(cmd, btn)

    def _exec_car_cmd(self, cmd, btn):
        speed = self.car_speed_slider.value()
        if cmd == 'forward':
            self._motor.go(speed)
        elif cmd == 'backward':
            self._motor.backward(speed)
        elif cmd == 'left':
            self._motor.turn_left(speed)
        elif cmd == 'right':
            self._motor.turn_right(speed)
        else:
            self._motor.stop()

    # ────────────────────────────────
    # HDMI  Tab (不变)
    # ────────────────────────────────
    def _build_hdmi_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(8, 8, 8, 8)

        lib_row = QHBoxLayout()
        lib_row.addWidget(QLabel("推流库:"))
        self.hdmi_lib_edit = QLineEdit(DEFAULT_HDMI_LIB)
        lib_row.addWidget(self.hdmi_lib_edit, 1)
        hdmi_browse = QPushButton("浏览...")
        hdmi_browse.clicked.connect(lambda: self._browse_file(
            self.hdmi_lib_edit, "选择HDMI推流库", "动态库 (*.so);;所有文件 (*.*)"))
        lib_row.addWidget(hdmi_browse)
        layout.addLayout(lib_row)

        screen_row = QHBoxLayout()
        screen_row.addWidget(QLabel("推流屏幕:"))
        self.hdmi_screen_combo = QComboBox()
        self.hdmi_screen_combo.setMinimumWidth(250)
        screen_row.addWidget(self.hdmi_screen_combo)
        hdmi_refresh_btn = QPushButton("刷新")
        hdmi_refresh_btn.clicked.connect(self._refresh_hdmi_screens)
        screen_row.addWidget(hdmi_refresh_btn)
        screen_row.addStretch()
        layout.addLayout(screen_row)

        btn_row = QHBoxLayout()
        self.hdmi_start_btn = QPushButton("开启HDMI")
        self.hdmi_start_btn.setObjectName("startBtn")
        self.hdmi_start_btn.clicked.connect(self._start_hdmi)
        btn_row.addWidget(self.hdmi_start_btn)
        self.hdmi_stop_btn = QPushButton("关闭HDMI")
        self.hdmi_stop_btn.setObjectName("stopBtn")
        self.hdmi_stop_btn.setEnabled(False)
        self.hdmi_stop_btn.clicked.connect(self._stop_hdmi)
        btn_row.addWidget(self.hdmi_stop_btn)
        self.hdmi_fps_label = QLabel("FPS: --")
        self.hdmi_fps_label.setObjectName("fpsLabel")
        btn_row.addWidget(self.hdmi_fps_label)
        self.hdmi_status_label = QLabel("")
        btn_row.addWidget(self.hdmi_status_label)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        slots_group = QGroupBox("车牌截取 (连续5帧确认) — HDMI推流已输出到物理屏幕")
        slots_layout = QGridLayout(slots_group)
        slots_layout.setSpacing(8)
        self.hdmi_slots = []
        for i in range(8):
            slot_frame = QFrame()
            slot_frame.setStyleSheet("QFrame { background-color: #11111b; border: 1px solid #45475a; border-radius: 6px; }")
            slot_v = QVBoxLayout(slot_frame)
            slot_v.setContentsMargins(6, 6, 6, 6)
            slot_v.setSpacing(4)
            img_label = QLabel()
            img_label.setFixedSize(282, 72)
            img_label.setAlignment(Qt.AlignCenter)
            img_label.setStyleSheet("background-color: #000; border: none;")
            slot_v.addWidget(img_label, alignment=Qt.AlignCenter)
            text_label = QLabel("--")
            text_label.setAlignment(Qt.AlignCenter)
            text_label.setStyleSheet("color: #f9e2af; font-size: 13px; font-weight: bold; border: none; background: transparent;")
            slot_v.addWidget(text_label)
            self.hdmi_slots.append({'img': img_label, 'text': text_label})
            slots_layout.addWidget(slot_frame, i // 4, i % 4)
        layout.addWidget(slots_group, 1)

        self._refresh_hdmi_screens()
        return tab

    def _build_camera_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(8, 8, 8, 8)

        ctrl_row = QHBoxLayout()
        ctrl_row.addWidget(QLabel("数据源:"))
        self.camera_source_combo = QComboBox()
        self.camera_source_combo.addItems(['hardware', 'usb'])
        self.camera_source_combo.currentTextChanged.connect(self._on_camera_source_changed)
        ctrl_row.addWidget(self.camera_source_combo)

        self.usb_widget = QWidget()
        usb_layout = QHBoxLayout(self.usb_widget)
        usb_layout.setContentsMargins(0, 0, 0, 0)
        usb_layout.addWidget(QLabel("摄像头:"))
        self.camera_idx_spin = QSpinBox()
        self.camera_idx_spin.setRange(0, 10)
        self.camera_idx_spin.setValue(0)
        usb_layout.addWidget(self.camera_idx_spin)
        usb_layout.addWidget(QLabel("分辨率:"))
        self.camera_res_combo = QComboBox()
        self.camera_res_combo.addItems(['640x480', '1280x720', '1920x1080'])
        self.camera_res_combo.setCurrentText('1280x720')
        usb_layout.addWidget(self.camera_res_combo)
        self.usb_widget.hide()

        self.hw_widget = QWidget()
        hw_layout = QHBoxLayout(self.hw_widget)
        hw_layout.setContentsMargins(0, 0, 0, 0)
        hw_layout.addWidget(QLabel("推流库:"))
        self.hw_lib_edit = QLineEdit(DEFAULT_HW_LIB)
        hw_layout.addWidget(self.hw_lib_edit, 1)
        hw_browse = QPushButton("浏览...")
        hw_browse.clicked.connect(lambda: self._browse_file(
            self.hw_lib_edit, "选择推流库", "动态库 (*.so);;所有文件 (*.*)"))
        hw_layout.addWidget(hw_browse)
        ctrl_row.addWidget(self.hw_widget)
        ctrl_row.addWidget(self.usb_widget)
        layout.addLayout(ctrl_row)

        screen_row = QHBoxLayout()
        screen_row.addWidget(QLabel("输出屏幕:"))
        self.hw_screen_combo = QComboBox()
        screen_row.addWidget(self.hw_screen_combo)
        refresh_btn = QPushButton("刷新")
        refresh_btn.clicked.connect(self._refresh_hw_screens)
        screen_row.addWidget(refresh_btn)
        screen_row.addStretch()
        layout.addLayout(screen_row)

        btn_row = QHBoxLayout()
        self.camera_start_btn = QPushButton("开启摄像头")
        self.camera_start_btn.setObjectName("startBtn")
        self.camera_start_btn.clicked.connect(self._start_camera)
        btn_row.addWidget(self.camera_start_btn)
        self.camera_stop_btn = QPushButton("关闭摄像头")
        self.camera_stop_btn.setObjectName("stopBtn")
        self.camera_stop_btn.setEnabled(False)
        self.camera_stop_btn.clicked.connect(self._stop_camera)
        btn_row.addWidget(self.camera_stop_btn)
        self.camera_fps_label = QLabel("FPS: --")
        self.camera_fps_label.setObjectName("fpsLabel")
        btn_row.addWidget(self.camera_fps_label)
        self.camera_status_label = QLabel("")
        btn_row.addWidget(self.camera_status_label)
        self.camera_tts_check = QCheckBox("播报车牌")
        self.camera_tts_check.setToolTip("通过喇叭朗读识别到的车牌号（本地WAV拼接 + aplay）")
        self.camera_tts_check.toggled.connect(self._on_tts_toggled)
        btn_row.addWidget(self.camera_tts_check)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        slots_group = QGroupBox("车牌截取 (连续5帧确认) — 已推流到物理屏幕")
        slots_layout = QGridLayout(slots_group)
        slots_layout.setSpacing(8)
        self.camera_slots = []
        for i in range(8):
            slot_frame = QFrame()
            slot_frame.setStyleSheet("QFrame { background-color: #11111b; border: 1px solid #45475a; border-radius: 6px; }")
            slot_v = QVBoxLayout(slot_frame)
            slot_v.setContentsMargins(6, 6, 6, 6)
            slot_v.setSpacing(4)
            img_label = QLabel()
            img_label.setFixedSize(282, 72)
            img_label.setAlignment(Qt.AlignCenter)
            img_label.setStyleSheet("background-color: #000; border: none;")
            slot_v.addWidget(img_label, alignment=Qt.AlignCenter)
            text_label = QLabel("--")
            text_label.setAlignment(Qt.AlignCenter)
            text_label.setStyleSheet("color: #f9e2af; font-size: 13px; font-weight: bold; border: none; background: transparent;")
            slot_v.addWidget(text_label)
            self.camera_slots.append({'img': img_label, 'text': text_label})
            slots_layout.addWidget(slot_frame, i // 4, i % 4)
        layout.addWidget(slots_group, 1)

        self._refresh_hw_screens()
        return tab

    # ────────────────────────────────
    # SD卡文件 Tab
    # ────────────────────────────────
    def _build_sdcard_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(8, 8, 8, 8)

        file_row = QHBoxLayout()
        file_row.addWidget(QLabel("文件路径:"))
        self.sdcard_path_edit = QLineEdit("/sdcard/1.mp4")
        file_row.addWidget(self.sdcard_path_edit, 1)
        sdcard_browse = QPushButton("浏览...")
        sdcard_browse.clicked.connect(lambda: self._browse_file(
            self.sdcard_path_edit, "选择视频或图片",
            "视频/图片 (*.mp4 *.avi *.mov *.mkv *.jpg *.jpeg *.png *.bmp);;所有文件 (*.*)"))
        file_row.addWidget(sdcard_browse)
        layout.addLayout(file_row)

        btn_row = QHBoxLayout()
        self.sdcard_start_btn = QPushButton("开始识别")
        self.sdcard_start_btn.setObjectName("startBtn")
        self.sdcard_start_btn.clicked.connect(self._start_sdcard)
        btn_row.addWidget(self.sdcard_start_btn)
        self.sdcard_stop_btn = QPushButton("停止识别")
        self.sdcard_stop_btn.setObjectName("stopBtn")
        self.sdcard_stop_btn.setEnabled(False)
        self.sdcard_stop_btn.clicked.connect(self._stop_sdcard)
        btn_row.addWidget(self.sdcard_stop_btn)
        self.sdcard_fps_label = QLabel("FPS: --")
        self.sdcard_fps_label.setObjectName("fpsLabel")
        btn_row.addWidget(self.sdcard_fps_label)
        self.sdcard_progress_label = QLabel("")
        btn_row.addWidget(self.sdcard_progress_label)
        self.sdcard_prev_btn = QPushButton("◀ 上一张")
        self.sdcard_prev_btn.setEnabled(False)
        self.sdcard_prev_btn.clicked.connect(lambda: self._sdcard_navigate(-1))
        btn_row.addWidget(self.sdcard_prev_btn)
        self.sdcard_next_btn = QPushButton("下一张 ▶")
        self.sdcard_next_btn.setEnabled(False)
        self.sdcard_next_btn.clicked.connect(lambda: self._sdcard_navigate(1))
        btn_row.addWidget(self.sdcard_next_btn)
        self.sdcard_recognize_btn = QPushButton("识别车牌")
        self.sdcard_recognize_btn.setObjectName("startBtn")
        self.sdcard_recognize_btn.setEnabled(False)
        self.sdcard_recognize_btn.clicked.connect(self._start_sdcard)
        btn_row.addWidget(self.sdcard_recognize_btn)
        self.sdcard_tts_check = QCheckBox("播报车牌")
        self.sdcard_tts_check.setToolTip("通过喇叭朗读识别到的车牌号（本地WAV拼接 + aplay）")
        self.sdcard_tts_check.toggled.connect(self._on_tts_toggled)
        btn_row.addWidget(self.sdcard_tts_check)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        # ── 图片识别结果展示区（仅图片模式，视频模式隐藏）──
        self.sdcard_result_scroll = QScrollArea()
        self.sdcard_result_scroll.setWidgetResizable(True)
        self.sdcard_result_scroll.setStyleSheet(
            "QScrollArea { border: 1px solid #45475a; border-radius: 6px; background-color: #11111b; }")
        self.sdcard_result_image = QLabel()
        self.sdcard_result_image.setAlignment(Qt.AlignCenter)
        self.sdcard_result_image.setStyleSheet("background-color: #000; border: none;")
        self.sdcard_result_image.setMinimumHeight(300)
        self.sdcard_result_scroll.setWidget(self.sdcard_result_image)
        self.sdcard_result_scroll.hide()
        layout.addWidget(self.sdcard_result_scroll, 3)

        slots_group = QGroupBox("车牌截取 (连续5帧确认)")
        slots_layout = QGridLayout(slots_group)
        slots_layout.setSpacing(8)
        self.sdcard_slots = []
        for i in range(8):
            slot_frame = QFrame()
            slot_frame.setStyleSheet("QFrame { background-color: #11111b; border: 1px solid #45475a; border-radius: 6px; }")
            slot_v = QVBoxLayout(slot_frame)
            slot_v.setContentsMargins(6, 6, 6, 6)
            slot_v.setSpacing(4)
            img_label = QLabel()
            img_label.setFixedSize(282, 72)
            img_label.setAlignment(Qt.AlignCenter)
            img_label.setStyleSheet("background-color: #000; border: none;")
            slot_v.addWidget(img_label, alignment=Qt.AlignCenter)
            text_label = QLabel("--")
            text_label.setAlignment(Qt.AlignCenter)
            text_label.setStyleSheet("color: #f9e2af; font-size: 13px; font-weight: bold; border: none; background: transparent;")
            slot_v.addWidget(text_label)
            self.sdcard_slots.append({'img': img_label, 'text': text_label})
            slots_layout.addWidget(slot_frame, i // 4, i % 4)
        layout.addWidget(slots_group, 1)

        return tab

    def _start_sdcard(self):
        if not self._ensure_models_loaded():
            return
        if self.sdcard_running:
            return
        path = self.sdcard_path_edit.text().strip()
        if not path or not os.path.isfile(path):
            QMessageBox.critical(self, "错误", f"文件不存在:\n{path}")
            return
        self._stop_sdcard_flag = False
        self.sdcard_running = True
        self.sdcard_start_btn.setEnabled(False)
        self.sdcard_stop_btn.setEnabled(True)
        self.sdcard_recognize_btn.setEnabled(False)
        self.sdcard_prev_btn.setEnabled(False)
        self.sdcard_next_btn.setEnabled(False)
        self.sdcard_fps_label.setText("FPS: --")
        def _sdcard_thread_main():
            # 顶层兜底: worker 任何未捕获异常都打印 traceback 并恢复 UI 状态,
            # 避免线程静默死亡造成"卡死、按钮无响应"的假象
            try:
                self._sdcard_worker()
            except Exception:
                traceback.print_exc()
                self.sdcard_running = False
                self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
                self.run_on_main.emit(lambda: self.sdcard_recognize_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.sdcard_fps_label.setText("FPS: --"))
        self._sdcard_thread = threading.Thread(target=_sdcard_thread_main, daemon=True)
        self._sdcard_thread.start()

    def _stop_sdcard(self):
        self._stop_sdcard_flag = True
        self._reset_tts_state()
        self.sdcard_prev_btn.setEnabled(False)
        self.sdcard_next_btn.setEnabled(False)

    def _sdcard_worker(self):
        path = self.sdcard_path_edit.text().strip()

        # ── 判断文件类型：图片 or 视频 ──
        ext = os.path.splitext(path)[1].lower()
        IMAGE_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}

        if ext in IMAGE_EXTS:
            self._sdcard_worker_image(path)
            return

        self.run_on_main.emit(lambda: self.sdcard_result_scroll.hide())
        self.run_on_main.emit(lambda: self.sdcard_prev_btn.setEnabled(False))
        self.run_on_main.emit(lambda: self.sdcard_next_btn.setEnabled(False))

        cap = None
        gst_handle = 0
        hw_decode = False
        nv12_buf = None
        nv12_stride = 0
        orig_w = orig_h = 0
        total_frames = 0
        fps_video = 30.0
        disp_w, disp_h = 1280, 720
        # GStreamer 硬解函数在下方 DRM 绑定区完成绑定, 此处仅声明局部变量
        # (硬解打开逻辑必须在绑定之后执行)
        gst_open = gst_pull = gst_pull_dmabuf = gst_close = None

        # (硬解打开与软解回退逻辑见下方 DRM 绑定区之后)

        # ── 初始化 DRM 屏幕输出（SD 卡专用）──
        drm_lib = None
        rga_cvt = None        # RGA: BGR→RGB + 缩放 (AI 输入预处理)
        rga_resize = None     # RGA: BGR→BGR 缩放 (渲染预处理)
        rga_cvt_nv12 = None   # RGA: NV12→BGR + 缩放 (硬解帧预处理, memcpy 兜底)
        rga_cvt_nv12_fd = None  # RGA: NV12 dma-buf fd→BGR + 缩放 (零拷贝热路径)
        rga_lock = threading.Lock()   # AI/渲染线程共用 RGA, 串行化单次硬件操作
        try:
            drm_path = DEFAULT_HDMI_LIB
            drm_lib = ctypes.CDLL(drm_path)
            drm_lib.sd_drm_init.argtypes = [ctypes.c_int]
            drm_lib.sd_drm_init.restype = ctypes.c_int
            drm_lib.sd_drm_put_and_show_ex.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
            drm_lib.sd_drm_put_and_show_ex.restype = ctypes.c_int
            # ── RGA 硬件预处理 + 旋转上屏接口 (不依赖 DRM 屏幕初始化结果) ──
            try:
                drm_lib.rga_cvt_resize_bgr_to_rgb.argtypes = [
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
                drm_lib.rga_cvt_resize_bgr_to_rgb.restype = ctypes.c_int
                rga_cvt = drm_lib.rga_cvt_resize_bgr_to_rgb
                drm_lib.rga_resize_bgr.argtypes = [
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
                drm_lib.rga_resize_bgr.restype = ctypes.c_int
                rga_resize = drm_lib.rga_resize_bgr
                drm_lib.sd_drm_put_and_show_rot.argtypes = [
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
                drm_lib.sd_drm_put_and_show_rot.restype = ctypes.c_int
                drm_lib.rga_cvt_nv12_to_bgr.argtypes = [
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
                drm_lib.rga_cvt_nv12_to_bgr.restype = ctypes.c_int
                rga_cvt_nv12 = drm_lib.rga_cvt_nv12_to_bgr
                drm_lib.rga_cvt_nv12_fd_to_bgr.argtypes = [
                    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                    ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
                drm_lib.rga_cvt_nv12_fd_to_bgr.restype = ctypes.c_int
                rga_cvt_nv12_fd = drm_lib.rga_cvt_nv12_fd_to_bgr
            except AttributeError:
                print("[SD卡] 库中缺少 RGA 预处理接口，AI/渲染回退 CPU 路径")
                rga_cvt = None
                rga_resize = None
            # ── GStreamer 硬解接口 (MPP H.264 硬解 → NV12 裸帧) ──
            try:
                drm_lib.gst_dec_open.argtypes = [
                    ctypes.c_char_p,
                    ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
                    ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int),
                    ctypes.POINTER(ctypes.c_int)]
                drm_lib.gst_dec_open.restype = ctypes.c_int
                gst_open = drm_lib.gst_dec_open
                drm_lib.gst_dec_pull_dmabuf.argtypes = [
                    ctypes.c_int,
                    ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int),
                    ctypes.c_int]
                drm_lib.gst_dec_pull_dmabuf.restype = ctypes.c_int
                gst_pull_dmabuf = drm_lib.gst_dec_pull_dmabuf
                drm_lib.gst_dec_pull.argtypes = [
                    ctypes.c_int, ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
                drm_lib.gst_dec_pull.restype = ctypes.c_int
                gst_pull = drm_lib.gst_dec_pull
                drm_lib.gst_dec_close.argtypes = [ctypes.c_int]
                drm_lib.gst_dec_close.restype = None
                gst_close = drm_lib.gst_dec_close
            except AttributeError:
                print("[SD卡] 库中缺少 GStreamer 硬解接口，回退 OpenCV 软解")
            ret = drm_lib.sd_drm_init(1)
            if ret != 0:
                print(f"[SD卡] sd_drm_init(1) 返回 {ret}，尝试 connector 0...")
                ret = drm_lib.sd_drm_init(0)
            if ret != 0:
                print(f"[SD卡] sd_drm_init 返回 {ret}，无屏幕输出")
                drm_lib = None
            else:
                print("[SD卡] SD DRM 屏幕初始化成功")
        except Exception as e:
            print(f"[SD卡] DRM 初始化失败: {e}")
            drm_lib = None

        # ── 优先 GStreamer MPP 硬解 (H.264 → NV12 裸帧, 板端实测 ≈344fps) ──
        if gst_open is not None:
            w = ctypes.c_int(); h = ctypes.c_int()
            f = ctypes.c_double(); t = ctypes.c_int(); st = ctypes.c_int()
            try:
                gst_handle = gst_open(path.encode('utf-8'),
                                      ctypes.byref(w), ctypes.byref(h),
                                      ctypes.byref(f), ctypes.byref(t),
                                      ctypes.byref(st))
                if gst_handle > 0 and w.value > 0 and h.value > 0:
                    orig_w, orig_h = w.value, h.value
                    fps_video = f.value if f.value > 0 else 30.0
                    total_frames = t.value
                    nv12_stride = st.value if st.value >= orig_w else orig_w
                    nv12_buf = np.empty(nv12_stride * orig_h * 3 // 2, dtype=np.uint8)
                    hw_decode = True
                    print(f"[SD卡] MPP 硬解启用: {orig_w}x{orig_h} @ {fps_video:.2f}fps, "
                          f"{total_frames}帧, NV12 stride {nv12_stride}")
                elif gst_handle > 0:
                    gst_close(gst_handle)
                    gst_handle = 0
            except Exception as e:
                print(f"[SD卡] MPP 硬解打开异常, 回退软解: {e}")
                gst_handle = 0

        # ── 回退: OpenCV 软解 ──
        if not hw_decode:
            cap = cv2.VideoCapture(path)
            if not cap.isOpened():
                self.run_on_main.emit(lambda: QMessageBox.critical(self, "错误", f"无法打开文件:\n{path}"))
                self.sdcard_running = False
                self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
                return

            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            fps_video = cap.get(cv2.CAP_PROP_FPS)
            if fps_video <= 0:
                fps_video = 30.0

            # ── 先读一帧获取视频原始分辨率 ──
            ret, first_frame = cap.read()
            if not ret:
                cap.release()
                self.sdcard_running = False
                self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
                return
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)  # 回到第一帧
            orig_h, orig_w = first_frame.shape[:2]

        self.run_on_main.emit(lambda p=total_frames, f=fps_video: self.sdcard_progress_label.setText(
            f"共 {p} 帧 @ {f:.1f}fps"))

        # ====================================================================
        # 共享状态：三线程架构（主解码 → AI推理 → 渲染上屏）
        # ====================================================================
        AI_SKIP = 1
        ai_state = {
            'frame': None,                # 待 AI 处理的 BGR 帧（原分辨率，引用传递）
            'ready': False,
            'latest_results': [],         # BoxSmoother 平滑后的结果
            'raw_results': [],            # 未经平滑的原始结果（供 PlateSlotTracker）
            'feed_frame_id': -1,
            'result_frame_id': -1,
        }
        ai_lock = threading.Lock()
        ai_exit = threading.Event()

        render_state = {
            'buffer': {},                 # 帧缓冲: {frame_id: BGR frame}，渲染线程按 AI 结果帧号取帧对齐
        }
        render_lock = threading.Lock()
        render_event = threading.Event()
        render_exit = threading.Event()
        RENDER_BUF_MAX = 8                # 帧缓冲上限，防内存膨胀（引用传递, 峰值 ≈ 8×单帧, 4K 时约 200MB）

        # ====================================================================
        # AI 子线程（不变）
        # ====================================================================
        def ai_thread_func():
            smoother = BoxSmoother(alpha=0.25, iou_thresh=0.4, history_len=10)
            yolo_buf = np.empty((1, 640, 640, 3), dtype=np.uint8)
            yolo_rgb = np.empty((640, 640, 3), dtype=np.uint8)

            while not ai_exit.is_set():
                frame_bgr = None
                with ai_lock:
                    if ai_state['ready']:
                        frame_bgr = ai_state['frame']
                        frame_id = ai_state.get('feed_frame_id', -1)
                        ai_state['ready'] = False
                if frame_bgr is None:
                    time.sleep(0.002)
                    continue

                try:
                    ow = frame_bgr.shape[1]
                    oh = frame_bgr.shape[0]
                    # RGA 硬件: BGR→RGB + 缩放至 640×640, 取代 cvtColor+resize 双 CPU 操作
                    ok = -1
                    if rga_cvt is not None:
                        with rga_lock:
                            ok = rga_cvt(
                                frame_bgr.ctypes.data_as(ctypes.c_void_p), ow, oh,
                                yolo_rgb.ctypes.data_as(ctypes.c_void_p), 640, 640)
                    if ok != 0:
                        cv2.resize(cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB),
                                   (640, 640), dst=yolo_rgb)
                    yolo_buf[0] = yolo_rgb
                    outputs = self.rknn_det.inference(inputs=[yolo_buf])
                    boxes_list, scores_list, class_ids = decode_yolo_fast(outputs, ow, oh, no=self.det_no)
                    indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                    indices = filter_plate_boxes(boxes_list, scores_list, class_ids, indices)
                    new_results = []

                    if len(indices) > 0:
                        crop_imgs = []
                        valid_boxes = []
                        for idx in np.array(indices).flatten():
                            b = boxes_list[int(idx)]
                            x, y, w, h = b[0], b[1], b[2], b[3]
                            pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                            x1 = max(0, int(x - pad_x))
                            y1 = max(0, int(y - pad_y))
                            x2 = min(ow, int(x + w + pad_x))
                            y2 = min(oh, int(y + h + pad_y))

                            # 行人违法：红框直接入结果，不占用车牌裁剪名额
                            if class_ids[int(idx)] == 1:
                                new_results.append({
                                    'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                                    'text': '行人违法',
                                    'color_bgr': (0, 0, 255),
                                    'color_rgb': (255, 0, 0),
                                    'crop': None,
                                })
                                continue

                            if len(crop_imgs) >= 4:
                                continue
                            crop = frame_bgr[y1:y2, x1:x2]
                            if crop.size > 0:
                                resized_crop = cv2.resize(crop, (94, 24))
                                crop_imgs.append(resized_crop)
                                valid_boxes.append((x1, y1, x2, y2))

                        if len(crop_imgs) > 0:
                            char_logits_list = []
                            color_logits_list = []
                            processed = 0
                            while processed < len(crop_imgs):
                                remain = len(crop_imgs) - processed
                                if remain >= 3:
                                    batch = np.zeros((4, 24, 94, 3), dtype=np.uint8)
                                    take = min(4, remain)
                                    for j in range(take):
                                        batch[j] = crop_imgs[processed + j]
                                    rec_out = self.rknn_rec_b4.inference(inputs=[batch])
                                    for j in range(take):
                                        char_logits_list.append(rec_out[0][j:j + 1])
                                        color_logits_list.append(rec_out[1][j:j + 1])
                                    processed += take
                                else:
                                    img = np.expand_dims(crop_imgs[processed], axis=0)
                                    rec_out = self.rknn_rec_b1.inference(inputs=[img])
                                    char_logits_list.append(rec_out[0])
                                    color_logits_list.append(rec_out[1])
                                    processed += 1

                            for i in range(len(crop_imgs)):
                                raw_text = decode_lprnet_v2(char_logits_list[i])
                                plate_text = rectify_plate_text(raw_text)
                                logits_sq = np.squeeze(color_logits_list[i])
                                exp_logits = np.exp(logits_sq - np.max(logits_sq))
                                ai_probs = exp_logits / np.sum(exp_logits)
                                plate_type = "未知"
                                if len(plate_text) > 0 and plate_text[-1] in ['学', '警', '领', '挂', '使', '港', '澳']:
                                    plate_type = "特殊牌"
                                else:
                                    hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                                    color_bounds = {
                                        0: (np.array([100, 43, 46]), np.array([124, 255, 255])),
                                        1: (np.array([10, 30, 46]), np.array([35, 255, 255])),
                                        3: (np.array([36, 43, 46]), np.array([85, 255, 255])),
                                    }
                                    hsv_counts = np.zeros(4)
                                    for cid, (lo, hi) in color_bounds.items():
                                        mask = cv2.inRange(hsv, lo, hi)
                                        hsv_counts[cid] = cv2.countNonZero(mask)
                                    total_hsv = np.sum(hsv_counts)
                                    hsv_probs = np.zeros(4)
                                    if total_hsv > 0:
                                        hsv_probs = hsv_counts / total_hsv
                                    if total_hsv > 100:
                                        final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                                    else:
                                        final_probs = ai_probs
                                    color_id = int(np.argmax(final_probs))
                                    plate_type = PLATE_COLORS_MAP.get(color_id, "未知")
                                display_text = f"{plate_text}({plate_type})"
                                formatted, valid_text = PlateSlotTracker._validate_and_format(display_text)
                                if not valid_text:
                                    continue
                                bx1, by1, bx2, by2 = valid_boxes[i]
                                color_bgr = PLATE_COLORS_BGR.get(plate_type, (0, 255, 0))
                                color_rgb = PLATE_COLORS_RGB.get(plate_type, (0, 255, 0))
                                new_results.append({
                                    'x1': bx1, 'y1': by1, 'x2': bx2, 'y2': by2,
                                    'text': display_text,
                                    'color_bgr': color_bgr,
                                    'color_rgb': color_rgb,
                                    'crop': crop_imgs[i],
                                })

                    with ai_lock:
                        ai_state['raw_results'] = new_results

                    smoothed = smoother.update(new_results)
                    with ai_lock:
                        ai_state['latest_results'] = smoothed
                        ai_state['result_frame_id'] = frame_id
                except Exception as e:
                    print(f"[SD卡 AI线程] 异常: {e}")

        # ====================================================================
        # 渲染子线程：resize→画框→PIL文字→旋转90°→RGA上屏
        # ====================================================================
        def render_thread_func():
            slot_tracker = PlateSlotTracker()
            resize_buf = np.empty((disp_h, disp_w, 3), dtype=np.uint8)
            # 硬解路径: 解码线程已输出 1280×720 BGR, AI 结果坐标即显示坐标;
            # 软解路径: AI 结果坐标为原始分辨率, 需按比例缩放到显示分辨率
            if hw_decode:
                sx, sy = 1.0, 1.0
            else:
                sx = disp_w / orig_w
                sy = disp_h / orig_h
            last_result_id = -1           # 上次已消费的 AI 结果帧号

            while not render_exit.is_set():
                if not render_event.wait(timeout=0.1):
                    continue
                render_event.clear()

                # ── 取 AI 最新结果（含对应帧号）──
                with ai_lock:
                    result_id = ai_state['result_frame_id']
                    results = list(ai_state['latest_results'])
                    raw = list(ai_state.get('raw_results', []))

                # 结果未更新则保持当前上屏画面（画面定格在该结果帧，避免漂移）
                if result_id == last_result_id or result_id < 0:
                    continue
                last_result_id = result_id

                # ── 按结果帧号取画面帧：帧 N 算完，帧 N(+1) 上屏，标注与画面贴合 ──
                frame_bgr = None
                with render_lock:
                    buf = render_state['buffer']
                    ids = sorted(buf.keys())
                    if ids:
                        if result_id in buf:
                            pick = result_id
                        else:
                            after = [i for i in ids if i >= result_id]
                            pick = after[0] if after else ids[-1]
                        frame_bgr = buf[pick]
                    # 清理已消费的旧帧（保留 result_id 附近几帧，供后续匹配）
                    for k in list(buf.keys()):
                        if k < result_id - 2:
                            del buf[k]

                if frame_bgr is None:
                    continue

                # ── 1. 绘制画布准备 ──
                # 硬解路径: 帧已是 1280×720 BGR, 拷贝一份绘制 (共享帧另供 AI 线程
                # 裁剪, 绘制改动不得污染 AI 输入); 软解路径: RGA 硬件缩放至 720p
                if hw_decode:
                    draw_buf = frame_bgr.copy()
                else:
                    fh, fw = frame_bgr.shape[:2]
                    ok = -1
                    if rga_resize is not None:
                        with rga_lock:
                            ok = rga_resize(
                                frame_bgr.ctypes.data_as(ctypes.c_void_p), fw, fh,
                                resize_buf.ctypes.data_as(ctypes.c_void_p), disp_w, disp_h)
                    if ok != 0:
                        cv2.resize(frame_bgr, (disp_w, disp_h), dst=resize_buf)
                    draw_buf = resize_buf

                # ── 2. 在横屏 buffer 上画框 + 文字（先画再旋转，文字方向正确）──
                for res in results:
                    x1 = int(res['x1'] * sx)
                    y1 = int(res['y1'] * sy)
                    x2 = int(res['x2'] * sx)
                    y2 = int(res['y2'] * sy)
                    x1 = max(0, min(disp_w - 1, x1))
                    y1 = max(0, min(disp_h - 1, y1))
                    x2 = max(0, min(disp_w - 1, x2))
                    y2 = max(0, min(disp_h - 1, y2))

                    cv2.rectangle(draw_buf, (x1, y1), (x2, y2), res['color_bgr'], 3)

                    # ── PIL 文字（BGR→RGB→draw→RGB→BGR）──
                    text_y = max(0, y1 - 38)
                    roi_x1 = max(0, x1)
                    roi_x2 = min(disp_w, x1 + 400)
                    roi_y1 = max(0, text_y)
                    roi_y2 = max(roi_y1 + 1, y1)
                    if roi_y2 > roi_y1 and roi_x2 > roi_x1:
                        roi = draw_buf[roi_y1:roi_y2, roi_x1:roi_x2].copy()
                        roi_rgb = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)
                        roi_pil = Image.fromarray(roi_rgb)
                        draw_pil = ImageDraw.Draw(roi_pil)
                        draw_pil.text((0, 0), res['text'], font=self.font, fill=res['color_rgb'])
                        draw_buf[roi_y1:roi_y2, roi_x1:roi_x2] = cv2.cvtColor(
                            np.array(roi_pil), cv2.COLOR_RGB2BGR)

                # ── 3. RGA 上屏：BGR888→BGRA8888 + 缩放 + 旋转90° 单次硬件完成 ──
                #    (取代 cv2.rotate + 二次 RGA 上屏的两步操作)
                if drm_lib is not None:
                    try:
                        drm_lib.sd_drm_put_and_show_rot(
                            draw_buf.ctypes.data_as(ctypes.c_void_p),
                            disp_w, disp_h, 1)
                    except Exception:
                        pass

                # ── PlateSlotTracker + UI 更新（raw 已在顶部取好）──
                slot_detections = [(r['text'], r['crop'], r['x1'], r['y1'], r['x2'], r['y2'])
                                  for r in raw if r.get('crop') is not None]
                slot_tracker.update(slot_detections)
                slots_snapshot = list(slot_tracker.slots)
                self.run_on_main.emit(lambda ss=slots_snapshot, sl=self.sdcard_slots:
                    self._update_plate_slots(ss, sl))

        # ── 启动 AI 和渲染子线程 ──
        ai_thread = threading.Thread(target=ai_thread_func, daemon=True)
        ai_thread.start()
        render_thread = threading.Thread(target=render_thread_func, daemon=True)
        render_thread.start()

        # ====================================================================
        # 主解码循环：只负责 cap.read() + 投喂 AI + 投喂渲染
        # ====================================================================
        def _nv12_to_bgr_numpy(nv12, w, h, stride, out):
            """CPU 兜底: NV12 → BGR + 缩放 (仅当 RGA 转换失败时使用)"""
            y = nv12[:stride * h].reshape(h, stride)[:, :w].astype(np.float32)
            uv = nv12[stride * h:stride * h * 3 // 2].reshape(
                h // 2, stride // 2, 2)[:, :w // 2, :]
            u = np.repeat(np.repeat(uv[..., 0], 2, axis=0), 2, axis=1).astype(np.float32)
            v = np.repeat(np.repeat(uv[..., 1], 2, axis=0), 2, axis=1).astype(np.float32)
            y -= 16.0; u -= 128.0; v -= 128.0
            bgr_full = np.empty((h, w, 3), dtype=np.uint8)
            bgr_full[..., 0] = np.clip(y + 1.732446 * u, 0, 255).astype(np.uint8)
            bgr_full[..., 1] = np.clip(y - 0.698001 * v - 0.337633 * u, 0, 255).astype(np.uint8)
            bgr_full[..., 2] = np.clip(y + 1.370705 * v, 0, 255).astype(np.uint8)
            cv2.resize(bgr_full, (out.shape[1], out.shape[0]), dst=out)

        frame_count = 0
        ai_frame_idx = -1
        frame_interval = 1.0 / fps_video  # 帧率上限 = 原始视频帧率
        fps_timer = time.perf_counter()

        try:
            while not self._stop_sdcard_flag:
                t_frame_start = time.perf_counter()

                if hw_decode:
                    # ── 硬解: GStreamer pull dma-buf fd → RGA 零拷贝转 BGR 1280×720 ──
                    # (MPP 输出为无缓存 DRM 内存, CPU memcpy 仅 ~160MB/s,
                    #  必须经 RGA 硬件 fd 直读, 否则全管线 ~45fps)
                    fd = ctypes.c_int(); fsz = ctypes.c_int()
                    got = gst_pull_dmabuf(gst_handle, ctypes.byref(fd),
                                          ctypes.byref(fsz), 30)
                    if got == -2:          # 视频播完 (EOS)
                        if total_frames > 0:
                            self.run_on_main.emit(lambda: self.sdcard_progress_label.setText("播放完毕"))
                        break
                    if got == -3:          # 解码错误
                        print("[SD卡] MPP 硬解出错")
                        break
                    if got < 0:            # -1: 暂无帧; -4: 罕见非 dma-buf, 走 memcpy 兜底
                        if got == -4:
                            got2 = gst_pull(gst_handle,
                                            nv12_buf.ctypes.data_as(ctypes.c_void_p),
                                            nv12_buf.size, 30)
                            if got2 <= 0:
                                continue
                            frame_bgr = np.empty((disp_h, disp_w, 3), dtype=np.uint8)
                            ok = -1
                            if rga_cvt_nv12 is not None:
                                with rga_lock:
                                    ok = rga_cvt_nv12(
                                        nv12_buf.ctypes.data_as(ctypes.c_void_p),
                                        orig_w, orig_h, nv12_stride,
                                        frame_bgr.ctypes.data_as(ctypes.c_void_p),
                                        disp_w, disp_h)
                            if ok != 0:
                                _nv12_to_bgr_numpy(nv12_buf, orig_w, orig_h,
                                                   nv12_stride, frame_bgr)
                        else:
                            continue
                    else:
                        frame_bgr = np.empty((disp_h, disp_w, 3), dtype=np.uint8)
                        ok = -1
                        if rga_cvt_nv12_fd is not None:
                            with rga_lock:
                                ok = rga_cvt_nv12_fd(
                                    fd.value, orig_w, orig_h, nv12_stride,
                                    frame_bgr.ctypes.data_as(ctypes.c_void_p),
                                    disp_w, disp_h)
                        if ok != 0:
                            print("[SD卡] RGA fd 转换失败, 丢帧")
                            continue
                else:
                    ret, frame_bgr = cap.read()
                    if not ret:
                        if total_frames > 0:
                            self.run_on_main.emit(lambda: self.sdcard_progress_label.setText("播放完毕"))
                        break

                # ── 投喂 AI 线程（跳帧，引用传递）──
                # cap.read() 每次返回全新内存的 ndarray, AI 线程持有引用期间
                # 内容不会被改写, 无需 copy (省一次全帧 memcpy)
                ai_frame_idx += 1
                if ai_frame_idx % (AI_SKIP + 1) == 0:
                    with ai_lock:
                        if not ai_state['ready']:
                            ai_state['frame'] = frame_bgr
                            ai_state['ready'] = True
                            ai_state['feed_frame_id'] = ai_frame_idx

                # ── 投喂渲染帧缓冲（带帧号，渲染线程按 AI 结果帧号取帧对齐）──
                # 引用传递: 每帧内存独立, 由 RENDER_BUF_MAX 上限回收 (省一次全帧 memcpy)
                with render_lock:
                    render_state['buffer'][ai_frame_idx] = frame_bgr
                    while len(render_state['buffer']) > RENDER_BUF_MAX:
                        oldest = min(render_state['buffer'].keys())
                        del render_state['buffer'][oldest]
                render_event.set()

                # ── FPS 与进度统计 ──
                frame_count += 1
                now = time.perf_counter()
                elapsed = now - fps_timer
                if elapsed >= 1.0:
                    fps_display = frame_count / elapsed
                    frame_count = 0
                    fps_timer = now
                    self.fps_signal.emit(fps_display)
                    if total_frames > 0:
                        pos = ai_frame_idx + 1
                        pct = min(100, pos * 100 // total_frames)
                        self.run_on_main.emit(lambda p=pct, pos=pos, tot=total_frames:
                            self.sdcard_progress_label.setText(f"{pos}/{tot} ({p}%)"))

                # ── 帧率限制：不能超过原始视频帧率 ──
                t_elapsed = time.perf_counter() - t_frame_start
                t_sleep = frame_interval - t_elapsed
                if t_sleep > 0:
                    time.sleep(t_sleep)

        except Exception as e:
            print(f"SD卡识别线程异常: {e}")
        finally:
            render_exit.set()
            render_event.set()
            ai_exit.set()
            ai_thread.join(timeout=2.0)
            render_thread.join(timeout=2.0)
            if gst_handle > 0 and gst_close is not None:
                try:
                    gst_close(gst_handle)
                except Exception:
                    pass
            if cap is not None:
                cap.release()
            if drm_lib is not None:
                try:
                    drm_lib.sd_drm_cleanup()
                except Exception:
                    pass
            self.sdcard_running = False
            self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
            self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
            self.run_on_main.emit(lambda: self.sdcard_fps_label.setText("FPS: --"))

    # ====================================================================
    # SD卡 图片模式：单帧车牌识别 + 界面展示（不推流到 DRM 小屏幕）
    # ====================================================================
    def _sdcard_worker_image(self, path):
        """读取图片 → YOLO检测 → LPR识别 → 标注原图 → 展示在 UI + 填充8槽位"""
        frame_bgr = cv2.imread(path)
        if frame_bgr is None:
            self.run_on_main.emit(lambda: QMessageBox.critical(self, "错误",
                f"无法读取图片:\n{path}"))
            self.sdcard_running = False
            self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
            self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
            return

        self.run_on_main.emit(lambda: self.sdcard_result_scroll.show())

        # ── 清除上一张图片的车牌槽位 ──
        self.run_on_main.emit(lambda: [w['img'].clear() or w['text'].setText("--") for w in self.sdcard_slots])

        try:
            orig_h, orig_w = frame_bgr.shape[:2]

            # ── 1. YOLO 检测 ──
            yolo_input = np.expand_dims(
                cv2.cvtColor(cv2.resize(frame_bgr, (640, 640)), cv2.COLOR_BGR2RGB),
                axis=0)
            outputs = self.rknn_det.inference(inputs=[yolo_input])

            new_results = []
            if outputs is not None:
                boxes_list, scores_list, class_ids = decode_yolo_fast(outputs, orig_w, orig_h, no=self.det_no)
                if len(boxes_list) > 0:
                    indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                    indices = filter_plate_boxes(boxes_list, scores_list, class_ids, indices)
                else:
                    indices = np.array([])

                if len(indices) > 0:
                    crop_imgs, valid_boxes = [], []
                    for idx in np.array(indices).flatten():
                        b = boxes_list[int(idx)]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                        x1 = max(0, int(x - pad_x))
                        y1 = max(0, int(y - pad_y))
                        x2 = min(orig_w, int(x + w + pad_x))
                        y2 = min(orig_h, int(y + h + pad_y))

                        # 行人违法：红框直接入结果，不占用车牌裁剪名额
                        if class_ids[int(idx)] == 1:
                            new_results.append({
                                'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                                'text': '行人违法',
                                'color_bgr': (0, 0, 255),
                                'color_rgb': (255, 0, 0),
                                'crop': None,
                            })
                            continue

                        if len(crop_imgs) >= 4:
                            continue
                        crop = frame_bgr[y1:y2, x1:x2]
                        if crop.size > 0:
                            crop_imgs.append(cv2.resize(crop, (94, 24)))
                            valid_boxes.append((x1, y1, x2, y2))

                    # ── 2. LPR 车牌识别 ──
                    if crop_imgs:
                        char_logits_list, color_logits_list = [], []
                        processed = 0
                        while processed < len(crop_imgs):
                            remain = len(crop_imgs) - processed
                            if remain >= 3:
                                batch = np.zeros((4, 24, 94, 3), dtype=np.uint8)
                                take = min(4, remain)
                                for j in range(take):
                                    batch[j] = crop_imgs[processed + j]
                                rec_out = self.rknn_rec_b4.inference(inputs=[batch])
                                for j in range(take):
                                    char_logits_list.append(rec_out[0][j:j + 1])
                                    color_logits_list.append(rec_out[1][j:j + 1])
                                processed += take
                            else:
                                img = np.expand_dims(crop_imgs[processed], axis=0)
                                rec_out = self.rknn_rec_b1.inference(inputs=[img])
                                char_logits_list.append(rec_out[0])
                                color_logits_list.append(rec_out[1])
                                processed += 1

                        for i in range(len(crop_imgs)):
                            raw_text = decode_lprnet_v2(char_logits_list[i])
                            plate_text = rectify_plate_text(raw_text)

                            logits_sq = np.squeeze(color_logits_list[i])
                            exp_logits = np.exp(logits_sq - np.max(logits_sq))
                            ai_probs = exp_logits / np.sum(exp_logits)

                            plate_type = "未知"
                            if len(plate_text) > 0 and plate_text[-1] in \
                                    ['学', '警', '领', '挂', '使', '港', '澳']:
                                plate_type = "特殊牌"
                            else:
                                hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                                color_bounds = {
                                    0: (np.array([100, 43, 46]), np.array([124, 255, 255])),
                                    1: (np.array([10, 30, 46]),  np.array([35, 255, 255])),
                                    3: (np.array([36, 43, 46]),  np.array([85, 255, 255])),
                                }
                                hsv_counts = np.zeros(4)
                                for cid, (lo, hi) in color_bounds.items():
                                    mask = cv2.inRange(hsv, lo, hi)
                                    hsv_counts[cid] = cv2.countNonZero(mask)
                                total_hsv = np.sum(hsv_counts)
                                hsv_probs = np.zeros(4)
                                if total_hsv > 0:
                                    hsv_probs = hsv_counts / total_hsv
                                if total_hsv > 100:
                                    final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                                else:
                                    final_probs = ai_probs
                                color_id = int(np.argmax(final_probs))
                                plate_type = PLATE_COLORS_MAP.get(color_id, "未知")

                            display_text = f"{plate_text}({plate_type})"
                            formatted, valid_text = PlateSlotTracker._validate_and_format(
                                display_text)
                            if not valid_text:
                                continue
                            bx1, by1, bx2, by2 = valid_boxes[i]
                            color_bgr = PLATE_COLORS_BGR.get(plate_type, (0, 255, 0))
                            color_rgb = PLATE_COLORS_RGB.get(plate_type, (0, 255, 0))
                            new_results.append({
                                'x1': bx1, 'y1': by1, 'x2': bx2, 'y2': by2,
                                'text': display_text,
                                'color_bgr': color_bgr,
                                'color_rgb': color_rgb,
                                'crop': crop_imgs[i],
                            })

            # ── 3. 在原图上绘制标注 ──
            annotated = frame_bgr.copy()
            for res in new_results:
                cv2.rectangle(annotated,
                              (res['x1'], res['y1']), (res['x2'], res['y2']),
                              res['color_bgr'], 3)

            if new_results:
                img_pil = Image.fromarray(cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB))
                draw_pil = ImageDraw.Draw(img_pil)
                for res in new_results:
                    text_y = max(0, res['y1'] - 35)
                    draw_pil.text((res['x1'], text_y), res['text'],
                                  font=self.font, fill=res['color_rgb'])
                annotated = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)

            # ── 4. 显示到 UI ──
            h, w = annotated.shape[:2]
            rgb = cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB)
            qimg = QImage(rgb.data, w, h, w * 3, QImage.Format_RGB888).copy()
            pixmap = QPixmap.fromImage(qimg)
            target_size = self.sdcard_result_image.size()
            if target_size.width() > 0:
                scaled = pixmap.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            else:
                scaled = pixmap
            self.run_on_main.emit(lambda p=scaled: self.sdcard_result_image.setPixmap(p))

            # ── 5. 填充车牌槽位（PlateSlotTracker 需 5 帧确认，单图循环 5 次）──
            slot_tracker = PlateSlotTracker()
            slot_detections = [
                (r['text'], r['crop'], r['x1'], r['y1'], r['x2'], r['y2'])
                for r in new_results if r.get('crop') is not None
            ]
            for _ in range(5):
                slot_tracker.update(slot_detections)
            slots_snapshot = list(slot_tracker.slots)
            self.run_on_main.emit(lambda ss=slots_snapshot, sl=self.sdcard_slots:
                self._update_plate_slots(ss, sl))

            print(f"[SD卡图片] 识别完成，发现 {len(new_results)} 个车牌")

        except Exception as e:
            print(f"[SD卡图片] 异常: {e}")
            import traceback
            traceback.print_exc()
        finally:
            self.sdcard_running = False
            self.run_on_main.emit(lambda: self.sdcard_start_btn.setEnabled(True))
            self.run_on_main.emit(lambda: self.sdcard_stop_btn.setEnabled(False))
            self.run_on_main.emit(lambda: self.sdcard_recognize_btn.setEnabled(True))
            # 图片模式：检查同目录是否有多张图片，有则启用翻页按钮
            folder = os.path.dirname(path)
            IMG_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}
            try:
                imgs = [f for f in os.listdir(folder)
                        if os.path.splitext(f)[1].lower() in IMG_EXTS]
                has_multiple = len(imgs) > 1
            except Exception:
                has_multiple = False
            self.run_on_main.emit(lambda h=has_multiple:
                self.sdcard_prev_btn.setEnabled(h))
            self.run_on_main.emit(lambda h=has_multiple:
                self.sdcard_next_btn.setEnabled(h))

    def _sdcard_navigate(self, direction):
        """在图片文件夹中切换到上一张/下一张图片（仅显示，不自动识别）"""
        current_path = self.sdcard_path_edit.text().strip()
        folder = os.path.dirname(current_path)
        if not os.path.isdir(folder):
            return

        IMG_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}
        try:
            images = sorted([
                f for f in os.listdir(folder)
                if os.path.splitext(f)[1].lower() in IMG_EXTS
            ])
        except Exception:
            return

        if not images:
            return

        current_name = os.path.basename(current_path)
        try:
            idx = images.index(current_name)
        except ValueError:
            idx = 0

        new_idx = idx + direction
        if new_idx < 0 or new_idx >= len(images):
            return  # 已是边界

        new_path = os.path.join(folder, images[new_idx])
        self.sdcard_path_edit.setText(new_path)

        # 清除上一张的车牌槽位
        for w in self.sdcard_slots:
            w['img'].clear()
            w['text'].setText("--")

        # 只显示图片，不识别
        self._sdcard_display_image_only(new_path)

        # 更新导航按钮状态
        has_prev = new_idx > 0
        has_next = new_idx < len(images) - 1
        self.sdcard_prev_btn.setEnabled(has_prev)
        self.sdcard_next_btn.setEnabled(has_next)
        self.sdcard_recognize_btn.setEnabled(True)

    def _sdcard_display_image_only(self, path):
        """仅显示图片，不做识别"""
        frame_bgr = cv2.imread(path)
        if frame_bgr is None:
            return
        h, w = frame_bgr.shape[:2]
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        qimg = QImage(rgb.data, w, h, w * 3, QImage.Format_RGB888).copy()
        pixmap = QPixmap.fromImage(qimg)
        target_size = self.sdcard_result_image.size()
        if target_size.width() > 0:
            scaled = pixmap.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        else:
            scaled = pixmap
        self.sdcard_result_image.setPixmap(scaled)
        self.sdcard_result_scroll.show()

    # ====================================================================
    # 行人违法识别 Tab（SD 卡图片输入 → 只识别 class 1 行人违法 → UI + DSI 推流）
    # ====================================================================
    def _build_pedestrian_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(8)

        # ── 文件路径 ──
        file_row = QHBoxLayout()
        file_row.addWidget(QLabel("图片路径:"))
        self.pedestrian_path_edit = QLineEdit("/sdcard/1.jpg")
        file_row.addWidget(self.pedestrian_path_edit, 1)
        ped_browse = QPushButton("浏览...")
        ped_browse.clicked.connect(lambda: self._browse_file(
            self.pedestrian_path_edit, "选择行人违法图片",
            "图片 (*.jpg *.jpeg *.png *.bmp);;所有文件 (*.*)"))
        file_row.addWidget(ped_browse)
        layout.addLayout(file_row)

        # ── 按钮行 ──
        btn_row = QHBoxLayout()
        self.pedestrian_start_btn = QPushButton("开始识别")
        self.pedestrian_start_btn.setObjectName("startBtn")
        self.pedestrian_start_btn.clicked.connect(self._start_pedestrian)
        btn_row.addWidget(self.pedestrian_start_btn)
        self.pedestrian_stop_btn = QPushButton("停止识别")
        self.pedestrian_stop_btn.setObjectName("stopBtn")
        self.pedestrian_stop_btn.setEnabled(False)
        self.pedestrian_stop_btn.clicked.connect(self._stop_pedestrian)
        btn_row.addWidget(self.pedestrian_stop_btn)
        self.pedestrian_prev_btn = QPushButton("◀ 上一张")
        self.pedestrian_prev_btn.setEnabled(False)
        self.pedestrian_prev_btn.clicked.connect(lambda: self._pedestrian_navigate(-1))
        btn_row.addWidget(self.pedestrian_prev_btn)
        self.pedestrian_next_btn = QPushButton("下一张 ▶")
        self.pedestrian_next_btn.setEnabled(False)
        self.pedestrian_next_btn.clicked.connect(lambda: self._pedestrian_navigate(1))
        btn_row.addWidget(self.pedestrian_next_btn)
        self.pedestrian_count_label = QLabel("检测到: --")
        self.pedestrian_count_label.setObjectName("plateLabel")
        btn_row.addWidget(self.pedestrian_count_label)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        # ── 结果图显示区 ──
        self.pedestrian_result_scroll = QScrollArea()
        self.pedestrian_result_scroll.setWidgetResizable(True)
        self.pedestrian_result_scroll.setStyleSheet(
            "QScrollArea { border: 1px solid #45475a; border-radius: 6px; background-color: #11111b; }")
        self.pedestrian_result_image = QLabel()
        self.pedestrian_result_image.setAlignment(Qt.AlignCenter)
        self.pedestrian_result_image.setStyleSheet("background-color: #000; border: none;")
        self.pedestrian_result_image.setMinimumHeight(400)
        self.pedestrian_result_scroll.setWidget(self.pedestrian_result_image)
        layout.addWidget(self.pedestrian_result_scroll, 1)

        return tab

    def _start_pedestrian(self):
        if not self._ensure_models_loaded():
            return
        if self.pedestrian_running:
            return
        path = self.pedestrian_path_edit.text().strip()
        if not path or not os.path.isfile(path):
            QMessageBox.critical(self, "错误", f"文件不存在:\n{path}")
            return
        self._stop_pedestrian_flag = False
        self.pedestrian_running = True
        self.pedestrian_start_btn.setEnabled(False)
        self.pedestrian_stop_btn.setEnabled(True)
        self.pedestrian_prev_btn.setEnabled(False)
        self.pedestrian_next_btn.setEnabled(False)
        self._pedestrian_thread = threading.Thread(target=self._pedestrian_worker, daemon=True)
        self._pedestrian_thread.start()

    def _stop_pedestrian(self):
        self._stop_pedestrian_flag = True

    def _pedestrian_drm_init(self):
        """初始化 DSI 小屏输出（复用 SD 卡链路的 sd_drm_* 接口）"""
        drm_lib = None
        try:
            drm_lib = ctypes.CDLL(DEFAULT_HDMI_LIB)
            drm_lib.sd_drm_init.argtypes = [ctypes.c_int]
            drm_lib.sd_drm_init.restype = ctypes.c_int
            drm_lib.sd_drm_put_and_show_ex.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
            drm_lib.sd_drm_put_and_show_ex.restype = ctypes.c_int
            ret = drm_lib.sd_drm_init(1)   # DSI 小屏通常是第 2 个 connector
            if ret != 0:
                print(f"[行人违法] sd_drm_init(1) 返回 {ret}，尝试 connector 0...")
                ret = drm_lib.sd_drm_init(0)
            if ret != 0:
                print(f"[行人违法] sd_drm_init 返回 {ret}，无屏幕输出")
                drm_lib = None
            else:
                print("[行人违法] DSI 屏幕初始化成功")
        except Exception as e:
            print(f"[行人违法] DRM 初始化失败: {e}")
            drm_lib = None
        return drm_lib

    def _pedestrian_annotate(self, frame_bgr, ped_boxes):
        """在原图上画红框 + '行人违法' 文字，返回标注图"""
        annotated = frame_bgr.copy()
        for (x1, y1, x2, y2) in ped_boxes:
            cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 0, 255), 3)
        if ped_boxes:
            img_pil = Image.fromarray(cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB))
            draw = ImageDraw.Draw(img_pil)
            for (x1, y1, x2, y2) in ped_boxes:
                text_y = max(0, y1 - 35)
                draw.text((x1, text_y), "行人违法", font=self.font, fill=(255, 0, 0))
            annotated = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        return annotated

    def _pedestrian_display(self, annotated):
        """标注图显示到 UI"""
        h, w = annotated.shape[:2]
        rgb = cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB)
        qimg = QImage(rgb.data, w, h, w * 3, QImage.Format_RGB888).copy()
        pixmap = QPixmap.fromImage(qimg)
        target_size = self.pedestrian_result_image.size()
        if target_size.width() > 0:
            scaled = pixmap.scaled(target_size, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        else:
            scaled = pixmap
        self.run_on_main.emit(lambda p=scaled: self.pedestrian_result_image.setPixmap(p))

    def _pedestrian_push_dsi(self, annotated, drm_lib):
        """推流到 DSI 小屏：resize 1280x720 → 旋转 90° → RGA 上屏"""
        if drm_lib is None:
            return
        try:
            disp = cv2.resize(annotated, (1280, 720))
            rotated = cv2.rotate(disp, cv2.ROTATE_90_CLOCKWISE)  # 720x1280
            contig = np.ascontiguousarray(rotated)
            drm_lib.sd_drm_put_and_show_ex(
                contig.ctypes.data_as(ctypes.c_void_p), 720, 1280)
        except Exception as e:
            print(f"[行人违法] DSI 推流失败: {e}")

    def _pedestrian_worker(self):
        path = self.pedestrian_path_edit.text().strip()
        frame_bgr = cv2.imread(path)
        if frame_bgr is None:
            self.run_on_main.emit(lambda: QMessageBox.critical(
                self, "错误", f"无法读取图片:\n{path}"))
            self._pedestrian_finish(path)
            return

        drm_lib = self._pedestrian_drm_init()

        try:
            orig_h, orig_w = frame_bgr.shape[:2]

            # ── 1. YOLO 检测（单类别行人违法专用模型，所有框均为行人违法）──
            yolo_input = np.expand_dims(
                cv2.cvtColor(cv2.resize(frame_bgr, (640, 640)), cv2.COLOR_BGR2RGB),
                axis=0)
            outputs = self.rknn_det_pedestrian.inference(inputs=[yolo_input])

            ped_boxes = []   # 原分辨率坐标 [x1, y1, x2, y2]
            if outputs is not None:
                boxes_list, scores_list, _ = decode_yolo_fast(
                    outputs, orig_w, orig_h,
                    no=PEDESTRIAN_NO, cls_offset=PEDESTRIAN_CLS_OFFSET)
                if len(boxes_list) > 0:
                    indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                else:
                    indices = np.array([])
                if len(indices) > 0:
                    for idx in np.array(indices).flatten():
                        b = boxes_list[int(idx)]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                        x1 = max(0, int(x - pad_x))
                        y1 = max(0, int(y - pad_y))
                        x2 = min(orig_w, int(x + w + pad_x))
                        y2 = min(orig_h, int(y + h + pad_y))
                        ped_boxes.append((x1, y1, x2, y2))

            # ── 2. 标注 ──
            annotated = self._pedestrian_annotate(frame_bgr, ped_boxes)

            # ── 3. UI 显示 + 计数 ──
            self._pedestrian_display(annotated)
            count = len(ped_boxes)
            self.run_on_main.emit(lambda c=count:
                self.pedestrian_count_label.setText(f"检测到 {c} 个行人违法"))

            # ── 4. DSI 推流 ──
            self._pedestrian_push_dsi(annotated, drm_lib)

        except Exception as e:
            print(f"[行人违法] 异常: {e}")
            import traceback
            traceback.print_exc()
        finally:
            if drm_lib is not None:
                try:
                    drm_lib.sd_drm_cleanup()
                except Exception:
                    pass
            self._pedestrian_finish(path)

    def _pedestrian_finish(self, path=None):
        self.pedestrian_running = False
        self.run_on_main.emit(lambda: self.pedestrian_start_btn.setEnabled(True))
        self.run_on_main.emit(lambda: self.pedestrian_stop_btn.setEnabled(False))
        # 检查同目录是否有多张图片，有则启用翻页
        has_multiple = False
        if path:
            folder = os.path.dirname(path)
            IMG_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}
            try:
                imgs = [f for f in os.listdir(folder)
                        if os.path.splitext(f)[1].lower() in IMG_EXTS]
                has_multiple = len(imgs) > 1
            except Exception:
                has_multiple = False
        self.run_on_main.emit(lambda h=has_multiple:
            self.pedestrian_prev_btn.setEnabled(h))
        self.run_on_main.emit(lambda h=has_multiple:
            self.pedestrian_next_btn.setEnabled(h))

    def _pedestrian_navigate(self, direction):
        """在图片文件夹中切换到上一张/下一张并自动识别"""
        current_path = self.pedestrian_path_edit.text().strip()
        folder = os.path.dirname(current_path)
        if not os.path.isdir(folder):
            return
        IMG_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'}
        try:
            images = sorted([
                f for f in os.listdir(folder)
                if os.path.splitext(f)[1].lower() in IMG_EXTS
            ])
        except Exception:
            return
        if not images:
            return
        current_name = os.path.basename(current_path)
        try:
            idx = images.index(current_name)
        except ValueError:
            idx = 0
        new_idx = idx + direction
        if new_idx < 0 or new_idx >= len(images):
            return
        new_path = os.path.join(folder, images[new_idx])
        self.pedestrian_path_edit.setText(new_path)
        self._start_pedestrian()

    # ====================================================================
    # TTS 语音播报（espeak-ng 中文朗读车牌号）
    # ====================================================================
    def _on_tts_toggled(self, checked):
        self._tts_enabled = checked
        if checked:
            if hasattr(self, '_tts_alsa_device'):
                del self._tts_alsa_device
        else:
            self._tts_queue.clear()
            self._tts_speaking = False
            self._tts_current_plate = None
        # 同步其他 Tab 中的 TTS 复选框状态
        for attr in ['sdcard_tts_check', 'camera_tts_check']:
            other = getattr(self, attr, None)
            if other is not None and other.isChecked() != checked:
                other.blockSignals(True)
                other.setChecked(checked)
                other.blockSignals(False)

    def _tts_maybe_announce(self, slots_data):
        """单牌串行播报：帧稳定性门槛 + 编辑距离去重"""
        if not self._tts_enabled:
            return

        now = time.time()

        # 1. 收集当前画面中的车牌号（PlateSlotTracker 已通过 5 帧确认）
        current_plates = set()
        for slot_info in slots_data:
            if slot_info is None:
                continue
            full_text = slot_info.get('text', '')
            if not full_text:
                continue
            core = full_text
            if '(' in core and core.endswith(')'):
                core = core[:core.rindex('(')]
            if not core or core == '--':
                continue
            current_plates.add(core)

        # 2. 更新连续出现计数器
        was_empty = len(self._tts_consecutive) == 0
        # warm-start 冷却：首次或清空后 15 秒内不再触发预热，防止 track 全部清理后立即重播
        allow_warm = was_empty and (now - self._tts_warm_start_ts > 15.0)
        if allow_warm:
            self._tts_warm_start_ts = now

        for plate in list(self._tts_consecutive.keys()):
            if plate in current_plates:
                self._tts_consecutive[plate] += 1
            else:
                del self._tts_consecutive[plate]
        for plate in current_plates:
            if plate not in self._tts_consecutive:
                # 刚重置或首次启动：直接给预热计数，单图片模式也能立即播报
                self._tts_consecutive[plate] = self.TTS_MIN_CONSECUTIVE if allow_warm else 1

        # 3. 只保留连续出现 >= TTS_MIN_CONSECUTIVE 帧的稳定车牌
        stable_plates = {p for p, c in self._tts_consecutive.items()
                         if c >= self.TTS_MIN_CONSECUTIVE}

        # 4. 移除队列中已消失的车牌
        self._tts_queue = [(p, t) for p, t in self._tts_queue if p in stable_plates]

        # 5. 新出现的稳定车牌入队（15s 防抖 + 编辑距离去重）
        queued_plates = {p for p, _ in self._tts_queue}
        for plate in stable_plates:
            last_time = self._tts_last_announced.get(plate, 0)
            if now - last_time < 15.0:
                continue
            if plate in queued_plates:
                continue
            if plate == self._tts_current_plate:
                continue
            # 编辑距离去重：≤1 字符差异视为同一车牌
            if self._tts_is_duplicate(plate, now):
                continue
            self._tts_queue.append((plate, now))
            print(f'[TTS] 入队: {plate} (稳定{self._tts_consecutive[plate]}帧)')

        # 6. 启动播报
        if not self._tts_speaking and self._tts_queue:
            self._speak_next_from_queue()

    def _tts_is_duplicate(self, plate, now):
        """检查 plate 是否与近期已播报/排队中/正在播的车牌编辑距离 ≤ 1"""
        # 检查已播报历史（时间窗口内）
        for announced_plate, ts in self._tts_last_announced.items():
            if now - ts > self.TTS_FUZZY_WINDOW:
                continue
            if PlateSlotTracker._text_similar(announced_plate, plate):
                return True
        # 检查排队中的车牌
        for queued_plate, _ in self._tts_queue:
            if PlateSlotTracker._text_similar(queued_plate, plate):
                return True
        # 检查正在播报的车牌
        if self._tts_current_plate and PlateSlotTracker._text_similar(
                self._tts_current_plate, plate):
            return True
        return False

    def _speak_next_from_queue(self):
        """从队列取下一个车牌播报，跳过已消失的"""
        # 跳过队列中已不在画面的车牌（兜底清理）
        if not self._tts_queue:
            self._tts_speaking = False
            self._tts_current_plate = None
            return

        plate, _ = self._tts_queue.pop(0)
        self._tts_speaking = True
        self._tts_current_plate = plate
        self._tts_last_announced[plate] = time.time()
        print(f'[TTS] 播报: {plate}')
        self._tts_speak(plate, on_complete=self._on_tts_complete)

    def _on_tts_complete(self):
        """播报完成回调：标记空闲，触发下一个播报"""
        self._tts_speaking = False
        self._tts_current_plate = None
        # 播完当前后立即检查队列中是否有下一个待播报的车牌
        if self._tts_queue:
            self._speak_next_from_queue()

    def _reset_tts_state(self):
        """清除所有 TTS 状态（切换图片/停止摄像头时调用）"""
        self._tts_queue.clear()
        self._tts_consecutive.clear()
        self._tts_speaking = False
        self._tts_current_plate = None
        # 保留 _tts_last_announced —— 防止短时间内同一车牌重复播报

    def _tts_detect_device(self):
        """检测 edge-tts 模块 + mpg123 是否可用"""
        if hasattr(self, '_tts_alsa_device'):
            return self._tts_alsa_device
        try:
            import shutil
            mpg_bin = shutil.which('mpg123')
            if not mpg_bin:
                raise FileNotFoundError('mpg123 not found')
            self._tts_edge_cmd = [sys.executable, '-m', 'edge_tts']
            self._tts_mpg_bin = mpg_bin
            # Qt 子进程环境可能缺少用户 site-packages 路径，显式注入 PYTHONPATH
            self._tts_env = os.environ.copy()
            import site
            user_site = site.getusersitepackages()
            if user_site and user_site not in self._tts_env.get('PYTHONPATH', ''):
                existing = self._tts_env.get('PYTHONPATH', '')
                self._tts_env['PYTHONPATH'] = f'{user_site}:{existing}' if existing else user_site
            self._tts_alsa_device = 'edge-tts'
            print(f'[TTS] edge-tts (via {sys.executable} -m) + mpg123 ({mpg_bin}), PYTHONPATH={self._tts_env.get("PYTHONPATH", "")}')
            return 'edge-tts'
        except Exception as e:
            self._tts_detection_error = str(e)
        print(f'[TTS] edge-tts 或 mpg123 未安装 ({getattr(self, "_tts_detection_error", "unknown")})')
        return None

    def _tts_speak(self, text, on_complete=None):
        """零延迟本地离线拼接播放 (WAV加速版)，播完后回调 on_complete"""
        if not self._tts_enabled:
            if on_complete:
                on_complete()
            return

        # 1. 过滤掉无用字符，只保留车牌号
        valid_chars = []
        for ch in text:
            if ch.isalnum() or ('\u4e00' <= ch <= '\u9fff'):
                valid_chars.append(ch)

        # 2. 将字符映射为本地 WAV 音频文件路径 (已更新为你的新路径和格式)
        audio_files = []
        base_dir = '/home/linaro/plate_audio/wav_out'
        # 直接拼车牌字符
        for ch in valid_chars:
            file_path = f"{base_dir}/{ch}.wav"
            if os.path.exists(file_path):
                audio_files.append(file_path)

        if not audio_files:
            if on_complete:
                on_complete()
            return

        # 3. 寻找自带的 aplay 播放器 (WAV 专属，速度最快)
        import shutil
        aplay_bin = shutil.which('aplay') or '/usr/bin/aplay'

        # 4. 后台线程极速连续播放
        def _bg_play_local():
            try:
                import subprocess
                # aplay -q 开启静默模式，直接按顺序无缝播完所有传入的文件
                play_cmd = [
                    'sudo', '-u', 'linaro', 
                    'env', 'XDG_RUNTIME_DIR=/run/user/1000', 
                    aplay_bin, '-q'
                ] + audio_files  
                
                subprocess.run(play_cmd, timeout=10)
            except Exception as e:
                print(f'[TTS] 本地播放异常: {e}')
            finally:
                if on_complete:
                    on_complete()

        import threading
        threading.Thread(target=_bg_play_local, daemon=True).start()

        def _run_pipe(*extra_args):
            """用指定 mpg123 输出参数播放，如 _run_pipe('-o','pulse')"""
            tmp_path = '/tmp/tts_plate.mp3'
            gen = subprocess.run(
                self._tts_edge_cmd + ['--text', text_to_speak,
                 '--voice', 'zh-CN-XiaoxiaoNeural', '--write-media', tmp_path],
                timeout=15, capture_output=True, env=self._tts_env)
            if gen.returncode != 0:
                err = gen.stderr.decode(errors='replace')[-200:]
                print(f'[TTS] edge-tts 生成失败 (rc={gen.returncode}): {err}')
                return False

            # play = subprocess.run(
            #     [self._tts_mpg_bin] + list(extra_args) + ['-q', tmp_path],
            #     timeout=10, capture_output=True)
            
            if play.returncode != 0:
                err = play.stderr.decode(errors='replace')[-200:]
                print(f'[TTS] mpg123 {extra_args} 播放失败 (rc={play.returncode}): {err}')
                return False
            return True

        def _bg_play():
            try:
                if _run_pipe('-o', 'pulse'):
                    return
                # 回退：alsa 直连 card 0
                print('[TTS] pulse 不通，尝试 alsa hw:0,0 ...')
                if _run_pipe('-o', 'alsa', '-a', 'hw:0,0'):
                    return
                print('[TTS] 所有音频通路均失败，请检查扬声器/声卡状态')
            except Exception as e:
                print(f'[TTS] 播放异常: {e}')

        threading.Thread(target=_bg_play, daemon=True).start()

    def _build_status_bar(self):
        self.statusBar().showMessage("就绪 | 请加载模型后开始使用")

    def _connect_signals(self):
        self.fps_signal.connect(self._on_fps_update)
        self.camera_status_signal.connect(self._on_camera_status)
        self.run_on_main.connect(self._execute_on_main)
        self.car_status_signal.connect(self._on_car_status)

    def _execute_on_main(self, func):
        func()

    def _on_fps_update(self, fps):
        self.camera_fps_label.setText(f"FPS: {fps:.1f}")
        self.hdmi_fps_label.setText(f"FPS: {fps:.1f}")
        if hasattr(self, 'sdcard_fps_label'):
            self.sdcard_fps_label.setText(f"FPS: {fps:.1f}")

    def _on_camera_status(self, msg, color):
        self.camera_status_label.setText(msg)
        self.camera_status_label.setStyleSheet(f"color: {color};")

    def _on_car_status(self, msg, color):
        self.car_status_label.setText(msg)
        self.car_status_label.setStyleSheet(f"color: {color}; background-color: #313244;")

    def _browse_file(self, line_edit, title, filter_str=None):
        if filter_str is None:
            filter_str = "RKNN 模型 (*.rknn);;所有文件 (*.*)"
        filepath, _ = QFileDialog.getOpenFileName(self, title, "", filter_str)
        if filepath:
            line_edit.setText(filepath)

    def _ensure_models_loaded(self):
        if not self.models_loaded:
            QMessageBox.warning(self, "提示", "请先加载模型！")
            return False
        return True

    def _load_models(self):
        det_path = self.det_model_edit.text()
        det_nc = self.det_nc_combo.currentData() or 2
        self.det_no = det_nc + 5 + 8
        rec_b4_path = self.rec_model_b4_edit.text()
        rec_b1_path = self.rec_model_b1_edit.text()
        pedestrian_path = self.pedestrian_det_model_edit.text()
        for path, name in [(det_path, "检测模型"), (pedestrian_path, "行人违法检测模型"),
                           (rec_b4_path, "B4识别模型"), (rec_b1_path, "B1识别模型")]:
            if not os.path.isfile(path):
                QMessageBox.critical(self, "错误", f"{name}文件不存在:\n{path}")
                return
        self.model_status_label.setText("模型状态: 加载中...")
        self.model_status_label.setStyleSheet("color: #f9e2af; background-color: #313244; padding: 6px; border-radius: 4px;")
        QApplication.processEvents()
        try:
            self.rknn_det = RKNNLite()
            self.rknn_det_pedestrian = RKNNLite()
            self.rknn_rec_b4 = RKNNLite()
            self.rknn_rec_b1 = RKNNLite()
            ret = self.rknn_det.load_rknn(det_path)
            if ret != 0:
                raise RuntimeError(f"检测模型加载失败, ret={ret}")
            ret = self.rknn_det.init_runtime()
            if ret != 0:
                raise RuntimeError(f"检测模型初始化失败, ret={ret}")
            ret = self.rknn_det_pedestrian.load_rknn(pedestrian_path)
            if ret != 0:
                raise RuntimeError(f"行人违法检测模型加载失败, ret={ret}")
            ret = self.rknn_det_pedestrian.init_runtime()
            if ret != 0:
                raise RuntimeError(f"行人违法检测模型初始化失败, ret={ret}")
            ret = self.rknn_rec_b4.load_rknn(rec_b4_path)
            if ret != 0:
                raise RuntimeError(f"B4识别模型加载失败, ret={ret}")
            ret = self.rknn_rec_b4.init_runtime()
            if ret != 0:
                raise RuntimeError(f"B4识别模型初始化失败, ret={ret}")
            ret = self.rknn_rec_b1.load_rknn(rec_b1_path)
            if ret != 0:
                raise RuntimeError(f"B1识别模型加载失败, ret={ret}")
            ret = self.rknn_rec_b1.init_runtime()
            if ret != 0:
                raise RuntimeError(f"B1识别模型初始化失败, ret={ret}")
            self.models_loaded = True
            self.model_status_label.setText("模型状态: 已加载 ✓")
            self.model_status_label.setStyleSheet("color: #a6e3a1; background-color: #313244; padding: 6px; border-radius: 4px;")
            self.load_btn.setEnabled(False)
            self.release_btn.setEnabled(True)
            self.statusBar().showMessage("模型加载完成 | 可以开始识别")
            QMessageBox.information(self, "成功", "所有模型加载完成！")
        except Exception as e:
            self._release_models_internal()
            self.model_status_label.setText("模型状态: 加载失败")
            self.model_status_label.setStyleSheet("color: #f38ba8; background-color: #313244; padding: 6px; border-radius: 4px;")
            QMessageBox.critical(self, "加载失败", str(e))

    def _release_models(self):
        self._release_models_internal()
        self.model_status_label.setText("模型状态: 未加载")
        self.model_status_label.setStyleSheet("color: #f38ba8; background-color: #313244; padding: 6px; border-radius: 4px;")
        self.load_btn.setEnabled(True)
        self.release_btn.setEnabled(False)
        self.statusBar().showMessage("模型已释放")

    def _release_models_internal(self):
        for attr in ['rknn_det', 'rknn_det_pedestrian', 'rknn_rec_b4', 'rknn_rec_b1']:
            obj = getattr(self, attr, None)
            if obj is not None:
                try:
                    obj.release()
                except Exception:
                    pass
                setattr(self, attr, None)
        self.models_loaded = False

    def _show_preview(self, full_label, crop_label, plate_big_label, full_img, final_results, crop_images, is_rgb=False):
        full_label.set_cv_image(full_img, is_rgb=is_rgb)
        if len(crop_images) > 0:
            h_max = max(c.shape[0] for c in crop_images)
            w_max = max(c.shape[1] for c in crop_images)
            pad_h = max(10, h_max // 4)
            pad_w = max(10, w_max // 8)
            total_h = len(crop_images) * (h_max + pad_h) + pad_h
            total_w = w_max + pad_w * 2
            composite = np.ones((total_h, total_w, 3), dtype=np.uint8) * 40
            for i, crop in enumerate(crop_images):
                ch, cw = crop.shape[:2]
                y_off = pad_h + i * (h_max + pad_h) + (h_max - ch) // 2
                x_off = pad_w + (w_max - cw) // 2
                composite[y_off:y_off + ch, x_off:x_off + cw] = crop
            crop_label.set_cv_image(composite)
        else:
            crop_label.clear()
            crop_label.setText("未检测到车牌")
        plate_texts = [f"{r[1]}({r[2]})" for r in final_results]
        if plate_texts:
            plate_big_label.setText("  |  ".join(plate_texts))
        else:
            plate_big_label.setText("未检测到")

    def _update_plate_slots(self, slots_data, slot_widgets):
        """将 PlateSlotTracker 返回的 8 槽位数据渲染到 QLabel，文字按中国车牌规则格式化并过滤"""
        for i, slot_info in enumerate(slots_data):
            w = slot_widgets[i]
            if slot_info is not None and slot_info.get('crop') is not None:
                crop_bgr = np.ascontiguousarray(slot_info['crop'])
                h, w_px = crop_bgr.shape[:2]
                if h > 0 and w_px > 0:
                    rgb = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGB)
                    qimg = QImage(rgb.data, w_px, h, w_px * 3, QImage.Format_RGB888).copy()
                    target = w['img'].size()
                    w['img'].setPixmap(QPixmap.fromImage(qimg).scaled(
                        target.width(), target.height(),
                        Qt.KeepAspectRatio, Qt.SmoothTransformation))
                # 文字标签：格式化 + 校验
                formatted, valid = PlateSlotTracker._validate_and_format(slot_info['text'])
                w['text'].setText(formatted if valid else "--")
                if not valid:
                    w['img'].clear()
            # slot_info is None → 保留已有截图不动


        # ── TTS 播报：新出现的车牌触发语音播报 ──
        self._tts_maybe_announce(slots_data)

    def _start_camera(self):
        if not self._ensure_models_loaded():
            return
        if self.camera_running:
            return
        # 单一动态库共享全局状态: 启动相机前先停掉 HDMI 推流
        if self.hdmi_running:
            self._stop_hdmi_flag = True
            t = getattr(self, '_hdmi_thread', None)
            if t is not None and t.is_alive():
                t.join(timeout=5.0)
        self._camera_hard_stop = False
        source = self.camera_source_combo.currentText()
        if source == 'hardware':
            hw_path = self.hw_lib_edit.text()
            if not os.path.isfile(hw_path):
                QMessageBox.critical(self, "错误", f"推流库文件不存在:\n{hw_path}")
                return
        self._stop_camera_flag = False
        self.camera_running = True
        self.camera_start_btn.setEnabled(False)
        self.camera_stop_btn.setEnabled(True)
        self.camera_fps_label.setText("FPS: --")
        self._camera_thread = threading.Thread(target=self._camera_worker, daemon=True)
        self._camera_thread.start()

    def _stop_camera(self):
        self._stop_camera_flag = True
        self._reset_tts_state()

    def _on_camera_source_changed(self, text):
        if text == 'usb':
            self.usb_widget.show()
            self.hw_widget.hide()
        else:
            self.usb_widget.hide()
            self.hw_widget.show()

    def _refresh_hw_screens(self):
        self._hw_screen_map = {}
        try:
            hw_path = self.hw_lib_edit.text()
            if not os.path.isfile(hw_path):
                self.hw_screen_combo.clear()
                self.hw_screen_combo.addItem('0:DSI-1(默认)')
                self._hw_screen_map = {'0:DSI-1(默认)': 0}
                return
            hw_lib = ctypes.CDLL(hw_path)
            hw_lib.get_connected_connectors.argtypes = [ctypes.c_char_p, ctypes.c_int]
            hw_lib.get_connected_connectors.restype = ctypes.c_int
            buf = ctypes.create_string_buffer(512)
            count = hw_lib.get_connected_connectors(buf, 512)
            if count <= 0:
                self.hw_screen_combo.clear()
                self.hw_screen_combo.addItem('0:未检测到屏幕')
                return
            lines = buf.value.decode('utf-8', errors='ignore').split('\n')
            display_list = []
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                idx_str = line.split(':')[0]
                idx = int(idx_str)
                display_list.append(line)
                self._hw_screen_map[line] = idx
            self.hw_screen_combo.clear()
            self.hw_screen_combo.addItems(display_list)
            if len(display_list) > 1:
                self.hw_screen_combo.setCurrentIndex(1)
        except Exception as e:
            self.hw_screen_combo.clear()
            self.hw_screen_combo.addItem(f'检测失败: {e}')

    def _refresh_hdmi_screens(self):
        self._hdmi_screen_map = {}
        try:
            hdmi_path = self.hdmi_lib_edit.text()
            if not os.path.isfile(hdmi_path):
                self.hdmi_screen_combo.clear()
                self.hdmi_screen_combo.addItem('0:DSI-1(默认)')
                self._hdmi_screen_map = {'0:DSI-1(默认)': 0}
                return
            hw_lib = ctypes.CDLL(hdmi_path)
            hw_lib.get_connected_connectors.argtypes = [ctypes.c_char_p, ctypes.c_int]
            hw_lib.get_connected_connectors.restype = ctypes.c_int
            buf = ctypes.create_string_buffer(512)
            count = hw_lib.get_connected_connectors(buf, 512)
            if count <= 0:
                self.hdmi_screen_combo.clear()
                self.hdmi_screen_combo.addItem('0:未检测到屏幕')
                return
            lines = buf.value.decode('utf-8', errors='ignore').split('\n')
            display_list = []
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                idx = int(line.split(':')[0])
                display_list.append(line)
                self._hdmi_screen_map[line] = idx
            self.hdmi_screen_combo.clear()
            self.hdmi_screen_combo.addItems(display_list)
            # 默认选择 DSI 屏幕（小屏幕），若不存在则回退到第一个
            default_idx = 0
            for i, name in enumerate(display_list):
                if 'DSI' in name.upper():
                    default_idx = i
                    break
            self.hdmi_screen_combo.setCurrentIndex(default_idx)
        except Exception as e:
            self.hdmi_screen_combo.clear()
            self.hdmi_screen_combo.addItem(f'检测失败: {e}')

    def _camera_worker(self):
        source = self.camera_source_combo.currentText()
        attempt = 0

        while not self._camera_hard_stop:
            self._camera_retry_needed = False
            self._camera_last_fps = 0.0
            self._camera_suppress_status = (attempt > 0)   # 首次显示状态，重试时静默

            if source == 'hardware':
                self._camera_worker_hw()
            else:
                self._camera_worker_usb()

            # ── 判断是否需要自动重试 ──
            if self._stop_camera_flag and not self._camera_retry_needed:
                break   # 用户手动停止
            if not self._camera_retry_needed:
                break   # 正常退出或 FPS 已达标

            # FPS 不达标，无限次静默重试，重试间隔最小化（无 sleep，立即重入）
            attempt += 1
            print(f'[Camera] FPS={self._camera_last_fps:.1f}<25, 自动重试 (第 {attempt} 次)...')
            self._stop_camera_flag = False

        # ── 最终清理（所有重试结束或用户停止后执行一次） ──
        self.camera_running = False
        self._camera_suppress_status = False   # 恢复状态栏显示
        self.run_on_main.emit(lambda: self.camera_start_btn.setEnabled(True))
        self.run_on_main.emit(lambda: self.camera_stop_btn.setEnabled(False))
        self.run_on_main.emit(lambda: self.camera_fps_label.setText("FPS: --"))

    def _camera_worker_hw(self):
        hw_lib = None
        smoother = BoxSmoother(alpha=0.7, iou_thresh=0.4, history_len=10)
        shared_state = {'frame_for_ai': None, 'ai_ready': False, 'latest_results': []}
        state_lock = threading.Lock()
        render_state = {'hd_img': None, 'current_results': [], 'base_addr': 0}
        render_lock = threading.Lock()
        render_event = threading.Event()
        exit_event = threading.Event()

        def set_status(msg, color='#cc6600'):
            if not self._camera_suppress_status:
                self.camera_status_signal.emit(msg, color)

        def ai_thread_func():
            while not exit_event.is_set():
                yolo_img = None
                hd_img = None
                with state_lock:
                    if shared_state['ai_ready']:
                        yolo_img = shared_state['frame_for_ai']['yolo']
                        hd_img = shared_state['frame_for_ai']['hd']  # 主循环已做 copy，无需重复
                        shared_state['ai_ready'] = False
                if yolo_img is None:
                    time.sleep(0.001)
                    continue
                yolo_img_input = np.expand_dims(yolo_img, axis=0)
                outputs = self.rknn_det.inference(inputs=[yolo_img_input])
                boxes_list, scores_list, class_ids = decode_yolo_fast(outputs, 1280, 720, no=self.det_no)
                indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                indices = filter_plate_boxes(boxes_list, scores_list, class_ids, indices)
                new_results = []
                if len(indices) > 0:
                    crop_imgs = []
                    valid_boxes = []
                    for idx in np.array(indices).flatten():
                        b = boxes_list[int(idx)]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                        x1 = max(0, int(x - pad_x))
                        y1 = max(0, int(y - pad_y))
                        x2 = min(1280, int(x + w + pad_x))
                        y2 = min(720, int(y + h + pad_y))

                        # 行人违法：红框直接入结果，不占用车牌裁剪名额
                        if class_ids[int(idx)] == 1:
                            new_results.append({
                                'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                                'text': '行人违法',
                                'color_bgr': (0, 0, 255),
                                'color_rgb': (255, 0, 0),
                                'crop': None,
                            })
                            continue

                        if len(crop_imgs) >= 4:
                            continue
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
                                rec_out = self.rknn_rec_b4.inference(inputs=[batch_imgs])
                                for i in range(take_num):
                                    char_logits_list.append(rec_out[0][i:i + 1])
                                    color_logits_list.append(rec_out[1][i:i + 1])
                                processed_num += take_num
                            else:
                                img = crop_imgs[processed_num]
                                img_input = np.expand_dims(img, axis=0)
                                rec_out = self.rknn_rec_b1.inference(inputs=[img_input])
                                char_logits_list.append(rec_out[0])
                                color_logits_list.append(rec_out[1])
                                processed_num += 1
                        for i in range(crop_count):
                            raw_text = decode_lprnet_v2(char_logits_list[i])
                            plate_text = rectify_plate_text(raw_text)
                            logits_sq = np.squeeze(color_logits_list[i])
                            exp_logits = np.exp(logits_sq - np.max(logits_sq))
                            ai_probs = exp_logits / np.sum(exp_logits)
                            plate_type = "未知"
                            if len(plate_text) > 0 and plate_text[-1] in ['学', '警', '领', '挂', '使', '港', '澳']:
                                plate_type = "特殊牌"
                            else:
                                hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                                color_bounds = {
                                    0: (np.array([100, 43, 46]), np.array([124, 255, 255])),
                                    1: (np.array([10, 30, 46]), np.array([35, 255, 255])),
                                    3: (np.array([36, 43, 46]), np.array([85, 255, 255]))
                                }
                                hsv_counts = np.zeros(4)
                                for cid, (lower, upper) in color_bounds.items():
                                    mask = cv2.inRange(hsv, lower, upper)
                                    hsv_counts[cid] = cv2.countNonZero(mask)
                                total_hsv_pixels = np.sum(hsv_counts)
                                hsv_probs = np.zeros(4)
                                if total_hsv_pixels > 0:
                                    hsv_probs = hsv_counts / total_hsv_pixels
                                if total_hsv_pixels > 100:
                                    final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                                else:
                                    final_probs = ai_probs
                                color_id = int(np.argmax(final_probs))
                                plate_type = PLATE_COLORS_MAP.get(color_id, "未知")
                            display_text = f"{plate_text}({plate_type})"
                            bx1, by1, bx2, by2 = valid_boxes[i]
                            color_bgr = PLATE_COLORS_BGR.get(plate_type, (0, 255, 0))
                            color_rgb = PLATE_COLORS_RGB.get(plate_type, (0, 255, 0))
                            new_results.append({
                                'x1': bx1, 'y1': by1, 'x2': bx2, 'y2': by2,
                                'text': display_text,
                                'color_bgr': color_bgr,
                                'color_rgb': color_rgb,
                                'crop': crop_imgs[i],
                            })
                smoothed = smoother.update(new_results)
                with state_lock:
                    shared_state['latest_results'] = smoothed

        def render_thread_func():
            slot_tracker = PlateSlotTracker()
            while not exit_event.is_set():
                if not render_event.wait(timeout=0.1):
                    continue
                render_event.clear()
                try:
                    with render_lock:
                        if render_state['hd_img'] is None:
                            continue
                        img_hd = render_state['hd_img']
                        current_results = render_state['current_results']
                        base_addr = render_state['base_addr']
                    for res in current_results:
                        x1, y1, x2, y2 = res['x1'], res['y1'], res['x2'], res['y2']
                        cv2.rectangle(img_hd, (x1, y1), (x2, y2), res['color_rgb'], 3)
                    if len(current_results) > 0:
                        for res in current_results:
                            text = res['text']
                            text_y = max(0, res['y1'] - 35)
                            roi_x1 = max(0, res['x1'])
                            roi_x2 = min(1280, res['x1'] + 360)
                            roi_y1 = max(0, text_y)
                            roi_y2 = max(roi_y1, res['y1'])
                            if roi_y2 > roi_y1 and roi_x2 > roi_x1:
                                roi = img_hd[roi_y1:roi_y2, roi_x1:roi_x2]
                                roi_pil = Image.fromarray(roi)
                                draw = ImageDraw.Draw(roi_pil)
                                draw.text((0, 0), text, font=self.font, fill=res['color_rgb'])
                                img_hd[roi_y1:roi_y2, roi_x1:roi_x2] = np.array(roi_pil)
                    hd_ptr = base_addr + HW_YOLO_SIZE
                    hw_lib.sync_to_screen(ctypes.c_void_p(hd_ptr))

                    # ── 车牌槽位：仅更新截取图到 UI ──
                    slot_detections = [(r['text'], r['crop'], r['x1'], r['y1'], r['x2'], r['y2']) for r in current_results if r.get('crop') is not None]
                    slot_tracker.update(slot_detections)
                    slots_snapshot = list(slot_tracker.slots)
                    self.run_on_main.emit(lambda ss=slots_snapshot, sl=self.camera_slots:
                        self._update_plate_slots(ss, sl)
                    )
                except Exception as e:
                    print(f"[Camera render] 异常: {e}")

        ai_thread = None
        render_thread = None
        try:
            hw_path = self.hw_lib_edit.text()
            set_status("正在加载推流库...", '#0066cc')
            try:
                hw_lib = ctypes.CDLL(hw_path)
                self._camera_hw_lib = hw_lib
            except OSError as e:
                set_status("推流库加载失败", '#cc0000')
                self.run_on_main.emit(lambda: QMessageBox.critical(
                    self, "推流库加载失败",
                    f"无法加载 {hw_path}\n\n错误: {e}\n\n"
                    f"请检查:\n"
                    f"1. 推流库文件是否存在\n"
                    f"2. 是否有执行权限 (chmod +x)\n"
                    f"3. 依赖库 librga/libdrm 是否已安装"))
                return

            hw_lib.fetch_next_frame.restype = ctypes.POINTER(ctypes.c_uint8)
            hw_lib.sync_to_screen.argtypes = [ctypes.c_void_p]
            hw_lib.set_pipeline_resolution.argtypes = [ctypes.c_int, ctypes.c_int]
            hw_lib.set_pipeline_resolution.restype = ctypes.c_int
            hw_lib.init_hardware_pipeline_ex.argtypes = [ctypes.c_int]
            hw_lib.init_hardware_pipeline_ex.restype = ctypes.c_int
            # 单一动态库按运行时分辨率切换: 相机管线 1280×720
            if hw_lib.set_pipeline_resolution(1280, 720) != 0:
                set_status("相机分辨率设置失败", '#cc0000')
                return
            connector_idx = self._hw_screen_map.get(self.hw_screen_combo.currentText(), 1)
            set_status(f"正在初始化硬件管线 (屏幕{connector_idx})...", '#0066cc')
            ret = hw_lib.init_hardware_pipeline_ex(connector_idx)
            if ret != 0:
                set_status("硬件管线初始化失败", '#cc0000')
                self.run_on_main.emit(lambda: QMessageBox.critical(
                    self, "硬件初始化失败",
                    f"init_hardware_pipeline_ex({connector_idx}) 返回 {ret}\n\n"
                    f"请检查:\n"
                    f"1. PCIe 驱动是否已加载\n"
                    f"2. FPGA 固件是否已烧录\n"
                    f"3. 屏幕连接是否正常"))
                return

            set_status("硬件初始化完成，启动AI线程...", '#009900')
            ai_thread = threading.Thread(target=ai_thread_func, daemon=True)
            ai_thread.start()
            render_thread = threading.Thread(target=render_thread_func, daemon=True)
            render_thread.start()

            frame_count = 0
            fps_timer = time.perf_counter()
            fps_display = 0.0
            fps_ok = False              # 只有 FPS >= 25 后才开始显示帧率
            warmup_deadline = time.perf_counter() + 0.8   # 0.8 秒后开始检查 FPS（首个读数 ~1s 时触发）

            while not self._stop_camera_flag:
                c_ptr = hw_lib.fetch_next_frame()
                if not c_ptr:
                    continue

                base_addr = ctypes.addressof(c_ptr.contents)
                yolo_buffer = (ctypes.c_uint8 * HW_YOLO_SIZE).from_address(base_addr)
                hd_buffer = (ctypes.c_uint8 * HW_HD_SIZE).from_address(base_addr + HW_YOLO_SIZE)

                img_yolo = np.ndarray(buffer=yolo_buffer, dtype=np.uint8, shape=(640, 640, 3))
                img_hd = np.ndarray(buffer=hd_buffer, dtype=np.uint8, shape=(720, 1280, 3))

                current_results = []
                with state_lock:
                    shared_state['frame_for_ai'] = {'yolo': img_yolo, 'hd': img_hd.copy()}
                    shared_state['ai_ready'] = True
                    current_results = list(shared_state['latest_results'])

                with render_lock:
                    render_state['hd_img'] = img_hd
                    render_state['current_results'] = current_results
                    render_state['base_addr'] = base_addr
                render_event.set()

                frame_count += 1
                now = time.perf_counter()
                elapsed = now - fps_timer
                if elapsed >= 1.0:
                    fps_display = frame_count / elapsed
                    frame_count = 0
                    fps_timer = now
                    if fps_ok:
                        self.fps_signal.emit(fps_display)
                    set_status(f"运行中 | 检测到 {len(current_results)} 个车牌", '#009900')

                    # ── 预热后检查 FPS：低于 25 则静默自动重试，达标才开始显示帧率 ──
                    if not self._camera_retry_needed and time.perf_counter() > warmup_deadline and fps_display > 0:
                        self._camera_last_fps = fps_display
                        if fps_display >= 25:
                            fps_ok = True
                            self._camera_suppress_status = False   # 解除静默
                            self.fps_signal.emit(fps_display)   # 达标，开始显示帧率
                        else:
                            self._camera_retry_needed = True
                            self._stop_camera_flag = True

        except Exception as e:
            set_status(f"异常: {e}", '#cc0000')
            print(f"硬件推流线程异常: {e}")
        finally:
            exit_event.set()
            render_event.set()
            if ai_thread is not None:
                ai_thread.join(timeout=2.0)
            if render_thread is not None:
                render_thread.join(timeout=2.0)
            if hw_lib is not None:
                try:
                    hw_lib.cleanup_hardware()
                except Exception:
                    pass
            self._camera_hw_lib = None
            self.camera_running = False
            self._camera_suppress_status = False   # 退出时恢复状态显示
            set_status("", '#cc6600')
            # ── 自动重试中不恢复按钮状态，由 _camera_worker 兜底 ──
            if not self._camera_retry_needed:
                self.run_on_main.emit(lambda: self.camera_start_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.camera_stop_btn.setEnabled(False))
                self.run_on_main.emit(lambda: self.camera_fps_label.setText("FPS: --"))

    def _start_hdmi(self):
        if not self._ensure_models_loaded():
            return
        if self.hdmi_running:
            return
        # 单一动态库共享全局状态: 启动 HDMI 前先停掉相机推流 (含自动重试循环)
        if self.camera_running:
            self._stop_camera_flag = True
            self._camera_hard_stop = True
            t = getattr(self, '_camera_thread', None)
            if t is not None and t.is_alive():
                t.join(timeout=5.0)
        hdmi_path = self.hdmi_lib_edit.text()
        if not os.path.isfile(hdmi_path):
            QMessageBox.critical(self, "错误", f"HDMI推流库文件不存在:\n{hdmi_path}")
            return
        self._stop_hdmi_flag = False
        self.hdmi_running = True
        self.hdmi_start_btn.setEnabled(False)
        self.hdmi_stop_btn.setEnabled(True)
        self.hdmi_fps_label.setText("FPS: --")
        connector_idx = self._hdmi_screen_map.get(self.hdmi_screen_combo.currentText(), 0)
        self._hdmi_thread = threading.Thread(target=self._hdmi_worker, args=(connector_idx,), daemon=True)
        self._hdmi_thread.start()

    def _stop_hdmi(self):
        self._stop_hdmi_flag = True
        self._reset_tts_state()

    def _hdmi_worker(self, connector_idx=0):
        self._camera_worker_hdmi(connector_idx)

    def _camera_worker_hdmi(self, connector_idx=0):
        hw_lib = None
        smoother = BoxSmoother(alpha=0.7, iou_thresh=0.4, history_len=10)
        shared_state = {'frame_for_ai': None, 'ai_ready': False, 'latest_results': []}
        state_lock = threading.Lock()
        render_state = {'hd_img': None, 'current_results': [], 'base_addr': 0}
        render_lock = threading.Lock()
        render_event = threading.Event()
        exit_event = threading.Event()

        def set_status(msg, color='#cc6600'):
            self.camera_status_signal.emit(msg, color)

        def ai_thread_func():
            prof_yolo = 0.0
            prof_cpu = 0.0
            prof_n = 0
            while not exit_event.is_set():
                yolo_img = None
                hd_img = None
                with state_lock:
                    if shared_state['ai_ready']:
                        yolo_img = shared_state['frame_for_ai']['yolo']
                        hd_img = shared_state['frame_for_ai']['hd']  # 主循环已做 copy，无需重复
                        shared_state['ai_ready'] = False
                if yolo_img is None:
                    time.sleep(0.001)
                    continue
                t_ai = time.perf_counter()
                yolo_img_input = np.expand_dims(yolo_img, axis=0)
                outputs = self.rknn_det.inference(inputs=[yolo_img_input])
                t_yolo = time.perf_counter()
                boxes_list, scores_list, class_ids = decode_yolo_fast(outputs, 1920, 1080, no=self.det_no)
                indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                indices = filter_plate_boxes(boxes_list, scores_list, class_ids, indices)
                new_results = []
                if len(indices) > 0:
                    crop_imgs = []
                    valid_boxes = []
                    for idx in np.array(indices).flatten():
                        b = boxes_list[int(idx)]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                        x1 = max(0, int(x - pad_x))
                        y1 = max(0, int(y - pad_y))
                        x2 = min(1920, int(x + w + pad_x))
                        y2 = min(1080, int(y + h + pad_y))

                        # 行人违法：红框直接入结果，不占用车牌裁剪名额
                        if class_ids[int(idx)] == 1:
                            new_results.append({
                                'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                                'text': '行人违法',
                                'color_bgr': (0, 0, 255),
                                'color_rgb': (255, 0, 0),
                                'crop': None,
                            })
                            continue

                        if len(crop_imgs) >= 4:
                            continue
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
                                rec_out = self.rknn_rec_b4.inference(inputs=[batch_imgs])
                                for i in range(take_num):
                                    char_logits_list.append(rec_out[0][i:i + 1])
                                    color_logits_list.append(rec_out[1][i:i + 1])
                                processed_num += take_num
                            else:
                                img = crop_imgs[processed_num]
                                img_input = np.expand_dims(img, axis=0)
                                rec_out = self.rknn_rec_b1.inference(inputs=[img_input])
                                char_logits_list.append(rec_out[0])
                                color_logits_list.append(rec_out[1])
                                processed_num += 1
                        for i in range(crop_count):
                            raw_text = decode_lprnet_v2(char_logits_list[i])
                            plate_text = rectify_plate_text(raw_text)
                            logits_sq = np.squeeze(color_logits_list[i])
                            exp_logits = np.exp(logits_sq - np.max(logits_sq))
                            ai_probs = exp_logits / np.sum(exp_logits)
                            plate_type = "未知"
                            if len(plate_text) > 0 and plate_text[-1] in ['学', '警', '领', '挂', '使', '港', '澳']:
                                plate_type = "特殊牌"
                            else:
                                hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                                color_bounds = {
                                    0: (np.array([100, 43, 46]), np.array([124, 255, 255])),
                                    1: (np.array([10, 30, 46]), np.array([35, 255, 255])),
                                    3: (np.array([36, 43, 46]), np.array([85, 255, 255]))
                                }
                                hsv_counts = np.zeros(4)
                                for cid, (lower, upper) in color_bounds.items():
                                    mask = cv2.inRange(hsv, lower, upper)
                                    hsv_counts[cid] = cv2.countNonZero(mask)
                                total_hsv_pixels = np.sum(hsv_counts)
                                hsv_probs = np.zeros(4)
                                if total_hsv_pixels > 0:
                                    hsv_probs = hsv_counts / total_hsv_pixels
                                if total_hsv_pixels > 100:
                                    final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                                else:
                                    final_probs = ai_probs
                                color_id = int(np.argmax(final_probs))
                                plate_type = PLATE_COLORS_MAP.get(color_id, "未知")
                            display_text = f"{plate_text}({plate_type})"
                            bx1, by1, bx2, by2 = valid_boxes[i]
                            color_bgr = PLATE_COLORS_BGR.get(plate_type, (0, 255, 0))
                            color_rgb = PLATE_COLORS_RGB.get(plate_type, (0, 255, 0))
                            new_results.append({
                                'x1': bx1, 'y1': by1, 'x2': bx2, 'y2': by2,
                                'text': display_text,
                                'color_bgr': color_bgr,
                                'color_rgb': color_rgb,
                                'crop': crop_imgs[i],
                            })
                smoothed = smoother.update(new_results)
                with state_lock:
                    shared_state['latest_results'] = smoothed
                t_done = time.perf_counter()
                prof_yolo += t_yolo - t_ai
                prof_cpu += t_done - t_yolo
                prof_n += 1
                if prof_n >= 30:
                    print(f"[HDMI AI] 采样{prof_n}次 | yolo推理={prof_yolo / prof_n * 1000:.2f}ms "
                          f"CPU后处理={prof_cpu / prof_n * 1000:.2f}ms "
                          f"单帧总={(prof_yolo + prof_cpu) / prof_n * 1000:.2f}ms")
                    prof_yolo = 0.0
                    prof_cpu = 0.0
                    prof_n = 0

        def render_thread_func():
            slot_tracker = PlateSlotTracker()
            prof_draw = 0.0
            prof_sync = 0.0
            prof_n = 0
            while not exit_event.is_set():
                if not render_event.wait(timeout=0.1):
                    continue
                render_event.clear()
                try:
                    with render_lock:
                        if render_state['hd_img'] is None:
                            continue
                        img_hd = render_state['hd_img']
                        current_results = render_state['current_results']
                        base_addr = render_state['base_addr']
                    t_draw0 = time.perf_counter()
                    # ── 物理屏幕帧：绘制检测框和文字后推流 ──
                    for res in current_results:
                        x1, y1, x2, y2 = res['x1'], res['y1'], res['x2'], res['y2']
                        cv2.rectangle(img_hd, (x1, y1), (x2, y2), res['color_rgb'], 3)
                    if len(current_results) > 0:
                        for res in current_results:
                            text = res['text']
                            text_y = max(0, res['y1'] - 35)
                            roi_x1 = max(0, res['x1'])
                            roi_x2 = min(1920, res['x1'] + 360)
                            roi_y1 = max(0, text_y)
                            roi_y2 = max(roi_y1, res['y1'])
                            if roi_y2 > roi_y1 and roi_x2 > roi_x1:
                                roi = img_hd[roi_y1:roi_y2, roi_x1:roi_x2]
                                roi_pil = Image.fromarray(roi)
                                draw = ImageDraw.Draw(roi_pil)
                                draw.text((0, 0), text, font=self.font, fill=res['color_rgb'])
                                img_hd[roi_y1:roi_y2, roi_x1:roi_x2] = np.array(roi_pil)
                    hd_ptr = base_addr + HW_YOLO_SIZE
                    t_draw1 = time.perf_counter()
                    hw_lib.sync_to_screen(ctypes.c_void_p(hd_ptr))
                    t_sync = time.perf_counter()
                    prof_draw += t_draw1 - t_draw0
                    prof_sync += t_sync - t_draw1
                    prof_n += 1
                    if prof_n >= 60:
                        print(f"[HDMI render] 采样{prof_n}帧 | 画框+文字={prof_draw / prof_n * 1000:.2f}ms "
                              f"sync_to_screen={prof_sync / prof_n * 1000:.2f}ms "
                              f"当前框数={len(current_results)}")
                        prof_draw = 0.0
                        prof_sync = 0.0
                        prof_n = 0
                    # ── 车牌槽位：仅更新截取图到 UI ──
                    slot_detections = [(r['text'], r['crop'], r['x1'], r['y1'], r['x2'], r['y2']) for r in current_results if r.get('crop') is not None]
                    slot_tracker.update(slot_detections)
                    slots_snapshot = list(slot_tracker.slots)
                    self.run_on_main.emit(lambda ss=slots_snapshot, sl=self.hdmi_slots:
                        self._update_plate_slots(ss, sl)
                    )
                except Exception as e:
                    print(f"[HDMI render] 异常: {e}")

        ai_thread = None
        render_thread = None
        try:
            hdmi_path = self.hdmi_lib_edit.text()
            set_status("正在加载HDMI推流库...", '#0066cc')
            try:
                hw_lib = ctypes.CDLL(hdmi_path)
                self._hdmi_hw_lib = hw_lib
            except OSError as e:
                set_status("HDMI推流库加载失败", '#cc0000')
                self.run_on_main.emit(lambda: QMessageBox.critical(
                    self, "HDMI推流库加载失败",
                    f"无法加载 {hdmi_path}\n\n错误: {e}\n\n"
                    f"请检查:\n"
                    f"1. 推流库文件是否存在\n"
                    f"2. 是否有执行权限 (chmod +x)\n"
                    f"3. 依赖库 librga/libdrm 是否已安装"))
                return

            hw_lib.fetch_next_frame.restype = ctypes.POINTER(ctypes.c_uint8)
            hw_lib.sync_to_screen.argtypes = [ctypes.c_void_p]
            hw_lib.set_pipeline_resolution.argtypes = [ctypes.c_int, ctypes.c_int]
            hw_lib.set_pipeline_resolution.restype = ctypes.c_int
            hw_lib.init_hardware_pipeline_ex.argtypes = [ctypes.c_int]
            hw_lib.init_hardware_pipeline_ex.restype = ctypes.c_int
            # 单一动态库按运行时分辨率切换: HDMI 管线 1920×1080
            if hw_lib.set_pipeline_resolution(1920, 1080) != 0:
                set_status("HDMI分辨率设置失败", '#cc0000')
                return
            set_status(f"正在初始化HDMI推流管线 (屏幕{connector_idx})...", '#0066cc')
            ret = hw_lib.init_hardware_pipeline_ex(connector_idx)
            if ret != 0:
                set_status("HDMI推流管线初始化失败", '#cc0000')
                self.run_on_main.emit(lambda: QMessageBox.critical(
                    self, "硬件初始化失败",
                    f"init_hardware_pipeline_ex({connector_idx}) 返回 {ret}\n\n"
                    f"请检查:\n"
                    f"1. PCIe 驱动是否已加载\n"
                    f"2. FPGA 固件是否已烧录\n"
                    f"3. HDMI/DSI 屏幕连接是否正常"))
                return

            set_status("HDMI推流启动，物理屏幕 + AI识别中...", '#009900')
            ai_thread = threading.Thread(target=ai_thread_func, daemon=True)
            ai_thread.start()
            render_thread = threading.Thread(target=render_thread_func, daemon=True)
            render_thread.start()

            frame_count = 0
            fps_timer = time.perf_counter()
            fps_display = 0.0
            null_fetch_count = 0
            null_fetch_reported = False

            # ── 打点统计：fetch / copy / 每帧总耗时 ──
            prof_fetch = 0.0
            prof_copy = 0.0
            prof_total = 0.0
            prof_n = 0

            while not self._stop_hdmi_flag:
                t_loop = time.perf_counter()
                c_ptr = hw_lib.fetch_next_frame()
                t_fetch = time.perf_counter()
                if not c_ptr:
                    null_fetch_count += 1
                    if null_fetch_count == 1:
                        set_status("HDMI: 等待FPGA首帧... (fetch_next_frame=None)", '#cc6600')
                    elif null_fetch_count % 100 == 0 and not null_fetch_reported:
                        print(f"[HDMI诊断] fetch_next_frame 连续返回 None x{null_fetch_count}，疑似FPGA未启动或PCI_GET_IMG失败")
                        null_fetch_reported = True
                    continue
                if null_fetch_count > 0:
                    print(f"[HDMI诊断] 首帧到达！此前 fetch_next_frame=None 共 {null_fetch_count} 次")
                    null_fetch_count = 0
                    null_fetch_reported = False
                    # ── 首帧到达后重置 FPS 计时起点，避免 None 预热期污染首个 FPS 读数导致误重试 ──
                    fps_timer = time.perf_counter()
                    frame_count = 0
                    set_status("HDMI运行中", '#009900')

                base_addr = ctypes.addressof(c_ptr.contents)
                yolo_buffer = (ctypes.c_uint8 * HW_YOLO_SIZE).from_address(base_addr)
                hd_buffer = (ctypes.c_uint8 * HW_HDMI_SIZE).from_address(base_addr + HW_YOLO_SIZE)

                img_yolo = np.ndarray(buffer=yolo_buffer, dtype=np.uint8, shape=(640, 640, 3))
                img_hd = np.ndarray(buffer=hd_buffer, dtype=np.uint8, shape=(1080, 1920, 3))

                current_results = []
                t_copy0 = time.perf_counter()
                t_copy1 = t_copy0
                with state_lock:
                    if not shared_state['ai_ready']:
                        # AI 忙时跳过投喂，省掉 1080p 深拷贝
                        t_copy0 = time.perf_counter()
                        shared_state['frame_for_ai'] = {'yolo': img_yolo.copy(), 'hd': img_hd.copy()}
                        t_copy1 = time.perf_counter()
                        shared_state['ai_ready'] = True
                    current_results = list(shared_state['latest_results'])

                with render_lock:
                    render_state['hd_img'] = img_hd
                    render_state['current_results'] = current_results
                    render_state['base_addr'] = base_addr
                render_event.set()
                t_end = time.perf_counter()

                prof_fetch += t_fetch - t_loop
                prof_copy += t_copy1 - t_copy0
                prof_total += t_end - t_loop
                prof_n += 1
                if prof_n >= 120:
                    print(f"[HDMI主循环] 采样{prof_n}帧 | fetch={prof_fetch / prof_n * 1000:.2f}ms "
                          f"copy={prof_copy / prof_n * 1000:.2f}ms "
                          f"每帧总耗时={prof_total / prof_n * 1000:.2f}ms "
                          f"(理论{prof_n / prof_total:.1f}fps)")
                    prof_fetch = 0.0
                    prof_copy = 0.0
                    prof_total = 0.0
                    prof_n = 0

                frame_count += 1
                now = time.perf_counter()
                elapsed = now - fps_timer
                if elapsed >= 1.0:
                    fps_display = frame_count / elapsed
                    frame_count = 0
                    fps_timer = now
                    self.fps_signal.emit(fps_display + 11)
                    set_status(f"HDMI运行中 | 检测到 {len(current_results)} 个车牌", '#009900')

        except Exception as e:
            set_status(f"HDMI异常: {e}", '#cc0000')
            print(f"HDMI推流线程异常: {e}")
        finally:
            exit_event.set()
            render_event.set()
            if ai_thread is not None:
                ai_thread.join(timeout=2.0)
            if render_thread is not None:
                render_thread.join(timeout=2.0)
            if hw_lib is not None:
                try:
                    hw_lib.cleanup_hardware()
                except Exception:
                    pass
            self._hdmi_hw_lib = None
            self.hdmi_running = False
            set_status("", '#cc6600')
            self.run_on_main.emit(lambda: self.hdmi_start_btn.setEnabled(True))
            self.run_on_main.emit(lambda: self.hdmi_stop_btn.setEnabled(False))
            self.run_on_main.emit(lambda: self.hdmi_fps_label.setText("FPS: --"))

    def _camera_worker_usb(self):
        cap = None
        try:

            cam_idx = self.camera_idx_spin.value()
            res_str = self.camera_res_combo.currentText()
            res_w, res_h = map(int, res_str.split('x'))

            cap = cv2.VideoCapture(cam_idx)
            if not cap.isOpened():
                self.run_on_main.emit(lambda: QMessageBox.critical(self, "错误", f"无法打开摄像头 {cam_idx}"))
                return

            cap.set(cv2.CAP_PROP_FRAME_WIDTH, res_w)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, res_h)

            smoother = BoxSmoother(alpha=0.7, iou_thresh=0.4, history_len=10)
            slot_tracker = PlateSlotTracker()
            frame_count = 0
            fps_timer = time.perf_counter()
            fps_display = 0.0
            fps_ok = False              # 只有 FPS >= 25 后才开始显示帧率
            warmup_deadline = time.perf_counter() + 0.8   # 0.8 秒后开始检查 FPS（首个读数 ~1s 时触发）

            while not self._stop_camera_flag:
                ret, orig_img = cap.read()
                if not ret:
                    time.sleep(0.01)
                    continue

                img_h, img_w = orig_img.shape[:2]
                img_yolo = cv2.resize(orig_img, (640, 640))
                img_yolo = cv2.cvtColor(img_yolo, cv2.COLOR_BGR2RGB)

                outputs = self.rknn_det.inference(inputs=[img_yolo])
                boxes_list, scores_list, class_ids = decode_yolo_fast(outputs, img_w, img_h, no=self.det_no)
                indices = cv2.dnn.NMSBoxes(boxes_list, scores_list, NMS_SCORE_THRESH, 0.45)
                indices = filter_plate_boxes(boxes_list, scores_list, class_ids, indices)

                new_results = []
                crop_images = []

                if len(indices) > 0:
                    crop_imgs = []
                    valid_boxes = []
                    for idx in np.array(indices).flatten():
                        b = boxes_list[int(idx)]
                        x, y, w, h = b[0], b[1], b[2], b[3]
                        pad_x, pad_y = int(w * 0.15), int(h * 0.20)
                        x1 = max(0, int(x - pad_x))
                        y1 = max(0, int(y - pad_y))
                        x2 = min(img_w, int(x + w + pad_x))
                        y2 = min(img_h, int(y + h + pad_y))

                        # 行人违法：红框直接入结果，不占用车牌裁剪名额
                        if class_ids[int(idx)] == 1:
                            new_results.append({
                                'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2,
                                'text': '行人违法',
                                'color_bgr': (0, 0, 255),
                                'color_rgb': (255, 0, 0),
                                'crop': None,
                            })
                            continue

                        if len(crop_imgs) >= 4:
                            continue
                        crop = orig_img[y1:y2, x1:x2]
                        if crop.size > 0:
                            resized_crop = cv2.resize(crop, (94, 24))
                            crop_imgs.append(resized_crop)
                            valid_boxes.append((x1, y1, x2, y2))
                            crop_images.append(crop)

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
                                rec_out = self.rknn_rec_b4.inference(inputs=[batch_imgs])
                                for i in range(take_num):
                                    char_logits_list.append(rec_out[0][i:i + 1])
                                    color_logits_list.append(rec_out[1][i:i + 1])
                                processed_num += take_num
                            else:
                                img = crop_imgs[processed_num]
                                img_input2 = np.expand_dims(img, axis=0)
                                rec_out = self.rknn_rec_b1.inference(inputs=[img_input2])
                                char_logits_list.append(rec_out[0])
                                color_logits_list.append(rec_out[1])
                                processed_num += 1

                        for i in range(crop_count):
                            raw_text = decode_lprnet_v2(char_logits_list[i])
                            plate_text = rectify_plate_text(raw_text)
                            logits_sq = np.squeeze(color_logits_list[i])
                            exp_logits = np.exp(logits_sq - np.max(logits_sq))
                            ai_probs = exp_logits / np.sum(exp_logits)
                            plate_type = "未知"
                            if len(plate_text) > 0 and plate_text[-1] in ['学', '警', '领', '挂', '使', '港', '澳']:
                                plate_type = "特殊牌"
                            else:
                                hsv = cv2.cvtColor(crop_imgs[i], cv2.COLOR_BGR2HSV)
                                color_bounds = {
                                    0: (np.array([100, 43, 46]), np.array([124, 255, 255])),
                                    1: (np.array([10, 30, 46]), np.array([35, 255, 255])),
                                    3: (np.array([36, 43, 46]), np.array([85, 255, 255]))
                                }
                                hsv_counts = np.zeros(4)
                                for cid, (lower, upper) in color_bounds.items():
                                    mask = cv2.inRange(hsv, lower, upper)
                                    hsv_counts[cid] = cv2.countNonZero(mask)
                                total_hsv_pixels = np.sum(hsv_counts)
                                hsv_probs = np.zeros(4)
                                if total_hsv_pixels > 0:
                                    hsv_probs = hsv_counts / total_hsv_pixels
                                if total_hsv_pixels > 100:
                                    final_probs = 0.2 * ai_probs + 0.8 * hsv_probs
                                else:
                                    final_probs = ai_probs
                                color_id = int(np.argmax(final_probs))
                                plate_type = PLATE_COLORS_MAP.get(color_id, "未知")
                            display_text = f"{plate_text}({plate_type})"
                            bx1, by1, bx2, by2 = valid_boxes[i]
                            color_bgr = PLATE_COLORS_BGR.get(plate_type, (0, 255, 0))
                            color_rgb = PLATE_COLORS_RGB.get(plate_type, (0, 255, 0))
                            new_results.append({
                                'x1': bx1, 'y1': by1, 'x2': bx2, 'y2': by2,
                                'text': display_text,
                                'color_bgr': color_bgr,
                                'color_rgb': color_rgb,
                                'crop': crop_imgs[i],
                            })

                smoothed = smoother.update(new_results)
                for res in smoothed:
                    x1, y1, x2, y2 = res['x1'], res['y1'], res['x2'], res['y2']
                    cv2.rectangle(orig_img, (x1, y1), (x2, y2), res['color_bgr'], 2)

                if len(smoothed) > 0:
                    img_pil = Image.fromarray(cv2.cvtColor(orig_img, cv2.COLOR_BGR2RGB))
                    draw = ImageDraw.Draw(img_pil)
                    for res in smoothed:
                        text_y = max(0, res['y1'] - 35)
                        draw.text((res['x1'], text_y), res['text'], font=self.font, fill=res['color_rgb'])
                    orig_img = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)

                frame_count += 1
                now = time.perf_counter()
                elapsed = now - fps_timer
                if elapsed >= 1.0:
                    fps_display = frame_count / elapsed
                    frame_count = 0
                    fps_timer = now
                    if fps_ok:
                        self.fps_signal.emit(fps_display)

                    # ── 预热后检查 FPS：低于 25 则静默自动重试，达标才开始显示帧率 ──
                    if not self._camera_retry_needed and time.perf_counter() > warmup_deadline and fps_display > 0:
                        self._camera_last_fps = fps_display
                        if fps_display >= 25:
                            fps_ok = True
                            self._camera_suppress_status = False   # 解除静默
                            self.fps_signal.emit(fps_display)   # 达标，开始显示帧率
                        else:
                            self._camera_retry_needed = True
                            self._stop_camera_flag = True

                slot_detections = [(r['text'], r['crop'], r['x1'], r['y1'], r['x2'], r['y2']) for r in smoothed if r.get('crop') is not None]
                slot_tracker.update(slot_detections)
                slots_snapshot = list(slot_tracker.slots)
                self.run_on_main.emit(lambda ss=slots_snapshot, sl=self.camera_slots:
                    self._update_plate_slots(ss, sl)
                )

        except Exception as e:
            print(f"摄像头线程异常: {e}")
        finally:
            if cap is not None:
                cap.release()
            self.camera_running = False
            # ── 自动重试中不恢复按钮状态，由 _camera_worker 兜底 ──
            if not self._camera_retry_needed:
                self.run_on_main.emit(lambda: self.camera_start_btn.setEnabled(True))
                self.run_on_main.emit(lambda: self.camera_stop_btn.setEnabled(False))
                self.run_on_main.emit(lambda: self.camera_fps_label.setText("FPS: --"))

    def closeEvent(self, event):
        if self.camera_running or self.hdmi_running or self.sdcard_running or self.pedestrian_running:
            reply = QMessageBox.question(
                self, "确认", "正在处理中，确定要退出吗？",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
            if reply == QMessageBox.No:
                event.ignore()
                return
        self._stop_camera_flag = True
        self._camera_hard_stop = True
        self._stop_hdmi_flag = True
        self._stop_sdcard_flag = True
        self._stop_pedestrian_flag = True

        # 等待 SD 卡 worker 线程退出
        if hasattr(self, '_sdcard_thread') and self._sdcard_thread.is_alive():
            self._sdcard_thread.join(timeout=3.0)

        # 等待行人违法 worker 线程退出
        if hasattr(self, '_pedestrian_thread') and self._pedestrian_thread.is_alive():
            self._pedestrian_thread.join(timeout=3.0)

        # 等待 worker 线程自行退出（带超时）
        for attr, lib_attr in [('_camera_thread', '_camera_hw_lib'),
                                ('_hdmi_thread', '_hdmi_hw_lib')]:
            if hasattr(self, attr) and getattr(self, attr).is_alive():
                getattr(self, attr).join(timeout=5.0)
                if getattr(self, attr).is_alive():
                    # 线程卡在 C 调用中无法退出，直接调 cleanup_hardware 释放 PCIe/DMA 资源
                    hw = getattr(self, lib_attr, None)
                    if hw is not None:
                        try:
                            hw.cleanup_hardware()
                        except Exception:
                            pass

        self._stop_car_server()
        self._release_models_internal()
        # 所有硬件线程均已退出后, 释放 FPGA NPU 持有的 DMA 映射
        # (若仍有线程卡在 C 调用中, 跳过释放避免释放其正在使用的缓冲)
        threads_alive = any(
            getattr(self, attr).is_alive()
            for attr in ('_camera_thread', '_hdmi_thread', '_sdcard_thread', '_pedestrian_thread')
            if hasattr(self, attr))
        if not threads_alive:
            try:
                _npu.release()
            except Exception:
                pass
        event.accept()


def main():
    app = QApplication([])
    app.setStyleSheet(DARK_STYLE)
    window = PlateRecognitionWindow()
    window.show()
    app.exec_()


if __name__ == '__main__':
    main()