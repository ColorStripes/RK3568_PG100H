"""npu_bridge.py — FPGA NPU 推理 Python 绑定 (ctypes)

与 app_pcie/sources/fpga_npu_bridge.cpp 导出的 extern "C" 接口一一对应:
    npu_init / npu_release
    npu_configure_layers / npu_upload_weights / npu_upload_instructions   (初始化三件套)
    npu_upload_image_file / npu_upload_image_rgba                         (上传图像, debug 用 verify)
    npu_infer_start / npu_infer_read                                       (启动推理 / 读回输出)

两种用法:
  1) car_qt.py 已加载 libdma_rga.so (相机+HDMI+NPU 合并库) 时,
     直接复用同一 CDLL 句柄, 共享驱动 fd 与 DMA 映射:
         hw_lib = ctypes.CDLL(path)
         npu = FpgaNpu(hw_lib)
  2) 独立使用, 加载同一合并库 (默认路径):
         npu = FpgaNpu()
"""

import ctypes
import os

# ---- 与 app_pcie/includes/npu_config.h 保持一致 ----
NPU_INPUT_W = 640
NPU_INPUT_H = 640
NPU_INPUT_C = 4
NPU_IMAGE_SIZE = NPU_INPUT_W * NPU_INPUT_H * NPU_INPUT_C      # 1638400

NPU_FPGA_CH = 32
NPU_HEAD1_SIZE = 20 * 20 * NPU_FPGA_CH                         # 12800
NPU_HEAD2_SIZE = 40 * 40 * NPU_FPGA_CH                         # 51200
NPU_HEAD3_SIZE = 80 * 80 * NPU_FPGA_CH                         # 204800
NPU_TOTAL_OUTPUT_SIZE = NPU_HEAD1_SIZE + NPU_HEAD2_SIZE + NPU_HEAD3_SIZE  # 268800

# 单一动态库: 相机/HDMI/FPGA_NPU 合并于 libdma_rga.so
DEFAULT_LIB_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'libdma_rga.so')


class FpgaNpu:
    """封装 fpga_npu_bridge.cpp 的 extern "C" 接口

    lib 参数可以是:
      - ctypes.CDLL 句柄 (复用已加载的合并库, 推荐)
      - .so 路径字符串 (本模块自行加载)
      - None (加载 DEFAULT_LIB_PATH)
    """

    def __init__(self, lib=None):
        if isinstance(lib, str):
            lib = ctypes.CDLL(lib)
        if lib is None:
            lib = ctypes.CDLL(DEFAULT_LIB_PATH)
        self._lib = lib
        self._bind()

    def _bind(self):
        lib = self._lib
        lib.npu_init.restype = ctypes.c_int
        lib.npu_release.restype = None
        lib.npu_configure_layers.restype = ctypes.c_int
        lib.npu_upload_weights.argtypes = [ctypes.c_char_p, ctypes.c_int]
        lib.npu_upload_weights.restype = ctypes.c_int
        lib.npu_upload_instructions.argtypes = [ctypes.c_char_p]
        lib.npu_upload_instructions.restype = ctypes.c_int
        lib.npu_upload_image_file.argtypes = [ctypes.c_char_p, ctypes.c_int]
        lib.npu_upload_image_file.restype = ctypes.c_int
        lib.npu_upload_image_rgba.argtypes = [ctypes.POINTER(ctypes.c_uint8), ctypes.c_int]
        lib.npu_upload_image_rgba.restype = ctypes.c_int
        lib.npu_infer_start.restype = ctypes.c_int
        lib.npu_infer_read.argtypes = [ctypes.POINTER(ctypes.c_uint8), ctypes.c_int]
        lib.npu_infer_read.restype = ctypes.c_int

    # ---- 生命周期 ----
    def init(self):
        """打开驱动并建立 TX/RX 映射。0 成功, -1 失败。"""
        return self._lib.npu_init()

    def release(self):
        """释放本模块持有的驱动资源。"""
        self._lib.npu_release()

    # ---- 初始化三件套: 配置层数 / 权重 / 指令 ----
    def configure_layers(self):
        """配置 NPU 总层数到 FPGA 层数寄存器。0 成功, -1 失败。"""
        return self._lib.npu_configure_layers()

    def upload_weights(self, weight_dir, verify=False):
        """上传 60 个权重文件。verify=True 时每次上传后 DMA 读回逐字节校验 (debug 用)。

        0 全部成功, -1 存在失败。
        """
        return self._lib.npu_upload_weights(weight_dir.encode(), 1 if verify else 0)

    def upload_instructions(self, instr_file):
        """上传指令流文件。返回指令字节数, -1 失败。"""
        return self._lib.npu_upload_instructions(instr_file.encode())

    # ---- 图像上传 ----
    def upload_image_file(self, image_path, verify=False):
        """上传图像文件到 FPGA 输入区 (debug 用)。

        jpg/png 走 RGA 解码+letterbox+RGBA8888; 640x640x4 raw bin 原样上传。
        verify=True 时上传后 DMA 读回逐字节校验。0 成功, -1 失败。
        """
        return self._lib.npu_upload_image_file(image_path.encode(), 1 if verify else 0)

    def upload_image_rgba(self, rgba_bytes, verify=False):
        """上传 Python 侧预处理好的 640x640x4 RGBA 缓冲。

        verify=True 时上传后 DMA 读回逐字节校验 (debug 用)。0 成功, -1 失败。
        """
        if len(rgba_bytes) < NPU_IMAGE_SIZE:
            raise ValueError(
                f'rgba buffer too small: {len(rgba_bytes)} < {NPU_IMAGE_SIZE}')
        buf = (ctypes.c_uint8 * len(rgba_bytes)).from_buffer_copy(rgba_bytes)
        return self._lib.npu_upload_image_rgba(buf, 1 if verify else 0)

    # ---- 推理 ----
    def infer_start(self):
        """发送启动信号并阻塞等待推理完成中断。0 成功, -1 失败 (超时 6s)。"""
        return self._lib.npu_infer_start()

    def infer_read(self):
        """DMA 读回三头连续 int8 输出。

        返回 bytes (长度 NPU_TOTAL_OUTPUT_SIZE), 失败返回 None。
        布局: Head1(20x20) | Head2(40x40) | Head3(80x80)。
        """
        out = (ctypes.c_uint8 * NPU_TOTAL_OUTPUT_SIZE)()
        ret = self._lib.npu_infer_read(out, NPU_TOTAL_OUTPUT_SIZE)
        if ret < 0:
            return None
        return bytes(out)

    def infer(self):
        """便捷封装: infer_start() + infer_read()。成功返回 bytes, 失败返回 None。"""
        if self.infer_start() < 0:
            return None
        return self.infer_read()

    def infer_heads(self):
        """同 infer(), 但拆分为 (head1, head2, head3) 三个 bytes 元组。"""
        raw = self.infer()
        if raw is None:
            return None
        o1 = NPU_HEAD1_SIZE
        o2 = NPU_HEAD1_SIZE + NPU_HEAD2_SIZE
        return raw[:o1], raw[o1:o2], raw[o2:]


if __name__ == '__main__':
    # 冒烟测试: 加载库并打印导出符号是否可用 (不触碰硬件)
    npu = FpgaNpu()
    print('[npu_bridge] lib loaded:', npu._lib._name)
    print('[npu_bridge] npu_init ->', npu._lib.npu_init.restype)
    print('[npu_bridge] output layout: head1=%d head2=%d head3=%d total=%d'
          % (NPU_HEAD1_SIZE, NPU_HEAD2_SIZE, NPU_HEAD3_SIZE, NPU_TOTAL_OUTPUT_SIZE))