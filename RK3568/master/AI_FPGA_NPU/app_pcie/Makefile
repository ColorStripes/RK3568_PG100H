# =====================================================================
# AI_FPGA_NPU/app_pcie — 构建脚本
#   make     -> ../libdma_rga.so   (单一动态库: 相机/HDMI/FPGA_NPU 合并,
#                                   Python ctypes 统一调用入口)
#   make app -> build/app          (遗留 GTK 演示, 当前无 main 源文件)
# =====================================================================

CXX = g++

build_dir = build
src_dir   = sources
inc_dir   = includes

includes = $(foreach dir,$(inc_dir),$(wildcard $(dir)/*.h))

CXXFLAGS = -O3 $(patsubst %, -I%, $(inc_dir))

# 第三方库
GTK = `pkg-config --cflags --libs gtk+-2.0 gmodule-export-2.0`
DRM = `pkg-config --cflags --libs libdrm`
RGA = -lrga
CV_CFLAGS = `pkg-config --cflags opencv4`
CV_LIBS   = `pkg-config --libs opencv4`
GST_CFLAGS = `pkg-config --cflags gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-allocators-1.0`
GST_LIBS   = `pkg-config --libs gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-allocators-1.0`

.PHONY: clean check create_build lib app

# =====================================================================
# 1) 单一动态库 (默认目标): 相机/HDMI/FPGA_NPU 合并于 ../libdma_rga.so
#    导出 extern "C" 接口, 供 Python ctypes 调用:
#      相机/HDMI: init_hardware_pipeline_ex / set_pipeline_resolution /
#                 fetch_next_frame /
#                 sync_to_screen / cleanup_hardware
#      NPU:      npu_init / npu_release / npu_upload_weights /
#                npu_upload_instructions / npu_upload_image_file /
#                npu_upload_image_rgba / npu_infer
# =====================================================================
lib_sources = $(src_dir)/pci_dma_bridge.cpp $(src_dir)/dma_bridge_rga.cpp $(src_dir)/fpga_npu_bridge.cpp $(src_dir)/gst_decoder.cpp
lib_objects = $(patsubst $(src_dir)/%.cpp,$(build_dir)/%.o,$(lib_sources))

lib: $(lib_objects) | create_build
	$(CXX) -shared $^ -o ../libdma_rga.so $(CV_LIBS) $(GST_LIBS) -lpthread $(RGA) -ldrm
	@echo "单一动态库构建完成: ../libdma_rga.so"

# 每个源文件单独编译 (-c -fPIC), 支持增量构建, 供 bear 生成 compile_commands.json
$(build_dir)/%.o: $(src_dir)/%.cpp $(includes) | create_build
	$(CXX) -c -O3 -fPIC -I$(inc_dir) -I/usr/include/libdrm -I/usr/include/drm $(CV_CFLAGS) $(GST_CFLAGS) $< -o $@

# =====================================================================
# 2) 遗留 GTK 演示程序 (原始 Pango PCIe 测试 GUI)
# =====================================================================
app_sources = $(wildcard $(src_dir)/*.cpp)
app_objects = $(patsubst %.cpp,$(build_dir)/%.o,$(notdir $(app_sources)))

app: $(app_objects) | create_build
	$(CXX) $^ -o $(build_dir)/app $(GTK) $(DRM) $(RGA)

clean:
	rm -rf $(build_dir)

check:
	@echo $(CXXFLAGS)
	@echo $(CURDIR)
	@echo $(src_dir)

create_build:
	@mkdir -p $(build_dir)