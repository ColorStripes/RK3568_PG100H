#ifndef YOLO_FPGA
#define YOLO_FPGA

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <opencv2/opencv.hpp>
#include <WinSock2.h>
#include <WS2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#include <iostream>
#include <fstream>
#include <cstring>

class YOLO
{
public:
	YOLO();
	~YOLO();
	void init_udp();  //
	void read_weight(std::string path, int n);  //
	void read_instruction(std::string path);    //
	void read_img(std::string path, unsigned int read_addr);  
	void write_img(std::string path, size_t size, unsigned int read_addr);  //
	void fpga_layer(char layer);
	void start_calc();
	long long calculate_end();  //
	void load_img(cv::Mat& img);
	void load_img(cv::Mat& img, bool use_letterbox);
	void nms(cv::Mat& img);
	void save_yolo_layers_to_file(const char* filename);

	// 预处理配置（对应 Python preprocess_image / resize_image）
	bool letterbox_image = true;   // 默认 letterbox；false 则直接拉伸到 640x640
	int letterbox_pad = 128;       // letterbox 灰边颜色；Ultralytics 训练可改为 114
	int display_max_size = 0;      // 仅缩小过大图；0=640原尺寸显示（不放大，避免模糊）
	double label_font_scale = 0.35;
	int label_thickness = 1;

private:
	SOCKET hServer;
	struct sockaddr_in fpgaAddr;


	//nms
	char* head1;
	char* head2;
	char* head3;

	double*** nms_pipe1_0;
	double*** nms_pipe1_1;
	double*** nms_pipe1_2;

	double*** nms_pipe2_0;
	double*** nms_pipe2_1;
	double*** nms_pipe2_2;

	double** nms_pipe3;
	int* nms_pipe3_cls;
	double*** nms_pipe4;

	int input_parallelism = 16;

	int image_h = 640;
	int image_w = 640;

	int class_num = 4;
	std::string class_name[4] = { "blue", "yellow", "green", "special" };
	int channel = (class_num + 5) * 3;   // 27 effective channels (3 anchors)
	int fpga_ch = channel + 5;           // 32 FPGA output per spatial cell (27 + 5 pad)
	int anchor_stride = class_num + 5;   // 9 channels per anchor (5 bbox + 4 cls)


	double quant_scale = 0.00391965;
	int quant_zero = 0;

	double nms_scale[3] = { 0.085316672921180725, 0.084871567785739899, 0.089666269719600677 };
	double nms_zero[3] = { 138, 153, 172 };

	int anchor_w[9] = { 25, 34, 44, 40, 48, 65, 148, 219, 315 };
	int anchor_h[9] = { 14, 20, 21, 25, 29, 36, 32, 45, 57 };



	int h_0 = 20;
	int w_0 = 20;

	int h_1 = 40;
	int w_1 = 40;

	int h_2 = 80;
	int w_2 = 80;

	int nms_total = (h_0 * w_0 + h_1 * w_1 + h_2 * w_2) * 3;

	double conf_thres = 0.1;   // 与 yolov5n_q.py confidence 一致
	double iou_thres = 0.3;    // 与 yolov5n_q.py nms_iou 一致


	int stride_h_0 = image_h / h_0;
	int stride_w_0 = image_w / w_0;

	int stride_h_1 = image_h / h_1;
	int stride_w_1 = image_w / w_1;

	int stride_h_2 = image_h / h_2;
	int stride_w_2 = image_w / w_2;

	double anchor_w_0[3] = { anchor_w[6] * 1.0 / stride_w_0, anchor_w[7] * 1.0 / stride_w_0,anchor_w[8] * 1.0 / stride_w_0 };
	double anchor_h_0[3] = { anchor_h[6] * 1.0 / stride_h_0, anchor_h[7] * 1.0 / stride_h_0,anchor_h[8] * 1.0 / stride_h_0 };
	double anchor_w_1[3] = { anchor_w[3] * 1.0 / stride_w_1, anchor_w[4] * 1.0 / stride_w_1,anchor_w[5] * 1.0 / stride_w_1 };
	double anchor_h_1[3] = { anchor_h[3] * 1.0 / stride_h_1, anchor_h[4] * 1.0 / stride_h_1,anchor_h[5] * 1.0 / stride_h_1 };
	double anchor_w_2[3] = { anchor_w[0] * 1.0 / stride_w_2, anchor_w[1] * 1.0 / stride_w_2,anchor_w[2] * 1.0 / stride_w_2 };
	double anchor_h_2[3] = { anchor_h[0] * 1.0 / stride_h_2, anchor_h[1] * 1.0 / stride_h_2,anchor_h[2] * 1.0 / stride_h_2 };



};






#endif