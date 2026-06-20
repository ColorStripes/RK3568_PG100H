#!/bin/bash

driver="pango_pci_driver"
root_name="root"                                    
temp_name=$(whoami)                                 

# ================= 提权 =================
if [ "$temp_name" != "$root_name" ]; then
    echo "当前操作用户名：$temp_name"
    echo "检测到需要管理员权限，正在自动提权并保留环境变量"
    exec sudo -E bash "$0" "$@"
fi
# ======================================================

# ── 退出时自动清理背景音乐进程 ──
cleanup_audio() {
    if [ -n "$AUDIO_PID" ] && kill -0 "$AUDIO_PID" 2>/dev/null; then
        pkill -P "$AUDIO_PID" 2>/dev/null
        kill -9 "$AUDIO_PID" 2>/dev/null
        wait "$AUDIO_PID" 2>/dev/null
    fi
}
trap cleanup_audio EXIT INT TERM

#  强制清理上次可能崩溃残留的死锁驱动
if [ `lsmod | grep -o "$driver"` ]; then
    echo "发现残留的 PCIe 驱动，正在强制卸载释放资源"
    rmmod $driver
    sleep 1
fi

echo "****************************复位PCIe设备***************************"
sh ../reset_pcie.sh
sleep 1

echo "*************************开始编译PCIe驱动程序************************"
cd ./driver
make clean
# make
bear -- make
echo "***************************开始装载PCIe驱动**************************"
insmod $driver.ko                               
cd ..

if [ `lsmod | grep -o "$driver"` ]; then
    echo "***************************PCIe驱动装载成功**************************"
else
    echo " PCIe驱动装载失败，请检查硬件！"
    exit 1
fi

# 2. 编译 C++ 动态链接库 (.so)
echo "*************************开始编译底层 C++ 动态库************************"
# 删除旧的库文件，确保每次都是全新编译
rm -f libdma_rga.so
# 编译包含了 DRM 硬件多图层支持的终极引擎
g++ -fPIC -shared ./app_pcie/sources/dma_bridge_rga.cpp -o libdma_rga.so -I/usr/include/libdrm -I/usr/include/drm -lrga -ldrm

if [ ! -f "libdma_rga.so" ]; then
    echo " 动态库编译失败！请检查 C++ 代码是否有语法错误。"
    rmmod $driver
    exit 1
fi
echo " 动态库 libdma_rga.so 编译成功！"

# 3. 启动 Python AI 推理
echo "***************************启动 Python 障碍物检测推理************************"
echo "正在挂起 Linux 桌面环境"
sudo systemctl stop lightdm 
sleep 1 # 稍微等1秒，确保桌面完全释放 DRM 权限

# 运行 Python 脚本（YOLO 障碍物检测 + GPIO 自动启停）

# ── 启动背景音乐循环播放 ──
AUDIO_FILE="/home/linaro/workspace/111.mp3"

# ── 强制初始化 ALSA 硬件 ──
alsactl init 2>/dev/null
sleep 0.2

# ── 打印诊断信息 ──
echo "========== ALSA 声卡列表 =========="
aplay -l 2>/dev/null
echo "========== amixer -c 0 scontrols =========="
amixer -c 0 scontrols 2>&1
echo "========== amixer -c 0 contents (前30行) =========="
amixer -c 0 contents 2>&1 | head -30
echo "=================================="

# ── 解静音 + 拉满音量（ES8388 声卡 card 0）──
for ctl in Master PCM Playback Headphone Speaker 'Line Out' DAC 'Analog Output' \
           'Headset' 'Right Output Mixer PCM' 'Left Output Mixer PCM' \
           'Right Output Mixer' 'Left Output Mixer' 'Output Mixer' \
           'hp switch' 'spk switch'; do
    amixer -c 0 sset "$ctl" unmute 60% 2>/dev/null
done

