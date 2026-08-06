# -*- coding: utf-8 -*-
"""
控制仲裁器 — 管理 AUTO/MANUAL/EMERGENCY 三种模式的电机指令转发
AUTO 模式: 接收 YOLO 障碍物检测结果，自动启停
MANUAL 模式: 接收 Web UI 方向指令
EMERGENCY: 强制停止，锁定直到手动解除
"""

import threading
import time
import logging

from motor import MotorController

logger = logging.getLogger("arbiter")

# 模式常量
MODE_AUTO = "auto"
MODE_MANUAL = "manual"
MODE_EMERGENCY = "emergency"

# AUTO 模式下，无障碍物时连续多少帧才恢复前进
AUTO_CLEAR_FRAMES = 3
# AUTO 模式下，超过多少秒没收到 AI 帧就自动停止
AUTO_STALE_TIMEOUT = 2.0


class ControlArbiter:
    def __init__(self, motor: MotorController):
        self._motor = motor
        self._lock = threading.Lock()
        self._mode = MODE_MANUAL
        self._stop_frame_count = 0
        self._last_ai_frame_time = 0.0
        self._was_stopped = False
        self._car_state = {
            "mode": MODE_MANUAL,
            "action": "stop",
            "speed": 0.0,
            "obstacle": False,
        }

    # ── 模式管理 ──
    @property
    def mode(self):
        with self._lock:
            return self._mode

    def switch_mode(self, new_mode):
        with self._lock:
            if new_mode not in (MODE_AUTO, MODE_MANUAL, MODE_EMERGENCY):
                return
            self._mode = new_mode
            self._stop_frame_count = 0
            self._was_stopped = False
            self._car_state["mode"] = new_mode
            self._motor.stop()
            logger.info("arbiter: 切换到 %s 模式", new_mode)

    def set_emergency(self):
        with self._lock:
            self._mode = MODE_EMERGENCY
            self._motor.stop()
            self._car_state.update(mode=MODE_EMERGENCY, action="emergency_stop")
            logger.warning("arbiter: 紧急停止!")

    def clear_emergency(self):
        with self._lock:
            if self._mode == MODE_EMERGENCY:
                self._mode = MODE_MANUAL
                self._car_state["mode"] = MODE_MANUAL
                logger.info("arbiter: 紧急停止解除，回到 MANUAL 模式")

    # ── AI 更新 (AUTO 模式专用) ──
    def update_from_ai(self, obstacle_detected: bool):
        """
        AI 线程每帧调用，传入当前是否检测到障碍物。
        仅在 AUTO 模式下生效。
        """
        with self._lock:
            self._last_ai_frame_time = time.monotonic()

            if self._mode != MODE_AUTO:
                return

            if obstacle_detected:
                self._stop_frame_count = 0
                self._motor.stop()
                if not self._was_stopped:
                    logger.info("[AUTO] 障碍物检测 → STOP")
                    self._was_stopped = True
                self._car_state.update(action="stop", obstacle=True)
            else:
                self._stop_frame_count += 1
                if self._stop_frame_count >= AUTO_CLEAR_FRAMES:
                    self._motor.forward()
                    if self._was_stopped:
                        logger.info("[AUTO] 无障碍 → GO")
                        self._was_stopped = False
                    self._car_state.update(action="forward", obstacle=False)

    def check_stale(self):
        """
        主循环调用：AUTO 模式下若 AI 帧超时未到达，自动停止。
        """
        with self._lock:
            if self._mode != MODE_AUTO:
                return
            if time.monotonic() - self._last_ai_frame_time > AUTO_STALE_TIMEOUT:
                self._motor.stop()
                self._car_state.update(action="stale_stop")
                if not self._was_stopped:
                    logger.warning("[AUTO] AI 帧超时 → 自动停止")
                    self._was_stopped = True

    # ── MANUAL 模式指令 ──
    def manual_command(self, action, speed=None):
        """
        Web UI 调用：仅在 MANUAL 模式下执行。
        action: forward | backward | turn_left | turn_right |
                spin_left | spin_right | stop
        """
        with self._lock:
            if self._mode == MODE_EMERGENCY:
                return False
            if self._mode == MODE_AUTO:
                # AUTO 模式下，只允许切换到 MANUAL
                return False

            method = getattr(self._motor, action, None)
            if method is None:
                return False
            if speed is not None:
                method(speed)
            else:
                method()
            self._car_state["action"] = action
            self._car_state["speed"] = speed or self._motor._speed
            return True

    # ── 状态快照 (供 Web API 读取) ──
    def get_state(self):
        with self._lock:
            return dict(self._car_state)


class ArbiterCommand:
    """AUTO 模式下回传给 AI 线程的命令——将来扩展用 (如巡线、定点停车)"""
    pass