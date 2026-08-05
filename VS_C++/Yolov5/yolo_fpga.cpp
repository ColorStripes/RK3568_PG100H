#include "yolo_fpga.h"
#include <chrono>
#include <algorithm>
#include <sstream>
#include <cmath>
#include <cstdlib>

YOLO::YOLO()
{
	nms_pipe1_0 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe1_0[i] = new double* [h_0];
		for (int j = 0; j < h_0; ++j) {
			nms_pipe1_0[i][j] = new double[w_0];
		}
	}

	nms_pipe1_1 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe1_1[i] = new double* [h_1];
		for (int j = 0; j < h_1; ++j) {
			nms_pipe1_1[i][j] = new double[w_1];
		}
	}

	nms_pipe1_2 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe1_2[i] = new double* [h_2];
		for (int j = 0; j < h_2; ++j) {
			nms_pipe1_2[i][j] = new double[w_2];
		}
	}

	nms_pipe2_0 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe2_0[i] = new double* [h_0];
		for (int j = 0; j < h_0; ++j) {
			nms_pipe2_0[i][j] = new double[w_0];
		}
	}

	nms_pipe2_1 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe2_1[i] = new double* [h_1];
		for (int j = 0; j < h_1; ++j) {
			nms_pipe2_1[i][j] = new double[w_1];
		}
	}

	nms_pipe2_2 = new double** [channel];
	for (int i = 0; i < channel; ++i) {
		nms_pipe2_2[i] = new double* [h_2];
		for (int j = 0; j < h_2; ++j) {
			nms_pipe2_2[i][j] = new double[w_2];
		}
	}

	head1 = new char[h_0 * w_0 * fpga_ch];
	head2 = new char[h_1 * w_1 * fpga_ch];
	head3 = new char[h_2 * w_2 * fpga_ch];

	nms_pipe4 = new double** [class_num];
	for (int i = 0; i < class_num; ++i) {
		nms_pipe4[i] = new double* [nms_total];
		for (int j = 0; j < nms_total; j++)
		{
			nms_pipe4[i][j] = new double[5 + 1 + 1];
		}
	}
}

YOLO::~YOLO()
{
	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_0; ++j) {
			delete[] nms_pipe1_0[i][j];
		}
		delete[] nms_pipe1_0[i];
	}
	delete[] nms_pipe1_0;

	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_1; ++j) {
			delete[] nms_pipe1_1[i][j];
		}
		delete[] nms_pipe1_1[i];
	}
	delete[] nms_pipe1_1;

	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_2; ++j) {
			delete[] nms_pipe1_2[i][j];
		}
		delete[] nms_pipe1_2[i];
	}
	delete[] nms_pipe1_2;

	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_0; ++j) {
			delete[] nms_pipe2_0[i][j];
		}
		delete[] nms_pipe2_0[i];
	}
	delete[] nms_pipe2_0;

	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_1; ++j) {
			delete[] nms_pipe2_1[i][j];
		}
		delete[] nms_pipe2_1[i];
	}
	delete[] nms_pipe2_1;

	for (int i = 0; i < channel; ++i) {
		for (int j = 0; j < h_2; ++j) {
			delete[] nms_pipe2_2[i][j];
		}
		delete[] nms_pipe2_2[i];
	}
	delete[] nms_pipe2_2;

	delete[] head1;
	delete[] head2;
	delete[] head3;

	for (int i = 0; i < class_num; ++i) {
		for (int j = 0; j < nms_total; j++)
		{
			delete[] nms_pipe4[i][j];
		}
		delete[] nms_pipe4[i];
	}
	delete[] nms_pipe4;
}

void YOLO::init_udp()
{
	WORD sockVersion = MAKEWORD(2, 2);
	//必须先填写WSADATA结构体，再调用WSAStartup初始化Windows Sockets库
	WSADATA wsadata;
	//初始化套接字库，需要加载ws2_32.lib链接库
	if (WSAStartup(sockVersion, &wsadata)) {
		printf("WSAStartup failed \n");
		return;
	}
	//创建UDP套接字
	hServer = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (hServer == INVALID_SOCKET) {
		printf("socket failed \n");
		return;
	}
	//绑定本地IP地址
	sockaddr_in addrServer;
	const char LocalIP[] = "192.168.0.3";
	addrServer.sin_family = AF_INET;
	addrServer.sin_port = htons(5677);
	inet_pton(AF_INET, LocalIP, &addrServer.sin_addr);

	//绑定本地地址和端口，失败则清理
	int nRet = bind(hServer, (sockaddr*)&addrServer, sizeof(addrServer));
	//	绑定失败则关闭socket并清理
	if (nRet == SOCKET_ERROR) {
		printf("socket bind failed server\n");
		closesocket(hServer);
		WSACleanup();
		return;
	}

	// 设置FPGA地址
	fpgaAddr.sin_family = AF_INET;
	fpgaAddr.sin_port = htons(1234);
	const char DestationIP[] = "192.168.0.1";
	inet_pton(AF_INET, DestationIP, &fpgaAddr.sin_addr);
}

