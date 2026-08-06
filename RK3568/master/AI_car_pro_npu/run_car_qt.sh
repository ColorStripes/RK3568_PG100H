#!/bin/bash

driver="pango_pci_driver"
root_name="root"
temp_name=$(whoami)

# ================= 提权 =================
if [ "$temp_name" != "$root_name" ]; then
    echo "检测到需要管理员权限，自动提权"
    exec sudo -E bash "$0" "$@"
fi

PROJ_DIR="/home/linaro/workspace/AI_car_pro"

# ======================================================
# 1. 加载 PCIe 驱动
# ======================================================
echo "************************加载 PCIe 驱动************************"

if [ `lsmod | grep -o "$driver"` ]; then
    echo "卸载残留驱动..."
    rmmod $driver
    sleep 1
fi

echo "复位PCIe设备..."
sh /home/linaro/workspace/reset_pcie.sh 2>/dev/null || true
sleep 1

cd "$PROJ_DIR"

echo "编译并装载PCIe驱动..."
cd ./driver
make clean 2>/dev/null
bear -- make 2>/dev/null || make
insmod $driver.ko
cd ..

if [ `lsmod | grep -o "$driver"` ]; then
    echo "PCIe驱动装载成功"
else
    echo "PCIe驱动装载失败！"
    exit 1
fi

# ======================================================
# 2. 编译 C++ 桥接 .so
# ======================================================
echo "************************编译 libdma_rga.so (HDMI 1920x1080) ************************"
rm -f libdma_rga.so
g++ -fPIC -shared ./app_pcie/sources/dma_bridge_rga.cpp -o libdma_rga.so \
    -I/usr/include/libdrm -I/usr/include/drm -lrga -ldrm

echo "************************编译 libdma_rga_camera.so (摄像头 1280x720) ************************"
rm -f libdma_rga_camera.so
g++ -fPIC -shared -DCAMERA_MODE ./app_pcie/sources/dma_bridge_rga.cpp -o libdma_rga_camera.so \
    -I/usr/include/libdrm -I/usr/include/drm -lrga -ldrm

if [ ! -f "libdma_rga.so" ] || [ ! -f "libdma_rga_camera.so" ]; then
    echo "动态库编译失败！"
    rmmod $driver
    exit 1
fi
echo "libdma_rga.so 编译成功"

# ======================================================
# 3. 启动 Qt UI
# ======================================================
echo "**********************启动小车 Qt 控制台***********************"

cd "$PROJ_DIR"
python3 car_qt.py
EXIT_CODE=$?

# ======================================================
# 4. 清理
# ======================================================
echo "***************************清理资源****************************"
sleep 0.5
if [ `lsmod | grep -o "$driver"` ]; then
    rmmod $driver
fi
echo "清理完成 (退出码: $EXIT_CODE)"
exit $EXIT_CODE