# SDK修改设备树（编译boot.img)

## docker镜像加载

### 加载SDK套件环境

```shell
sudo docker load < Meyesemi_RKLinux_SDK_Build_Environment_Docker_V1.0.tar
```

查询加载

```shell
sudo docker image ls
```



### 创建docker容器

```shell
sudo docker run --privileged -it -u root -v $Host_contents:$Docker_contents $ImageID /bin/bash
```

$ImageID：docker_rk

$Host_contents：主机目录

$Docker_contents：/home/hjf/SDK



### 安装包

麻烦一条一条输入有错误

```shell
sudo apt-get update
sudo apt-get remove live-build
sudo apt-get install binfmt-support qemu-user-static --reinstall
sudo update-binfmts --enable qemu-aarch64
git clone https://salsa.debian.org/live-team/live-build.git --depth 1 -b debian/1%20230131cd live-build
rm -rf manpages/po/
sudo make install -j8
cd ..
```





## SDK编译

### 进入docker

```shell
sudo docker exec -it -w $cwd_contents $containerID /bin/bash
cd /home/hjf/SDK
```

#$cwd_contents：容器内 SDK 根目录

#$containerID：容器 ID







### 此过程需要UID1001 （创建用户）

```SHELL
groupadd newsgroup
useradd -M -u 1001 -g newsgroup newsperson
usermod -aG sudo newsperson
mkdir -p /home/newsperson
chown newsperson:newsgroup /home/newspersonchmod 700 /home/newsperson
usermod -s /bin/bash newsperson
id 1001
su - newsperson
```









### 上传Linux源码

到$Host_contents：主机目录下

在docker映射目录下解压 /home/hjf/SDK

```shell
sudo tar -xzvf MES_3568JBAF.tar.gz
```



### 内核源码修改

```shell
cd RK3568J_SDK/
```



查看设备树 末尾应该是干净的

```shell
vim kernel/arch/arm64/boot/dts/rockchip/rk3568-evb1-ddr4-v10.dts
```



追加设备：追加PWM12,13 超频CPU,GPU

```dtd
cat >> kernel/arch/arm64/boot/dts/rockchip/rk3568-evb1-ddr4-v10.dtsi << "EOF"

&pwm12 {
        status = "okay";
        pinctrl-names = "active";
        pinctrl-0 = <&pwm12m0_pins>;
};

&pwm13 {
        status = "okay";
        pinctrl-names = "active";
        pinctrl-0 = <&pwm13m0_pins>;
};

&cpu0_opp_table {
        opp-1800000000 {
                opp-supported-hw = <0xff 0xffff>;
        };
        opp-1992000000 {
                opp-supported-hw = <0xff 0xffff>;
        };
};

&gpu_opp_table {
        opp-800000000 {
                opp-supported-hw = <0xff 0xffff>;
        };
};

&npu_opp_table {
        opp-900000000 {
                opp-supported-hw = <0xff 0xffff>;
        };
        opp-1000000000 {
                status = "okay";
                opp-supported-hw = <0xff 0xffff>;
        };
};
EOF
```





清理缓存编译：

```shell
rm -f kernel/arch/arm64/boot/dts/rockchip/*.dtb
sudo ./build.sh kernel
```



这种情况选择5

```shell
Log colors: message notice warning error fatal

Running within sudo(root) environment!

Log saved at /home/hjf/SDK/RK3568J_SDK/output/sessions/2026-07-05_17-01-09
WARN: /home/hjf/SDK/RK3568J_SDK/output/defconfig not exists
Pick a defconfig:

1. rockchip_defconfig
2. rockchip_rk3566_evb2_lp4x_v10_32bit_defconfig
3. rockchip_rk3566_evb2_lp4x_v10_defconfig
4. rockchip_rk3568_evb1_ddr4_v10_32bit_defconfig
5. rockchip_rk3568_evb1_ddr4_v10_defconfig
6. rockchip_rk3568_evb8_lp4_v10_32bit_defconfig
7. rockchip_rk3568_evb8_lp4_v10_defconfig
8. rockchip_rk3568_pcie_ep_lp4x_v10_defconfig
Which would you like? [1]:

```





### 编译成果boot.img



![image-20260706010501934](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260706010501934.png)

不要用主机目录下的output的输出 是软连接下载巨快 是空文件



要用主机源码目录下的kernel中的boot.img

```shell
/home/server-jupyter/111/RK3568J_SDK/kernel-6.1/
```

![image-20260706010525072](https://raw.githubusercontent.com/ColorStripes/Typora_Picture/master/picture/image-20260706010525072.png)







### 温度监控

```shell
sudo watch -n 1 "echo '--- 实时监控 ---'; cat /sys/class/thermal/thermal_zone0/temp | awk '{print \"SoC 主温度: \"\$1/1000\" °C\"}'; cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq | awk '{print \"CPU 实时频率: \"\$1/1000\" MHz\"}'; cat /sys/class/devfreq/fde60000.gpu/cur_freq | awk '{print \"GPU 实时频率: \"\$1/1000000\" MHz\"}'; cat /sys/class/devfreq/fde40000.npu/cur_freq | awk '{print \"NPU 实时频率: \"\$1/1000000\" MHz\"}'; cat /sys/class/devfreq/dmc/cur_freq | awk '{print \"DDR 实时频率: \"\$1/1000000\" MHz\"}'"
```



### 设备树编译（只是帮助）

```shell
sudo ./build.sh kernel  #编译boot.img



sudo ./build.sh -h  #帮助
```







