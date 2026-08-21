#!/bin/bash

driver="pango_pci_driver"
root_name="root"
temp_name=$(whoami)

# ================= 提权 =================
if [ "$temp_name" != "$root_name" ]; then
    echo "检测到需要管理员权限，自动提权"
    exec sudo -E bash "$0" "$@"
fi

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"

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
# bear -- make 2>/dev/null || make
make 2>/dev/null || make

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
#    三个源文件联合编译: PCIe DMA 底层 + RGA/DRM 相机管线 + FPGA NPU 推理
#    单一动态库架构: 相机 (1280×720) / HDMI (1920×1080) / FPGA_NPU 共用
#    libdma_rga.so, 分辨率由 set_pipeline_resolution 运行时切换。
#    内核驱动 DMA 缓冲全局只允许分配一次, 所有模块共享同一份 fd/mmap。
# ======================================================
SO_CFLAGS="-fPIC -shared -O3 -I./app_pcie/includes -I/usr/include/libdrm -I/usr/include/drm `pkg-config --cflags opencv4 gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-allocators-1.0`"
SO_LIBS="-lrga -ldrm `pkg-config --libs opencv4 gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-allocators-1.0` -lpthread"
SO_SRCS="./app_pcie/sources/pci_dma_bridge.cpp ./app_pcie/sources/dma_bridge_rga.cpp ./app_pcie/sources/fpga_npu_bridge.cpp ./app_pcie/sources/gst_decoder.cpp"

echo "************************编译 libdma_rga.so (相机/HDMI/FPGA_NPU 合并库) ************************"
rm -f libdma_rga.so
g++ $SO_CFLAGS $SO_SRCS -o libdma_rga.so $SO_LIBS

if [ ! -f "libdma_rga.so" ]; then
    echo "动态库编译失败！"
    rmmod $driver
    exit 1
fi
echo "libdma_rga.so 编译成功 (含相机/HDMI/FPGA_NPU 接口)"

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
# if [ `lsmod | grep -o "$driver"` ]; then
#     rmmod $driver
# fi
echo "清理完成 (退出码: $EXIT_CODE)"
exit $EXIT_CODE