# ES8388 特定路由：把 PCM 信号打到输出
amixer -c 0 sset 'Right Output Mixer PCM' on 2>/dev/null
amixer -c 0 sset 'Left Output Mixer PCM' on 2>/dev/null
amixer -c 0 sset 'Playback' unmute 95% 2>/dev/null

# ── 探测非 HDMI 播放设备（遍历所有卡）──
ALSA_DEVICE=""
HDMI_DEVICE=""
for card in $(aplay -l 2>/dev/null | awk '/^card/{print $2}' | tr -d ':'); do
    card_line=$(aplay -l 2>/dev/null | awk "/^card $card:/{print; exit}")
    if echo "$card_line" | grep -qi 'hdmi'; then
        [ -z "$HDMI_DEVICE" ] && HDMI_DEVICE="hw:$card,0"
    else
        ALSA_DEVICE="hw:$card,0"
        break
    fi
done

[ -z "$ALSA_DEVICE" ] && ALSA_DEVICE="$HDMI_DEVICE"
[ -z "$ALSA_DEVICE" ] && ALSA_DEVICE="default"
echo "[音频] 选定设备: $ALSA_DEVICE"

_play_loop_alsa() {
    if command -v aplay >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
        echo "[音频] aplay + ffmpeg → $ALSA_DEVICE"
        while true; do
            ffmpeg -i "$AUDIO_FILE" -f s16le -acodec pcm_s16le -ar 44100 -ac 2 - 2>/dev/null \
                | aplay -D "$ALSA_DEVICE" -f S16_LE -r 44100 -c 2 -q 2>/dev/null
            sleep 0.1
        done &
        AUDIO_PID=$!
        return 0
    fi
    if command -v ffplay >/dev/null 2>&1; then
        echo "[音频] ffplay → $ALSA_DEVICE"
        SDL_AUDIODRIVER=alsa AUDIODEV="$ALSA_DEVICE" \
            ffplay -nodisp -loop 0 -loglevel quiet "$AUDIO_FILE" &
        AUDIO_PID=$!
        return 0
    fi
    if command -v mpg123 >/dev/null 2>&1; then
        echo "[音频] mpg123 → $ALSA_DEVICE"
        mpg123 -q --loop -1 -o alsa -a "$ALSA_DEVICE" "$AUDIO_FILE" &
        AUDIO_PID=$!
        return 0
    fi
    if command -v mpv >/dev/null 2>&1; then
        echo "[音频] mpv → $ALSA_DEVICE"
        mpv --no-video --loop=inf --audio-device="alsa/$ALSA_DEVICE" --really-quiet "$AUDIO_FILE" &
        AUDIO_PID=$!
        return 0
    fi
    if command -v aplay >/dev/null 2>&1; then
        echo "[音频] aplay → $ALSA_DEVICE"
        while true; do aplay -D "$ALSA_DEVICE" -q "$AUDIO_FILE" 2>/dev/null; sleep 0.1; done &
        AUDIO_PID=$!
        return 0
    fi
    return 1
}

if ! _play_loop_alsa; then
    echo "[音频] 无可用播放器，跳过"
    AUDIO_PID=""
fi

python3 test_zero_copy.py

# ── 停止背景音乐 ──
if [ -n "$AUDIO_PID" ] && kill -0 "$AUDIO_PID" 2>/dev/null; then
    pkill -P "$AUDIO_PID" 2>/dev/null
    kill -9 "$AUDIO_PID" 2>/dev/null
    wait "$AUDIO_PID" 2>/dev/null
    echo "[音频] 背景音乐已停止"
fi

# 4. 退出与清理
echo "***************************退出可执行程序************************"
echo "正在恢复 Linux 桌面环境"
sudo systemctl start lightdm

echo "***************************卸载PCIe驱动**************************"
if [ `lsmod | grep -o "$driver"` ]; then
    rmmod $driver                                       
fi
echo "系统已恢复正常。"