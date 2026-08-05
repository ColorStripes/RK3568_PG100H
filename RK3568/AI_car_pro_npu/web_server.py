# -*- coding: utf-8 -*-
"""
小车 Web 控制台 — Flask + MJPEG 视频流 + 摇杆控制
API:
  GET  /               → 控制台页面
  GET  /video_feed     → MJPEG 视频流
  POST /api/motor      → { "action": "forward", "speed": 0.6 }
  POST /api/mode       → { "mode": "auto" | "manual" }
  GET  /api/state      → 当前状态 JSON
"""

import threading
import time
import json
import cv2
import numpy as np
from flask import Flask, Response, request, jsonify

app = Flask(__name__)

# 全局引用，由 main.py 注入
_arbiter = None
_frame_src = None   # callable: () -> np.ndarray | None
_frame_lock = threading.Lock()

PORT = 5000

# ── 配置注入 ──
def configure(arbiter, frame_getter):
    global _arbiter, _frame_src
    _arbiter = arbiter
    _frame_src = frame_getter

# ── MJPEG 生成器 ──
def _mjpeg_generator():
    while True:
        frame = None
        if _frame_src:
            frame = _frame_src()
        if frame is not None:
            ret, jpeg = cv2.imencode(".jpg", frame)
            if ret:
                yield (b"--frame\r\n"
                       b"Content-Type: image/jpeg\r\n\r\n" +
                       jpeg.tobytes() + b"\r\n")
        time.sleep(0.03)

# ── 路由 ──
@app.route("/")
def index():
    return _HTML

@app.route("/video_feed")
def video_feed():
    return Response(_mjpeg_generator(),
                    mimetype="multipart/x-mixed-replace; boundary=frame")

@app.route("/api/motor", methods=["POST"])
def api_motor():
    data = request.get_json(force=True, silent=True) or {}
    action = data.get("action", "stop")
    speed = data.get("speed", None)
    if _arbiter:
        ok = _arbiter.manual_command(action, speed)
        return jsonify({"ok": ok, "action": action})
    return jsonify({"ok": False, "error": "arbiter not ready"})

@app.route("/api/mode", methods=["POST"])
def api_mode():
    data = request.get_json(force=True, silent=True) or {}
    mode = data.get("mode", "manual")
    if _arbiter:
        _arbiter.switch_mode(mode)
        return jsonify({"ok": True, "mode": mode})
    return jsonify({"ok": False, "error": "arbiter not ready"})

@app.route("/api/state")
def api_state():
    if _arbiter:
        return jsonify(_arbiter.get_state())
    return jsonify({"mode": "unknown", "action": "stop"})

# ── 启动函数 ──
def start_server():
    threading.Thread(target=app.run, kwargs={
        "host": "0.0.0.0",
        "port": PORT,
        "debug": False,
        "threaded": True,
    }, daemon=True).start()

# ============================================================
# 前端 HTML 页面
# ============================================================
_HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>小车控制台</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#111;color:#eee;font-family:Arial,Helvetica,sans-serif;
     display:flex;flex-direction:column;align-items:center;min-height:100vh;overflow-x:hidden}
h2{margin:10px 0 4px;font-size:18px}
#video{width:100vw;max-width:640px;border:2px solid #333;display:block}
#status{font-size:13px;margin:4px 0;color:#aaa}

/* 摇杆区 */
#joystick-area{position:relative;width:200px;height:200px;margin:10px auto;
  border-radius:50%;background:#222;border:2px solid #444;touch-action:none}
#knob{position:absolute;width:64px;height:64px;border-radius:50%;
  background:#e74c3c;left:68px;top:68px;transition:background .1s}
#knob.active{background:#c0392b}

