#!/bin/bash

# 确保开机时 PWM 节点被正确激活
if [ ! -d /sys/class/pwm/pwmchip0/pwm0 ]; then
    echo 0 > /sys/class/pwm/pwmchip0/export 2>/dev/null
    sleep 1
fi

while true; do
    # 读取温度
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    
    if [ "$temp" -gt 1000 ]; then
        temp=$((temp / 1000))
    fi

    # 温度判断逻辑
    if [ "$temp" -ge 70 ]; then
        /usr/local/bin/fan_ctrl -p 100 >/dev/null 2>&1
    elif [ "$temp" -ge 60 ]; then
        /usr/local/bin/fan_ctrl -p 70 >/dev/null 2>&1
    elif [ "$temp" -ge 50 ]; then
        /usr/local/bin/fan_ctrl -p 40 >/dev/null 2>&1
    else
        /usr/local/bin/fan_ctrl -k >/dev/null 2>&1
    fi
    
    # 休息 5 秒再测
    sleep 5
done