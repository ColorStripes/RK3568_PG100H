#!/bin/sh

driver="pango_pci_driver"
root_name="root"                                    
temp_name=$(whoami)                                 

# ================= 提权 =================
if [ "$temp_name" != "$root_name" ]; then
    echo "当前操作用户名：$temp_name"
    echo "检测到需要管理员权限，正在自动提权并保留环境变量"
    exec sudo -E sh "$0" "$@"
fi
# ======================================================

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
echo "***************************启动 Python 零拷贝推理************************"
echo "正在挂起 Linux 桌面环境"
sudo systemctl stop lightdm 
sleep 1 # 稍微等1秒，确保桌面完全释放 DRM 权限

# 运行 Python 脚本
python3 test_zero_copy.py

# 4. 退出与清理
echo "***************************退出可执行程序************************"
echo "正在恢复 Linux 桌面环境"
sudo systemctl start lightdm

echo "***************************卸载PCIe驱动**************************"
if [ `lsmod | grep -o "$driver"` ]; then
    rmmod $driver                                       
fi
echo "系统已恢复正常。"