/* 按钮区 */
.btns{display:grid;grid-template-columns:80px 80px 80px;gap:6px;margin:8px}
.btns button{padding:12px 0;font-size:16px;border:none;border-radius:8px;
  background:#333;color:#eee;cursor:pointer}
.btns button:active{background:#555}
.btns .stop-btn{background:#c0392b}
.btns .stop-btn:active{background:#e74c3c}

/* 模式 & 速度 */
.controls{display:flex;align-items:center;gap:12px;margin:6px;flex-wrap:wrap}
.controls label{font-size:13px}
#speed{width:120px}
#mode-toggle{padding:6px 16px;border:none;border-radius:6px;font-size:14px;cursor:pointer;
  background:#2980b9;color:#fff}
#mode-toggle.auto{background:#27ae60}
#e-stop{padding:6px 16px;border:none;border-radius:6px;font-size:14px;cursor:pointer;
  background:#c0392b;color:#fff}
</style>
</head>
<body>

<h2>小车实时画面</h2>
<img id="video" src="/video_feed" alt="video">
<div id="status">状态: 连接中...</div>

<div id="joystick-area">
  <div id="knob"></div>
</div>
<div style="color:#888;font-size:11px">拖动摇杆控制方向</div>

<div class="btns">
  <button onclick="send('spin_left')">&#x21BA;</button>
  <button onclick="send('forward')">&#x2B06;</button>
  <button onclick="send('spin_right')">&#x21BB;</button>
  <button onclick="send('turn_left')">&#x2B05;</button>
  <button onclick="send('stop')" class="stop-btn">&#x23F9;</button>
  <button onclick="send('turn_right')">&#x27A1;</button>
  <div></div>
  <button onclick="send('backward')">&#x2B07;</button>
  <div></div>
</div>

<div class="controls">
  <label>速度: <span id="speed-val">60%</span></label>
  <input id="speed" type="range" min="20" max="100" value="60" oninput="onSpeed()">
  <button id="mode-toggle" onclick="toggleMode()">AUTO</button>
  <button id="e-stop" onclick="fetch('/api/motor',{method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'stop'})})">
    急停</button>
</div>

<script>
let currentMode = 'manual';
let speed = 0.6;

// ── 摇杆 ──
const area = document.getElementById('joystick-area');
const knob = document.getElementById('knob');
const cx = 100, cy = 100, rmax = 55;
let dragging = false, activeAction = null;

function getPos(e){
  const t = e.touches ? e.touches[0] : e;
  const rect = area.getBoundingClientRect();
  return {x:t.clientX-rect.left-cx, y:t.clientY-rect.top-cy};
}
function clamp(v,m){return Math.max(-m,Math.min(m,v))}

function updateKnob(dx,dy){
  const d = Math.sqrt(dx*dx+dy*dy);
  const s = d>rmax ? rmax/d : 1;
  const kx = clamp(dx*s,-rmax,rmax), ky = clamp(dy*s,-rmax,rmax);
  knob.style.left = (cx + kx - 32) + 'px';
  knob.style.top  = (cy + ky - 32) + 'px';
  // 方向映射
  if(d<15){ return send('stop'); }
  let act;
  if(Math.abs(dx)>Math.abs(dy)){
    act = dx>0 ? 'turn_right' : 'turn_left';
  }else{
    act = dy>0 ? 'backward' : 'forward';
  }
  if(act !== activeAction){ activeAction=act; send(act); }
}

area.addEventListener('touchstart',e=>{e.preventDefault();dragging=true;knob.classList.add('active')});
area.addEventListener('touchmove',e=>{e.preventDefault();if(!dragging)return;const p=getPos(e);updateKnob(p.x,p.y)});
area.addEventListener('touchend',e=>{dragging=false;knob.classList.remove('active');knob.style.left='68px';knob.style.top='68px';activeAction=null;send('stop')});

area.addEventListener('mousedown',e=>{dragging=true;knob.classList.add('active')});
area.addEventListener('mousemove',e=>{if(!dragging)return;const p=getPos(e);updateKnob(p.x,p.y)});
area.addEventListener('mouseup',e=>{dragging=false;knob.classList.remove('active');knob.style.left='68px';knob.style.top='68px';activeAction=null;send('stop')});

// ── 指令发送 ──
function send(action){
  fetch('/api/motor',{method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({action:action,speed:speed})
  });
}

// ── 模式切换 ──
function toggleMode(){
  const btn = document.getElementById('mode-toggle');
  if(currentMode==='manual'){
    currentMode='auto';btn.textContent='MANUAL';btn.classList.add('auto');
  }else{
    currentMode='manual';btn.textContent='AUTO';btn.classList.remove('auto');
  }
  fetch('/api/mode',{method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({mode:currentMode})
  });
}

function onSpeed(){
  speed = parseInt(document.getElementById('speed').value)/100;
  document.getElementById('speed-val').textContent = Math.round(speed*100)+'%';
}

// ── 状态轮询 ──
setInterval(()=>{
  fetch('/api/state').then(r=>r.json()).then(s=>{
    document.getElementById('status').textContent =
      '模式: '+s.mode+' | 动作: '+s.action+' | 障碍物: '+(s.obstacle?'是':'否');
    const btn = document.getElementById('mode-toggle');
    if(s.mode==='auto' && !btn.classList.contains('auto')){
      currentMode='auto';btn.textContent='MANUAL';btn.classList.add('auto');
    }else if(s.mode==='manual' && btn.classList.contains('auto')){
      currentMode='manual';btn.textContent='AUTO';btn.classList.remove('auto');
    }
  });
},500);
</script>
</body>
</html>"""