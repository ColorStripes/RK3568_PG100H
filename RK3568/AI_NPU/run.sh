#!/bin/sh

driver="pango_pci_driver"
target="npu"
root_name="root"
temp_name=$(whoami)

if [ "$temp_name" != "$root_name" ]; then
    echo "当前操作用户名：$temp_name"
    echo "检测到需要管理员权限，正在自动提权并保留环境变量..."
    exec sudo -E sh "$0" "$@"
fi

BASE=$(dirname "$(readlink -f "$0")")

echo "****************************复位PCIe设备***************************"
sh "$BASE/../reset_pcie.sh"

if [ `lsmod | grep -o "$driver"` ]; then
    echo "****************************检测到PCIe驱动已装载，先卸载***************************"
    rmmod $driver
fi

echo "*************************编译PCIe驱动程序************************"
cd "$BASE/driver"
make clean
make
echo "***************************装载PCIe驱动**************************"
insmod $driver.ko
if [ `lsmod | grep -o "$driver"` ]; then
    echo "***************************PCIe驱动装载成功**************************"
else
    echo "***************************PCIe驱动装载失败**************************"
    exit 1
fi
cd "$BASE"

echo "*************************编译NPU推理程序************************"
cd "$BASE/app_pcie"
make clean
make $target
cd "$BASE"

echo "***************************启动NPU推理************************"
./app_pcie/build/npu_inference \
    ./npu_data/weight_bin \
    ./npu_data/instruction_all.txt \
    ./npu_data/output \
    ./npu_data/indata_bin/focus_data.bin

echo "***************************NPU推理完成************************"
rmmod $driver
echo "***************************卸载PCIe驱动**************************"