void YOLO::read_weight(std::string path, int n)
{
	std::string weight_path[60];
	int weight_addr[61] = { 0x80000000 };
	for (int i = 0; i < 57; i++)
	{
		weight_path[i] = path + "conv" + std::to_string(i + 1) + "_weight.bin";
	}
	for (int i = 57; i < 60; i++)
	{
		weight_path[i] = path + "out" + std::to_string(i - 56) + "_weight.bin";
	}

	//每个权重文件分配1MB地址空间
	for (int i = 1; i < 61; i++)
	{
		weight_addr[i] = weight_addr[i - 1] + 1048576;
	}

	//打开文件
	std::ifstream file(weight_path[n], std::ios::binary);
	if (file.is_open()) {

		file.seekg(0, std::ios::end);
		size_t size = file.tellg();			     //文件大小
		file.seekg(0, std::ios::beg);		     //回到文件开头

		//读取weight数据
		char* weight_buffer = new char[size];
		file.read(weight_buffer, size);

		//高低字节调顺序
		char* weight_buffer_16 = new char[size];
		for (int i = 0; i < size; i = i + input_parallelism) {
			for (int j = 0; j < input_parallelism; j = j + 1) {
				weight_buffer_16[i + j] = weight_buffer[i + input_parallelism - 1 - j];
			}
		}

		//发送数据
		unsigned int addr = weight_addr[n];

		int clientAddrSize = sizeof(fpgaAddr);
		int send_size = 1408; //1024+256+128  (MTU 1500)
		char buffer_temp[1408 + 9];

		for (int i = 0; i < size; i += send_size)
		{
			size_t remain_size = size - i;
			size_t udp_size = remain_size < send_size ? remain_size : send_size;
			buffer_temp[0] = 2;								//写数据
			buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI写地址
			buffer_temp[2] = (addr & 0xFF0000) >> 16;
			buffer_temp[3] = (addr & 0xFF00) >> 8;
			buffer_temp[4] = (addr & 0xFF);
			buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI写长度
			buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
			buffer_temp[7] = (udp_size & 0xFF00) >> 8;
			buffer_temp[8] = (udp_size & 0xFF);
			for (int k = 0; k < udp_size; k++)
			{
				buffer_temp[k + 9] = weight_buffer_16[i + k];
			}

			sendto(hServer, buffer_temp, udp_size + 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));

			if (udp_size % 16 == 0) {
				// 必须是16的倍数
			}
			else {
				exit(-1);
			}

			addr += udp_size;
		}
		delete[] weight_buffer;
		delete[] weight_buffer_16;
		file.close();
	}
	else {
		std::cout << "error file" << std::endl;
		std::cout << weight_path[n] << std::endl;
		std::cout << weight_addr[n] << std::endl;
	}
}

