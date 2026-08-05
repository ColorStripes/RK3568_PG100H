# 生成可执行文件的名称
Target = app

# 编译器改为g++
CXX = g++

# 存放中间文件的路径
build_dir = build

# 存放源文件的文件夹
src_dir = sources

# 存放头文件的文件夹
inc_dir = includes

# 源文件（*.cpp）
sources = $(foreach dir,$(src_dir),$(wildcard $(dir)/*.cpp))

# 目标文件（*.o）
objects = $(patsubst %.cpp,$(build_dir)/%.o,$(notdir $(sources)))

# 头文件
includes = $(foreach dir,$(inc_dir),$(wildcard $(dir)/*.h))

# 编译参数：指定头文件的路径
CXXFLAGS = -O3 $(patsubst %, -I%, $(inc_dir))

# 依赖的第三方库
GTK = `pkg-config --cflags --libs gtk+-2.0 gmodule-export-2.0`
# --- 移除 OpenCV，新增 DRM 硬件显示库链接 ---
DRM = `pkg-config --cflags --libs libdrm`
# --- RGA 硬件加速库链接 ---
RGA = -lrga

# 链接过程
$(build_dir)/$(Target) : $(objects) | create_build
	$(CXX) $^ -o $@ $(GTK) $(DRM) $(RGA)

# 编译工程
$(build_dir)/%.o : $(src_dir)/%.cpp $(includes) | create_build
	$(CXX) -c $(CXXFLAGS) $< -o $@ $(GTK) $(DRM) $(RGA)

# 以下为伪目标，调用方式：make 伪目标
.PHONY: clean check create_build cp

# 按架构删除
clean:
	rm -rf $(build_dir)

# 检查某个变量的值（用于调试）
check:
	@echo $(CXXFLAGS)
	@echo $(CURDIR)
	@echo $(src_dir)
	@echo $(sources)
	@echo $(objects)
	 
# 创建存放过程文件的目录
create_build:
	@mkdir -p $(build_dir)

# 将生成的可执行文件拷贝到当前目录
cp: 
	cp ./build/$(Target) ./