void YOLO::fpga_layer(char layer)
{
	char buffer_temp[2];

	buffer_temp[0] = 8;			//发指令
	buffer_temp[1] = layer;		//1字节并行层数

	sendto(hServer, buffer_temp, 2, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
}

void YOLO::start_calc()
{
	char buffer_temp[5];

	buffer_temp[0] = 1;			//发指令
	buffer_temp[1] = 0xF0;		//四字节AXI地址
	buffer_temp[2] = 0xF0;
	buffer_temp[3] = 0xF0;
	buffer_temp[4] = 0xF0;

	sendto(hServer, buffer_temp, 5, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
}

void YOLO::read_instruction(std::string path)
{
	//读取指令文件
	std::ifstream file(path);
	if (file.is_open()) {

		char c;
		size_t hexCount = 0;

		while (file.get(c)) {
			if (std::isxdigit(static_cast<unsigned char>(c))) {
				hexCount++;
			}
		}

		size_t size = hexCount / 2; // 两个hex字符 = 1字节

		// 回到文件开头
		file.clear();
		file.seekg(0);

		char* instruction_buffer = new char[size];  //指令缓冲区

		std::string line;
		int i = 0;
		while (std::getline(file, line)) {
			// 去除空白字符
			line.erase(std::remove_if(line.begin(), line.end(), ::isspace), line.end());
			if (line.empty()) continue;

			// 每2个十六进制字符转1个字节
			for (size_t pos = 0; pos + 1 < line.size(); pos += 2) {
				std::string byte_str = line.substr(pos, 2);
				uint32_t number;
				std::istringstream(byte_str) >> std::hex >> number;
				instruction_buffer[i++] = static_cast<char>(number & 0xFF);
			}
		}

		int send_size = 1408;				//1024+256+128  (MTU 1500)
		char buffer_temp[1408 + 1];
		for (int i = 0; i < size; i += send_size)
		{
			size_t remain_size = size - i;
			size_t udp_size = remain_size < send_size ? remain_size : send_size;
			buffer_temp[0] = 1;
			for (int k = 0; k < udp_size; k++)
			{
				buffer_temp[k + 1] = instruction_buffer[i + k];
			}
			sendto(hServer, buffer_temp, udp_size + 1, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));

			if (udp_size % 4 == 0) {
				// 必须是4的倍数
			}
			else {
				exit(0);
			}

			Sleep(1);
		}
		//释放内存
		delete[] instruction_buffer;
		//关闭文件
		file.close();
	}
}
void YOLO::read_img(std::string path, unsigned int read_addr)
{
	std::cout << "insert layer:" << path << std::endl;

	std::ifstream file(path, std::ios::binary);
	if (file.is_open()) {

		file.seekg(0, std::ios::end);
		size_t size = file.tellg();
		file.seekg(0, std::ios::beg);

		char* img_buffer = new char[size];
		file.read(img_buffer, size);

		//高低字节调顺序
		unsigned char* img_buffer_16 = new unsigned char[size];
		for (int i = 0; i < size; i = i + input_parallelism) {
			for (int j = 0; j < input_parallelism; j = j + 1) {
				img_buffer_16[i + j] = img_buffer[i + input_parallelism - 1 - j];
			}
		}

		unsigned int addr = read_addr;

		int send_size = 1408; //1024+256+128  (MTU 1500)
		char buffer_temp[1408 + 9];

		for (int i = 0; i < size; i += send_size)
		{
			size_t remain_size = size - i;
			size_t udp_size = remain_size < send_size ? remain_size : send_size;
			buffer_temp[0] = 2;								//写数据
			buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI写地址
			buffer_temp[2] = (addr & 0xFF0000) >> 16;
			buffer_temp[3] = (addr & 0xFF00) >> 8;
			buffer_temp[4] = (addr & 0xFF);
			buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI写长度
			buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
			buffer_temp[7] = (udp_size & 0xFF00) >> 8;
			buffer_temp[8] = (udp_size & 0xFF);
			for (int k = 0; k < udp_size; k++)
			{
				buffer_temp[k + 9] = img_buffer_16[i + k];
			}

			sendto(hServer, buffer_temp, udp_size + 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));

			if (udp_size % 16 == 0) {
				// 必须是16的倍数
			}
			else {
				exit(0);
			}
			addr += udp_size;
		}
		//释放内存
		delete[] img_buffer;
		file.close();
	}
}

long long YOLO::calculate_end()
{
	char buffer_[8];
	int clientAddrSize = sizeof(fpgaAddr);

	// 接收数据
	int len = recvfrom(hServer, buffer_, 8, 0, (SOCKADDR*)&fpgaAddr, &clientAddrSize);

	// 2. 检查接收长度
	if (len != 8) {
		return -1; // 通信失败
	}

	// 3. 检查头部标志 (buffer_[0-3] 应为 4)
	for (int i = 0; i < 4; i++) {
		if (buffer_[i] != 4) {
			return -1; // 协议错误返回 -1
		}
	}

	// 4. 解析周期数 (buffer_[4-7])
	unsigned int time_cnt = 0;

	// 方法A：使用 memcpy (推荐，避免对齐问题)
	// 从 buffer_ 后4字节拷贝为 unsigned integer
	memcpy(&time_cnt, &buffer_[4], 4);

	// 5. 返回周期数
	return (long long)time_cnt;
}

void YOLO::write_img(std::string path, size_t size, unsigned int read_addr)
{
	char* out_buffer = new char[size];

	unsigned int addr = read_addr;
	int receive_size = 1408;
	char buffer_[1408];
	int clientAddrSize = sizeof(fpgaAddr);

	for (int i = 0; i < size; i += receive_size) {

		size_t remain_size = size - i;
		size_t udp_size = remain_size < receive_size ? remain_size : receive_size;

		char buffer_temp[9];
		buffer_temp[0] = 7;								//读数据
		buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI读地址
		buffer_temp[2] = (addr & 0xFF0000) >> 16;
		buffer_temp[3] = (addr & 0xFF00) >> 8;
		buffer_temp[4] = (addr & 0xFF);
		buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI读长度
		buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
		buffer_temp[7] = (udp_size & 0xFF00) >> 8;
		buffer_temp[8] = (udp_size & 0xFF);
		sendto(hServer, buffer_temp, 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
		int recv_len = recvfrom(hServer, buffer_, udp_size, 0, (SOCKADDR*)&fpgaAddr, &clientAddrSize);
		if (recv_len != udp_size) {
			std::cout << "recv_len=" << recv_len << " expected=" << udp_size << std::endl;
			perror("recvfrom failed write_img");
			exit(EXIT_FAILURE);         // 接收失败退出
		}

		for (int k = 0; k < udp_size; k++)
		{
			out_buffer[i + k] = buffer_[k];
		}
		addr += udp_size;
	}

	std::cout << size << std::endl;
	std::ofstream outFile(path);
	for (size_t i = 0; i < size; i++)
	{
		outFile << unsigned int(unsigned char(out_buffer[i])) << std::endl;
	}
	outFile.flush();
	outFile.close();
	//内存释放
	delete[] out_buffer;
}

// 与 Python resize_image(..., letterbox_image=True) 一致：等比缩放 + 灰边居中（PIL BICUBIC）
static void letterbox_resize(cv::Mat& img, int target_w, int target_h, int pad_val, bool enable)
{
	if (!enable) {
		cv::resize(img, img, cv::Size(target_w, target_h), 0, 0, cv::INTER_CUBIC);
		return;
	}
	const int w = img.cols;
	const int h = img.rows;
	const float scale_w = (float)target_w / w;
	const float scale_h = (float)target_h / h;
	const float scale = scale_w < scale_h ? scale_w : scale_h;
	const int nw = (int)(w * scale);
	const int nh = (int)(h * scale);
	cv::Mat resized;
	cv::resize(img, resized, cv::Size(nw, nh), 0, 0, cv::INTER_CUBIC);
	cv::Mat out(target_h, target_w, CV_8UC3, cv::Scalar(pad_val, pad_val, pad_val));
	const int left = (target_w - nw) / 2;
	const int top = (target_h - nh) / 2;
	resized.copyTo(out(cv::Rect(left, top, nw, nh)));
	img = out;
}

static void show_image_scaled(const cv::Mat& img, const char* win_name, int max_size)
{
	cv::namedWindow(win_name, cv::WINDOW_NORMAL | cv::WINDOW_KEEPRATIO);
	cv::Mat display = img;
	if (max_size > 0) {
		const int w = img.cols;
		const int h = img.rows;
		const int max_dim = w > h ? w : h;
		if (max_dim > max_size) {
			const double scale = (double)max_size / max_dim;
			cv::resize(img, display, cv::Size((int)(w * scale), (int)(h * scale)), 0, 0, cv::INTER_AREA);
		}
	}
	cv::resizeWindow(win_name, display.cols, display.rows);
	cv::imshow(win_name, display);
}

void YOLO::load_img(cv::Mat& img)
{
	load_img(img, letterbox_image);
}

void YOLO::load_img(cv::Mat& img, bool use_letterbox)
{
	// 1. BGR -> RGB（与 Python cv2.cvtColor(..., COLOR_BGR2RGB) 一致）
	cv::cvtColor(img, img, cv::COLOR_BGR2RGB);

	// 2. resize（letterbox 或直接拉伸，由 use_letterbox 控制）
	letterbox_resize(img, image_w, image_h, letterbox_pad, use_letterbox);

	// 3. 量化：与 Python round((pixel/255 - quant_zero) / quant_scale) 一致，输出 uint8
	cv::Mat f32;
	img.convertTo(f32, CV_32F, 1.0 / 255.0 / quant_scale, -static_cast<double>(quant_zero) / quant_scale);
	cv::Mat fpga_img;
	f32.convertTo(fpga_img, CV_8U);

	// nms 画框用 640x640 BGR（与网络输入同尺寸）
	cv::cvtColor(img, img, cv::COLOR_RGB2BGR);

	const size_t img_size = image_w;
	std::vector<cv::Mat> channels;
	cv::split(fpga_img, channels);

	for (int i = (int)channels.size(); i < 4; ++i) {
		channels.push_back(cv::Mat((int)img_size, (int)img_size, CV_8U, cv::Scalar(0)));
	}

	cv::Mat output;
	cv::merge(channels, output);

	if (output.type() != CV_8UC4) {
		std::cerr << "FPGA input must be CV_8UC4, got type=" << output.type() << std::endl;
		exit(EXIT_FAILURE);
	}

	unsigned char* img_buffer = output.data;
	size_t size = img_size * img_size * 4;

	std::cout << size << std::endl;

	unsigned int addr = 0x90000000;
	size_t send_size = 1408;
	char buffer_temp[1408 + 9];

	for (int i = 0; i < (int)size; i += (int)send_size)
	{
		size_t remain_size = size - i;
		size_t udp_size = remain_size < send_size ? remain_size : send_size;
		buffer_temp[0] = 2;
		buffer_temp[1] = (addr & 0xFF000000) >> 24;
		buffer_temp[2] = (addr & 0xFF0000) >> 16;
		buffer_temp[3] = (addr & 0xFF00) >> 8;
		buffer_temp[4] = (addr & 0xFF);
		buffer_temp[5] = (udp_size & 0xFF000000) >> 24;
		buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
		buffer_temp[7] = (udp_size & 0xFF00) >> 8;
		buffer_temp[8] = (udp_size & 0xFF);
		for (int k = 0; k < (int)udp_size; k++)
		{
			buffer_temp[k + 9] = img_buffer[i + k];
		}
		sendto(hServer, buffer_temp, (int)udp_size + 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
		addr += (unsigned int)udp_size;
	}
	printf("load_finish\n");
}

// 车牌类别对应框颜色（OpenCV BGR）
cv::Scalar get_color(int class_id, int total_classes) {
	(void)total_classes;
	switch (class_id) {
	case 0: return cv::Scalar(255, 0, 0);     // blue  蓝牌 -> 蓝框
	case 1: return cv::Scalar(0, 255, 255);   // yellow 黄牌 -> 黄框
	case 2: return cv::Scalar(0, 255, 0);     // green  绿牌 -> 绿框
	case 3: return cv::Scalar(255, 255, 255); // special 特殊牌 -> 白框
	default: return cv::Scalar(200, 200, 200);
	}
}

// 将C语言结果保存回python的tensorflow
void YOLO::save_yolo_layers_to_file(const char* filename) {
	// 1. 创建文件流对象，以二进制模式打开
	std::ofstream outfile(filename, std::ios::binary);

	// 2. 检查文件是否成功打开
	if (!outfile.is_open()) {
		std::cerr << "Error: Failed to open file " << filename << std::endl;
		return;
	}

	// 1. 写入 Scale 0
	for (int c = 0; c < channel; c++) {
		for (int h = 0; h < h_0; h++) {
			outfile.write(reinterpret_cast<const char*>(nms_pipe1_0[c][h]), w_0 * sizeof(double));
		}
	}

	// 2. 写入 Scale 1
	for (int c = 0; c < channel; c++) {
		for (int h = 0; h < h_1; h++) {
			outfile.write(reinterpret_cast<const char*>(nms_pipe1_1[c][h]), w_1 * sizeof(double));
		}
	}

	// 3. 写入 Scale 2
	for (int c = 0; c < channel; c++) {
		for (int h = 0; h < h_2; h++) {
			outfile.write(reinterpret_cast<const char*>(nms_pipe1_2[c][h]), w_2 * sizeof(double));
		}
	}

	std::cout << "Successfully saved to: " << filename << std::endl;
}
void YOLO::nms(cv::Mat& img)
{
	//	记录时间
	auto start = std::chrono::high_resolution_clock::now();

	int receive_size = 1408;
	char buffer_[1408];
	int clientAddrSize = sizeof(fpgaAddr);

	const int head1_bytes = h_0 * w_0 * fpga_ch;
	const int head2_bytes = h_1 * w_1 * fpga_ch;
	const int head3_bytes = h_2 * w_2 * fpga_ch;

	unsigned int addr = 0xA3000000;
	for (int i = 0; i < head1_bytes; i += receive_size) {
		char buffer_temp[9];
		size_t remain_size = head1_bytes - i;
		size_t udp_size = remain_size < receive_size ? remain_size : receive_size;
		buffer_temp[0] = 7;								//读数据
		buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI读地址
		buffer_temp[2] = (addr & 0xFF0000) >> 16;
		buffer_temp[3] = (addr & 0xFF00) >> 8;
		buffer_temp[4] = (addr & 0xFF);
		buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI读长度
		buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
		buffer_temp[7] = (udp_size & 0xFF00) >> 8;
		buffer_temp[8] = (udp_size & 0xFF);

		sendto(hServer, buffer_temp, 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
		recvfrom(hServer, buffer_, udp_size, 0, (SOCKADDR*)&fpgaAddr, &clientAddrSize);
		for (int k = 0; k < udp_size; k++)
		{
			head1[i + k] = buffer_[k];
		}
		addr += udp_size;
	}

	addr = 0xA8000000;
	for (int i = 0; i < head2_bytes; i += receive_size) {
		char buffer_temp[9];
		size_t remain_size = head2_bytes - i;
		size_t udp_size = remain_size < receive_size ? remain_size : receive_size;
		buffer_temp[0] = 7;								//读数据
		buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI读地址
		buffer_temp[2] = (addr & 0xFF0000) >> 16;
		buffer_temp[3] = (addr & 0xFF00) >> 8;
		buffer_temp[4] = (addr & 0xFF);
		buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI读长度
		buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
		buffer_temp[7] = (udp_size & 0xFF00) >> 8;
		buffer_temp[8] = (udp_size & 0xFF);

		sendto(hServer, buffer_temp, 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
		recvfrom(hServer, buffer_, udp_size, 0, (SOCKADDR*)&fpgaAddr, &clientAddrSize);
		for (int k = 0; k < udp_size; k++)
		{
			head2[i + k] = buffer_[k];
		}
		addr += udp_size;
	}

	addr = 0xAC000000;
	for (int i = 0; i < head3_bytes; i += receive_size) {
		char buffer_temp[9];
		size_t remain_size = head3_bytes - i;
		size_t udp_size = remain_size < receive_size ? remain_size : receive_size;
		buffer_temp[0] = 7;								//读数据
		buffer_temp[1] = (addr & 0xFF000000) >> 24;		//四字节AXI读地址
		buffer_temp[2] = (addr & 0xFF0000) >> 16;
		buffer_temp[3] = (addr & 0xFF00) >> 8;
		buffer_temp[4] = (addr & 0xFF);
		buffer_temp[5] = (udp_size & 0xFF000000) >> 24;			//四字节AXI读长度
		buffer_temp[6] = (udp_size & 0xFF0000) >> 16;
		buffer_temp[7] = (udp_size & 0xFF00) >> 8;
		buffer_temp[8] = (udp_size & 0xFF);

		sendto(hServer, buffer_temp, 9, 0, (SOCKADDR*)&fpgaAddr, sizeof(fpgaAddr));
		recvfrom(hServer, buffer_, udp_size, 0, (SOCKADDR*)&fpgaAddr, &clientAddrSize);
		for (int k = 0; k < udp_size; k++)
		{
			head3[i + k] = buffer_[k];
		}
		addr += udp_size;
	}

	nms_pipe3 = new double* [nms_total];
	nms_pipe3_cls = new int[nms_total];
	for (int i = 0; i < nms_total; ++i) {
		nms_pipe3[i] = new double[5 + 1];
	}

	//第一尺度反量化操作
	int z = 0;
	for (int i = 0; i < h_0; i++)
	{
		for (int j = 0; j < w_0; j++)
		{
			for (int k = 0; k < fpga_ch; k++)
			{
				if (k < channel)
				{
					nms_pipe1_0[k][i][j] = (unsigned int(unsigned char(head1[z])) - nms_zero[0]) * nms_scale[0];
				}
				z++;
			}
		}
	}

	//第二尺度反量化操作
	z = 0;
	for (int i = 0; i < h_1; i++)
	{
		for (int j = 0; j < w_1; j++)
		{
			for (int k = 0; k < fpga_ch; k++)
			{
				if (k < channel)
				{
					nms_pipe1_1[k][i][j] = (unsigned int(unsigned char(head2[z])) - nms_zero[1]) * nms_scale[1];
				}
				z++;
			}
		}
	}

	//第三尺度反量化操作
	z = 0;
	for (int i = 0; i < h_2; i++)
	{
		for (int j = 0; j < w_2; j++)
		{
			for (int k = 0; k < fpga_ch; k++)
			{
				if (k < channel)
				{
					nms_pipe1_2[k][i][j] = (unsigned int(unsigned char(head3[z])) - nms_zero[2]) * nms_scale[2];
				}
				z++;
			}
		}
	}

	auto decode_scale = [&](double*** pipe1, double*** pipe2, int h, int w, double* anchor_w, double* anchor_h) {
		for (int k = 0; k < channel; k += anchor_stride)
		{
			int anchor_idx = k / anchor_stride;
			for (int i = 0; i < h; i++)
			{
				for (int j = 0; j < w; j++)
				{
					double temp1, temp2, temp3, temp4;
					temp1 = (1.0 / (1 + exp(0 - pipe1[k][i][j])) * 2 - 0.5 + j) / w;
					temp2 = (1.0 / (1 + exp(0 - pipe1[k + 1][i][j])) * 2 - 0.5 + i) / h;
					temp3 = ((1.0 / (1 + exp(0 - pipe1[k + 2][i][j])) * 2) * (1.0 / (1 + exp(0 - pipe1[k + 2][i][j])) * 2)) * anchor_w[anchor_idx] / w;
					temp4 = ((1.0 / (1 + exp(0 - pipe1[k + 3][i][j])) * 2) * (1.0 / (1 + exp(0 - pipe1[k + 3][i][j])) * 2)) * anchor_h[anchor_idx] / h;

					pipe2[k][i][j] = temp1 - temp3 / 2;
					pipe2[k + 1][i][j] = temp2 - temp4 / 2;
					pipe2[k + 2][i][j] = temp1 + temp3 / 2;
					pipe2[k + 3][i][j] = temp2 + temp4 / 2;
					pipe2[k + 4][i][j] = (1.0 / (1 + exp(0 - pipe1[k + 4][i][j])));
					for (int c = 0; c < class_num; c++) {
						pipe2[k + 5 + c][i][j] = (1.0 / (1 + exp(0 - pipe1[k + 5 + c][i][j])));
					}
				}
			}
		}
	};

	//把网络输出解码成框和置信（生成 nms_pipe2_）
	decode_scale(nms_pipe1_0, nms_pipe2_0, h_0, w_0, anchor_w_0, anchor_h_0);
	decode_scale(nms_pipe1_1, nms_pipe2_1, h_1, w_1, anchor_w_1, anchor_h_1);
	decode_scale(nms_pipe1_2, nms_pipe2_2, h_2, w_2, anchor_w_2, anchor_h_2);

	auto argmax_scale = [&](double*** pipe2, int h, int w) {
		for (int k = 0; k < channel; k += anchor_stride)
		{
			for (int i = 0; i < h; i++)
			{
				for (int j = 0; j < w; j++)
				{
					nms_pipe3[z][5] = -1.0;
					for (int m = 0; m < class_num; m++)
					{
						if (nms_pipe3[z][5] <= pipe2[k + m + 5][i][j])
						{
							nms_pipe3[z][0] = pipe2[k + 0][i][j];
							nms_pipe3[z][1] = pipe2[k + 1][i][j];
							nms_pipe3[z][2] = pipe2[k + 2][i][j];
							nms_pipe3[z][3] = pipe2[k + 3][i][j];
							nms_pipe3[z][4] = pipe2[k + 4][i][j];
							nms_pipe3[z][5] = pipe2[k + m + 5][i][j];
							nms_pipe3_cls[z] = m;
						}
					}
					z++;
				}
			}
		}
	};

	//从每个格子取得分最高的类别（生成 nms_pipe3）
	z = 0;
	argmax_scale(nms_pipe2_0, h_0, w_0);
	argmax_scale(nms_pipe2_1, h_1, w_1);
	argmax_scale(nms_pipe2_2, h_2, w_2);

	//根据 conf_thres 筛选候选，再做全局 class-agnostic NMS（跨尺度/anchor/类别去重）
	int* keep = new int[nms_total];
	int* order = new int[nms_total];
	int det_count = 0;
	for (int i = 0; i < nms_total; i++)
	{
		keep[i] = (nms_pipe3[i][4] * nms_pipe3[i][5] >= conf_thres) ? 1 : 0;
		if (keep[i]) {
			order[det_count++] = i;
		}
	}

	auto det_score = [&](int idx) {
		return nms_pipe3[idx][4] * nms_pipe3[idx][5];
	};

	//按得分降序排序
	for (int i = 0; i < det_count - 1; i++)
	{
		for (int j = 0; j < det_count - i - 1; j++)
		{
			if (det_score(order[j]) < det_score(order[j + 1]))
			{
				int tmp = order[j];
				order[j] = order[j + 1];
				order[j + 1] = tmp;
			}
		}
	}

	//全局 NMS：同一车牌多尺度/多 anchor 重叠框只保留最高分
	for (int ii = 0; ii < det_count; ii++)
	{
		int i = order[ii];
		if (!keep[i]) {
			continue;
		}
		for (int jj = ii + 1; jj < det_count; jj++)
		{
			int k = order[jj];
			if (!keep[k]) {
				continue;
			}
			if (nms_pipe3[i][0] > nms_pipe3[k][2] || nms_pipe3[i][2] < nms_pipe3[k][0]
				|| nms_pipe3[i][1] > nms_pipe3[k][3] || nms_pipe3[i][3] < nms_pipe3[k][1])
			{
				continue;
			}
			double inter_xmin = nms_pipe3[i][0] > nms_pipe3[k][0] ? nms_pipe3[i][0] : nms_pipe3[k][0];
			double inter_ymin = nms_pipe3[i][1] > nms_pipe3[k][1] ? nms_pipe3[i][1] : nms_pipe3[k][1];
			double inter_xmax = nms_pipe3[i][2] < nms_pipe3[k][2] ? nms_pipe3[i][2] : nms_pipe3[k][2];
			double inter_ymax = nms_pipe3[i][3] < nms_pipe3[k][3] ? nms_pipe3[i][3] : nms_pipe3[k][3];
			double inter_area = (inter_xmax - inter_xmin) * (inter_ymax - inter_ymin);
			if (inter_area <= 0) {
				continue;
			}
			double area1 = (nms_pipe3[i][2] - nms_pipe3[i][0]) * (nms_pipe3[i][3] - nms_pipe3[i][1]);
			double area2 = (nms_pipe3[k][2] - nms_pipe3[k][0]) * (nms_pipe3[k][3] - nms_pipe3[k][1]);
			double iou = inter_area / (area1 + area2 - inter_area);
			if (iou > iou_thres)
			{
				keep[k] = 0;
			}
		}
	}

	for (int ii = 0; ii < det_count; ii++)
	{
		int i = order[ii];
		if (!keep[i]) {
			continue;
		}
		int cls = nms_pipe3_cls[i];
		cv::Scalar color = get_color(cls, class_num);

		int x1 = nms_pipe3[i][0] < 0 ? 0 : int(nms_pipe3[i][0] * img.cols);
		int y1 = nms_pipe3[i][1] < 0 ? 0 : int(nms_pipe3[i][1] * img.rows);
		int x2 = nms_pipe3[i][2] * img.cols >= img.cols ? img.cols - 1 : int(nms_pipe3[i][2] * img.cols);
		int y2 = nms_pipe3[i][3] * img.rows >= img.rows ? img.rows - 1 : int(nms_pipe3[i][3] * img.rows);

		cv::rectangle(img, cv::Point(x1, y1), cv::Point(x2, y2), color, label_thickness, cv::LINE_AA);

		double score = det_score(i);
		std::string label = class_name[cls] + " " + std::to_string(score).substr(0, 4);
		int label_y = y1 > 12 ? y1 - 4 : y1 + 12;
		cv::Scalar text_color = (cls == 3) ? cv::Scalar(0, 0, 0) : color;  // 白框用黑字
		cv::putText(img, label, cv::Point(x1, label_y),
			cv::FONT_HERSHEY_SIMPLEX, label_font_scale, text_color, label_thickness, cv::LINE_AA);
	}

	delete[] keep;
	delete[] order;

	//计时输出与显示窗口
	auto stop = std::chrono::high_resolution_clock::now();
	auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start).count();
	std::cout << "2 Elapsed time: " << duration / 1000.0 << " ms\n";

	show_image_scaled(img, "img", display_max_size);
	cv::waitKey();
	cv::destroyAllWindows();

	for (int i = 0; i < nms_total; ++i) {
		delete[] nms_pipe3[i];
	}
	delete[] nms_pipe3;
	delete[] nms_pipe3_cls;
}