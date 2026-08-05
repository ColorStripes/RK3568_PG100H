#include "yolo_fpga.h"

using namespace cv;

int main() {


	YOLO yolo;
	cv::Mat img;
	yolo.init_udp();

	yolo.fpga_layer(53);	////////////////////////////////// 不同并行层数要变 //////////////////////////////////// 

	std::string img_path = "./img/11.jpg";
	std::string instruction_path;
	//std::cout << "input image path:";
	//std::cin >> img_path;

	double fpga_freq_mhz = 300.0;

	//weight
	for (int n = 1; n <= 60; n = n + 1) {
		std::string weight_path = "F:/VSstudio/Yolov5/Yolov5/weight_bin/";
		if ((n > 0) && (n <= 60)) {
			yolo.read_weight(weight_path, n - 1);
		}
	}


	// 与训练 / yolov5n_q.py / export_npy.py 保持一致
	yolo.letterbox_image = true;
	yolo.display_max_size = 0;  // 显示长边像素，0=不缩放


#define USE_DEBUG 2  // Ϊ0򲻱






#if USE_DEBUG == 1

	int count = 0;


	int index[88] = {
		0, 1, 2, 3, 4, 5, 6, 61, 68, 7, 8, 9, 10, 11, 12, 62, 13, 14, 63, 69, 15, 16, 17, 18, 19,
		20, 64, 21, 22, 65, 23, 24, 66, 70, 25, 26, 27, 28, 29, 30, 67, 71, 31, 32, 85, 86, 87, 72,
		73, 74, 33, 34, 83, 75, 35, 36, 37, 38, 76, 39, 40, 84, 77, 41, 42, 43, 44, 78, 45, 60, 46, 79,
		47, 48, 49, 50, 80, 51, 59, 52, 81, 53, 54, 55, 56, 82, 57, 58
	};


	int insert[88] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1
	};






	img = cv::imread(img_path);
	yolo.load_img(img);

	instruction_path = "F:/VSstudio/Yolov5/Yolov5/instruction_all.txt";
	yolo.read_instruction(instruction_path);

	for (int i = 0; i <= 87; i = i + 1) {
		int n = index[i];
		int m = -1;

		for (int j = 0; j <= 87; j = j + 1) {
			if (insert[j] == n) {
				m = n;
			}
		}

		std::cout << "M:" << m << ",  N:" << n << std::endl;





		//read_img
		std::string indata_path_0;
		std::string indata_path_1;
		if (n == 0) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata/focus_data.bin";
			if (m == 0) {
				yolo.read_img(indata_path_0, 0x90000000);
			}
		}
		else if ((n > 0) && (n < 58)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/conv" + std::to_string(n) + "_data.bin";
			if ((m == 1) || (m == 3) || (m == 4) || (m == 6) || (m == 8) || (m == 11) || (m == 14) || (m == 17) || (m == 18) || (m == 20)
				|| (m == 21) || (m == 24) || (m == 27) || (m == 28) || (m == 30) || (m == 32) || (m == 34) || (m == 35) || (m == 36) || (m == 38)
				|| (m == 39) || (m == 55)) {
				yolo.read_img(indata_path_0, 0xB0000000);
			}
			else if ((m == 2) || (m == 5) || (m == 7) || (m == 9) || (m == 10) || (m == 12) || (m == 13) || (m == 15) || (m == 19) || (m == 22)
				|| (m == 23) || (m == 25) || (m == 29) || (m == 31)) {
				yolo.read_img(indata_path_0, 0xC0000000);
			}
			else if ((m == 33) || (m == 37) || (m == 40) || (m == 43) || (m == 49) || (m == 56)) {
				yolo.read_img(indata_path_0, 0xD0000000);
			}
			else if ((m == 41) || (m == 42) || (m == 44) || (m == 45) || (m == 47) || (m == 48) || (m == 50) || (m == 51) || (m == 53)
				|| (m == 54) || (m == 57)) {
				yolo.read_img(indata_path_0, 0xE0000000);
			}
			else if (m == 16) {
				yolo.read_img(indata_path_0, 0xA0000000);
			}
			else if (m == 26) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
			else if (m == 46) {
				yolo.read_img(indata_path_0, 0xAA000000);
			}
			else if (m == 52) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
		}
		else if (n == 58) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 58) {
				yolo.read_img(indata_path_0, 0xA0000000);
			}
		}
		else if (n == 59) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 59) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
		}
		else if (n == 60) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 60) {
				yolo.read_img(indata_path_0, 0xAA000000);
			}
		}
		else if ((n >= 61) && (n <= 67)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/add" + std::to_string(n - 61) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/add" + std::to_string(n - 61) + "_data_" + std::to_string(1) + ".bin";
			if (m == 61) {
				yolo.read_img(indata_path_0, 0xC0000000);
				yolo.read_img(indata_path_1, 0xE0000000);
			}
			else if (m == 62) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 63) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 64) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 65) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 66) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 67) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 68) && (n <= 71)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 68) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 68) + "_data_" + std::to_string(1) + ".bin";
			if (m == 68) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 69) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 70) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 71) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
		}
		else if ((n >= 72) && (n <= 74)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat4_" + std::to_string(n - 71) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat4_" + std::to_string(n - 71) + "_data_" + std::to_string(1) + ".bin";
			if (m == 72) {
				yolo.read_img(indata_path_0, 0xC0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 73) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xF0000000);
			}
			else if (m == 74) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 75) && (n <= 82)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 70) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 70) + "_data_" + std::to_string(1) + ".bin";
			if (m == 75) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xA5000000);
			}
			else if (m == 76) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xE0000000);
			}
			else if (m == 77) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xA0000000);
			}
			else if (m == 78) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xF0000000);
			}
			else if (m == 79) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 80) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 81) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 82) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 83) && (n <= 84)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/up" + std::to_string(n - 83) + "_data.bin";
			if (m == 83) {
				yolo.read_img(indata_path_0, 0xC0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 84) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
		}
		else if ((n >= 85) && (n <= 87)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/max" + std::to_string(n - 84) + "_data.bin";
			if (m == 85) {
				yolo.read_img(indata_path_0, 0xC0000000);
			}
			else if (m == 86) {
				yolo.read_img(indata_path_0, 0xD0000000);
			}
			else if (m == 87) {
				yolo.read_img(indata_path_0, 0xE0000000);
			}
		}




		//size
		size_t hout = 0;
		size_t cout = 0;
		if ((n == 2) || (n == 7) || (n == 68)) {
			hout = 160;
			cout = 32;
		}
		else if ((n == 3) || (n == 4) || (n == 5) || (n == 6) || (n == 61)) {
			hout = 160;
			cout = 16;
		}
		else if (n == 8) {
			hout = 80;
			cout = 64;
		}
		else if ((n == 9) || (n == 10) || (n == 11) || (n == 12) || (n == 13) || (n == 14) || (n == 41) || (n == 42) || (n == 43) || (n == 44) || (n == 62) || (n == 63)) {
			hout = 80;
			cout = 32;
		}
		else if ((n == 15) || (n == 45) || (n == 69) || (n == 78) || (n == 84)) {
			hout = 80;
			cout = 64;
		}
		else if ((n == 16) || (n == 25) || (n == 39) || (n == 51) || (n == 70) || (n == 83)) {
			hout = 40;
			cout = 128;
		}
		else if ((n == 17) || (n == 18) || (n == 19) || (n == 20) || (n == 21) || (n == 22) || (n == 23) || (n == 24) || (n == 35)
			|| (n == 36) || (n == 37) || (n == 38) || (n == 40) || (n == 46) || (n == 47) || (n == 48) || (n == 49) || (n == 50)
			|| (n == 64) || (n == 65) || (n == 66)) {
			hout = 40;
			cout = 64;
		}
		else if ((n == 26) || (n == 31) || (n == 33) || (n == 57) || (n == 71) || (n == 72) || (n == 73) || (n == 81) || (n == 82)) {
			hout = 20;
			cout = 256;
		}
		else if ((n == 27) || (n == 28) || (n == 29) || (n == 30) || (n == 32) || (n == 34) || (n == 52) || (n == 53) || (n == 54)
			|| (n == 55) || (n == 56) || (n == 67) || (n == 85) || (n == 86) || (n == 87)) {
			hout = 20;
			cout = 128;
		}
		else if (n == 58) {
			hout = 20;
			cout = 32;
		}
		else if (n == 59) {
			hout = 40;
			cout = 32;
		}
		else if (n == 60) {
			hout = 80;
			cout = 32;
		}
		else if (n == 74) {
			hout = 20;
			cout = 512;
		}
		else if (n == 75) {
			hout = 40;
			cout = 256;
		}
		else if ((n == 76) || (n == 79) || (n == 80)) {
			hout = 40;
			cout = 128;
		}
		else if (n == 77) {
			hout = 80;
			cout = 128;
		}
		else if ((n == 0) || (n == 1)) {
			hout = 320;
			cout = 16;
		}
		size_t wout = hout;
		size_t size = hout * wout * cout;


		//outdata
		std::string outdata_path;
		if (n == 0) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/focus_result.txt";
		}
		else if ((n > 0) && (n < 58)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/conv" + std::to_string(n) + "_result.txt";
		}
		else if ((n >= 58) && (n <= 60)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/out" + std::to_string(n - 57) + "_result.txt";
		}
		else if ((n >= 61) && (n <= 67)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/add" + std::to_string(n - 61) + "_result.txt";
		}
		else if ((n >= 68) && (n <= 71)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat" + std::to_string(n - 68) + "_result.txt";
		}
		else if ((n >= 72) && (n <= 74)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat4_" + std::to_string(n - 71) + "_result.txt";
		}
		else if ((n >= 75) && (n <= 82)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat" + std::to_string(n - 70) + "_result.txt";
		}
		else if ((n >= 83) && (n <= 84)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/up" + std::to_string(n - 83) + "_result.txt";
		}
		else if ((n >= 85) && (n <= 87)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/max" + std::to_string(n - 84) + "_result.txt";
		}


		//addr
		unsigned int read_addr = 0xB0000000;
		if ((n == 0) || (n == 2) || (n == 5) || (n == 7) || (n == 9) || (n == 13) || (n == 16) || (n == 19) || (n == 23)
			|| (n == 26) || (n == 29) || (n == 31) || (n == 33) || (n == 37) || (n == 40) || (n == 48) || (n == 52) || (n == 53)
			|| (n == 61) || (n == 63) || (n == 64) || (n == 66) || (n == 67) || (n == 72) || (n == 75)
			|| (n == 76)) {
			read_addr = 0xB0000000;
		}
		else if ((n == 1) || (n == 3) || (n == 8) || (n == 11) || (n == 17) || (n == 21) || (n == 27) || (n == 32)
			|| (n == 34) || (n == 54) || (n == 62) || (n == 65) || (n == 68) || (n == 69) || (n == 70)
			|| (n == 71) || (n == 73)) {
			read_addr = 0xC0000000;
		}
		else if ((n == 4) || (n == 10) || (n == 18) || (n == 28) || (n == 35) || (n == 38) || (n == 39)
			|| (n == 41) || (n == 44) || (n == 47) || (n == 55) || (n == 74) || (n == 83)
			|| (n == 84) || (n == 85)) {
			read_addr = 0xD0000000;
		}
		else if ((n == 6) || (n == 12) || (n == 14) || (n == 20) || (n == 22) || (n == 24) || (n == 30)
			|| (n == 36) || (n == 43) || (n == 49) || (n == 77) || (n == 78) || (n == 79) || (n == 80)
			|| (n == 81) || (n == 82) || (n == 86)) {
			read_addr = 0xE0000000;
		}
		else if ((n == 42) || (n == 46) || (n == 50) || (n == 56) || (n == 87)) {
			read_addr = 0xF0000000;
		}
		else if ((n == 15) || (n == 57)) {
			read_addr = 0xA0000000;
		}
		else if ((n == 25) || (n == 51)) {
			read_addr = 0xA5000000;
		}
		else if ((n == 45)) {
			read_addr = 0xAA000000;
		}
		else if (n == 58) {
			read_addr = 0xA3000000;
		}
		else if (n == 59) {
			read_addr = 0xA8000000;
		}
		else if (n == 60) {
			read_addr = 0xAC000000;
		}



		std::cout << ": " << n << std::endl;
		yolo.start_calc();
		std::cout << "㿪ʼ " << std::endl;



		auto start = std::chrono::high_resolution_clock::now();
		long long fpga_cycles = yolo.calculate_end();
		if (fpga_cycles == -1) {
			std::cout << "Error: FPGA communication failed or protocol mismatch." << std::endl;
		}
		else {
			// 成功获取！
			// 假设 FPGA 频率是 300MHz (根据实际情况修改)

			double time_ms = fpga_cycles / (fpga_freq_mhz * 1000.0); // ĵλʾ
			std::cout << "FPGA Cycles: " << fpga_cycles << std::endl;
			std::cout << "FPGA Time: " << time_ms << " ms (assuming 300MHz)" << std::endl;
		}
		auto stop = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start).count();
		std::cout << "1 Elapsed time: " << duration / 1000.0 << " ms\n";



		yolo.write_img(outdata_path, size, read_addr);


		std::cout << "дɣس˳...:" << n << std::endl;

		std::cout << "ϵ" << count << std::endl;
		count = count + 1;


	}

	//释放常量区的指针
	yolo.start_calc();

	std::cout << "接受到结果 进行nms...:" << std::endl;
	yolo.nms(img);


#elif USE_DEBUG == 0

	img = cv::imread(img_path);
	yolo.load_img(img);

	//yolo.read_img("F:/VSstudio/Yolov5/Yolov5/indat/focus_data.bin", 0x90000000);

	instruction_path = "F:/VSstudio/Yolov5/Yolov5/instruction_all.txt";
	yolo.read_instruction(instruction_path);

	yolo.start_calc();

	std::cout << "等待接受结果..." << std::endl;
	auto start = std::chrono::high_resolution_clock::now();

	if (yolo.calculate_end()) {
		std::cout << "end_error" << std::endl;
	}

	auto stop = std::chrono::high_resolution_clock::now();
	auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start).count();
	std::cout << "1 Elapsed time: " << duration / 1000.0 << " ms\n";

	std::cout << "接受到结果 进行nms...:" << std::endl;
	yolo.nms(img);



#elif USE_DEBUG == 2

	instruction_path = "F:/VSstudio/Yolov5/Yolov5/instruction_all.txt";
	yolo.read_instruction(instruction_path);
	for (int i = 1; i <= 17; i++) {
		char filename[64];
		sprintf_s(filename, "./img/%06d.jpg", i);
		img_path = filename;
		
		// 使用 img_path
		std::cout << img_path << std::endl;


		img = cv::imread(img_path);
		yolo.load_img(img);


		yolo.start_calc();

		std::cout << "等待接受结果..." << std::endl;
		auto start = std::chrono::high_resolution_clock::now();

		//if (yolo.calculate_end()) {
		//	std::cout << "end_error" << std::endl;
		//}

		long long fpga_cycles = yolo.calculate_end();
		
		if (fpga_cycles == -1) {
			std::cout << "Error: FPGA communication failed or protocol mismatch." << std::endl;
		}
		else {
			// 成功获取！
			// 假设 FPGA 频率是 300MHz (根据实际情况修改)
			
			double time_ms = fpga_cycles / (fpga_freq_mhz * 1000.0); // 这里的单位换算演示
			std::cout << "FPGA Cycles: " << fpga_cycles << std::endl;
			std::cout << "FPGA Time: " << time_ms << " ms (assuming 300MHz)" << std::endl;
		}


		auto stop = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start).count();
		std::cout << "1 Elapsed time: " << duration / 1000.0 << " ms\n";

		std::cout << "接受到结果 进行nms...:" << std::endl;
		yolo.nms(img);

		std::cout << "nms...end:" << i << std::endl;

		//yolo.save_yolo_layers_to_file("F:\\python\\yolov5\\output.bin");
	}


	// ˫debug
#elif USE_DEBUG == 3


	int count = 0;


	int index[88] = {
		0, 1, 2, 3, 5, 6, 61, 4, 68, 7, 8, 9, 11, 12, 62, 13, 14, 63, 10, 69, 15, 16, 17, 19,
		20, 64, 21, 22, 65, 23, 24, 66, 18, 70, 25, 26, 27, 29, 30, 67, 28, 71, 31, 32, 85, 72, 86, 87, 
		73, 74, 33, 34, 83, 75, 35, 37, 38, 36, 76, 39, 40, 84, 77, 41, 43, 44, 42, 78, 45, 60, 46, 79,
		47, 49, 50, 48, 80, 51, 59, 52, 81, 53, 55, 56, 54, 82, 57, 58
	};


	int insert[88] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1 ,-1, -1,
					   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 ,-1 ,-1
	};


	//int para_index[27] = {
	//	1,    5,    4,    7,   11,  13,  10,  19, 
	//	21,  23,  18,  29,  28,  31,  33, 
	//	37,  36,  39,  43,  42,  46, 
	//	49,  48,  52,  55,  54,  57 
	//};
	
	
	int para_index[36] = {
		1,    5,6,    4,    7,   11,12,  13,14,  10,  19,20,
		21,22,  23,24,  18,  29,30,  28,  31, 87,  33, 83,
		37,  36,  39,  43,  42,  46,
		49,  48,  52,  55,  54,  57
	};


	
	
	img = cv::imread(img_path);
	yolo.load_img(img);
	
	instruction_path = "F:/VSstudio/Yolov5/Yolov5/instruction_all.txt";
	yolo.read_instruction(instruction_path);
	
	for (int i = 0; i <= 87; i = i + 1) {
		int n = index[i];
		
		bool found = false; // Ƿ para_index ҵ n

		for (int k = 0; k <= 36; k = k + 1) {
			if (para_index[k] == n) {
				found = true;
				break; // ȻҵˣûҪ k ѭ
			}
		}

		if (found) {
			continue;
		}

		int m = -1;
		for (int j = 0; j <= 87; j = j + 1) {
			if (insert[j] == n) {
				m = n;
				break;
			}
		}
	
		std::cout << "M:" << m << ",  N:" << n << std::endl;
	
	
		
	
	
		//read_img
		std::string indata_path_0;
		std::string indata_path_1;
		if (n == 0) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata/focus_data.bin";
			if (m == 0) {
				yolo.read_img(indata_path_0, 0x90000000);
			}
		}
		else if ((n > 0) && (n < 58)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/conv" + std::to_string(n) + "_data.bin";
			if ((m == 1) || (m == 3) || (m == 4) || (m == 6) || (m == 8) || (m == 11) || (m == 14) || (m == 17) || (m == 18) || (m == 20)
				|| (m == 21) || (m == 24) || (m == 27) || (m == 28) || (m == 30) || (m == 32) || (m == 34) || (m == 35) || (m == 36) || (m == 38)
				|| (m == 39) || (m == 55)) {
				yolo.read_img(indata_path_0, 0xB0000000);
			}
			else if ((m == 2) || (m == 5) || (m == 7) || (m == 9) || (m == 10) || (m == 12) || (m == 13) || (m == 15) || (m == 19) || (m == 22)
				|| (m == 23) || (m == 25) || (m == 29) || (m == 31)) {
				yolo.read_img(indata_path_0, 0xC0000000);
			}
			else if ((m == 33) || (m == 37) || (m == 40) || (m == 43) || (m == 49) || (m == 56)) {
				yolo.read_img(indata_path_0, 0xD0000000);
			}
			else if ((m == 41) || (m == 42) || (m == 44) || (m == 45) || (m == 47) || (m == 48) || (m == 50) || (m == 51) || (m == 53)
				|| (m == 54) || (m == 57)) {
				yolo.read_img(indata_path_0, 0xE0000000);
			}
			else if (m == 16) {
				yolo.read_img(indata_path_0, 0xA0000000);
			}
			else if (m == 26) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
			else if (m == 46) {
				yolo.read_img(indata_path_0, 0xAA000000);
			}
			else if (m == 52) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
		}
		else if (n == 58) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 58) {
				yolo.read_img(indata_path_0, 0xA0000000);
			}
		}
		else if (n == 59) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 59) {
				yolo.read_img(indata_path_0, 0xA5000000);
			}
		}
		else if (n == 60) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/out" + std::to_string(n - 57) + "_data.bin";
			if (m == 60) {
				yolo.read_img(indata_path_0, 0xAA000000);
			}
		}
		else if ((n >= 61) && (n <= 67)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/add" + std::to_string(n - 61) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/add" + std::to_string(n - 61) + "_data_" + std::to_string(1) + ".bin";
			if (m == 61) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 62) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 63) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 64) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 65) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 66) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 67) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 68) && (n <= 71)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 68) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 68) + "_data_" + std::to_string(1) + ".bin";
			if (m == 68) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 69) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 70) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 71) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
		}
		else if ((n >= 72) && (n <= 74)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat4_" + std::to_string(n - 71) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat4_" + std::to_string(n - 71) + "_data_" + std::to_string(1) + ".bin";
			if (m == 72) {
				yolo.read_img(indata_path_0, 0xC0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 73) {
				yolo.read_img(indata_path_0, 0xE0000000);
				yolo.read_img(indata_path_1, 0xF0000000);
			}
			else if (m == 74) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 75) && (n <= 82)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 70) + "_data_" + std::to_string(0) + ".bin";
			indata_path_1 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/cat" + std::to_string(n - 70) + "_data_" + std::to_string(1) + ".bin";
			if (m == 75) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xA5000000);
			}
			else if (m == 76) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xE0000000);
			}
			else if (m == 77) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xA0000000);
			}
			else if (m == 78) {
				yolo.read_img(indata_path_0, 0xD0000000);
				yolo.read_img(indata_path_1, 0xF0000000);
			}
			else if (m == 79) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 80) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xB0000000);
			}
			else if (m == 81) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
			else if (m == 82) {
				yolo.read_img(indata_path_0, 0xF0000000);
				yolo.read_img(indata_path_1, 0xC0000000);
			}
		}
		else if ((n >= 83) && (n <= 84)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/up" + std::to_string(n - 83) + "_data.bin";
			if (m == 83) {
				yolo.read_img(indata_path_0, 0xC0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
			else if (m == 84) {
				yolo.read_img(indata_path_0, 0xB0000000);
				yolo.read_img(indata_path_1, 0xD0000000);
			}
		}
		else if ((n >= 85) && (n <= 87)) {
			indata_path_0 = "F:/VSstudio/Yolov5/Yolov5/indata_bin/max" + std::to_string(n - 84) + "_data.bin";
			if (m == 85) {
				yolo.read_img(indata_path_0, 0xC0000000);
			}
			else if (m == 86) {
				yolo.read_img(indata_path_0, 0xD0000000);
			}
			else if (m == 87) {
				yolo.read_img(indata_path_0, 0xE0000000);
			}
		}
	
	
	
	
		//size
		size_t hout = 0;
		size_t cout = 0;
		if ((n == 2) || (n == 7) || (n == 68)) {
			hout = 160;
			cout = 32;
		}
		else if ((n == 3) || (n == 4) || (n == 5) || (n == 6) || (n == 61)) {
			hout = 160;
			cout = 16;
		}
		else if (n == 8) {
			hout = 80;
			cout = 64;
		}
		else if ((n == 9) || (n == 10) || (n == 11) || (n == 12) || (n == 13) || (n == 14) || (n == 41) || (n == 42) || (n == 43) || (n == 44) || (n == 62) || (n == 63)) {
			hout = 80;
			cout = 32;
		}
		else if ((n == 15) || (n == 45) || (n == 69) || (n == 78) || (n == 84)) {
			hout = 80;
			cout = 64;
		}
		else if ((n == 16) || (n == 25) || (n == 39) || (n == 51) || (n == 70) || (n == 83)) {
			hout = 40;
			cout = 128;
		}
		else if ((n == 17) || (n == 18) || (n == 19) || (n == 20) || (n == 21) || (n == 22) || (n == 23) || (n == 24) || (n == 35)
			|| (n == 36) || (n == 37) || (n == 38) || (n == 40) || (n == 46) || (n == 47) || (n == 48) || (n == 49) || (n == 50)
			|| (n == 64) || (n == 65) || (n == 66)) {
			hout = 40;
			cout = 64;
		}
		else if ((n == 26) || (n == 31) || (n == 33) || (n == 57) || (n == 71) || (n == 72) || (n == 73) || (n == 81) || (n == 82)) {
			hout = 20;
			cout = 256;
		}
		else if ((n == 27) || (n == 28) || (n == 29) || (n == 30) || (n == 32) || (n == 34) || (n == 52) || (n == 53) || (n == 54)
			|| (n == 55) || (n == 56) || (n == 67) || (n == 85) || (n == 86) || (n == 87)) {
			hout = 20;
			cout = 128;
		}
		else if (n == 58) {
			hout = 20;
			cout = 32;
		}
		else if (n == 59) {
			hout = 40;
			cout = 32;
		}
		else if (n == 60) {
			hout = 80;
			cout = 32;
		}
		else if (n == 74) {
			hout = 20;
			cout = 512;
		}
		else if (n == 75) {
			hout = 40;
			cout = 256;
		}
		else if ((n == 76) || (n == 79) || (n == 80)) {
			hout = 40;
			cout = 128;
		}
		else if (n == 77) {
			hout = 80;
			cout = 128;
		}
		else if ((n == 0) || (n == 1)) {
			hout = 320;
			cout = 16;
		}
		size_t wout = hout;
		size_t size = hout * wout * cout;
	
	
		//outdata
		std::string outdata_path;
		if (n == 0) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/focus_result.txt";
		}
		else if ((n > 0) && (n < 58)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/conv" + std::to_string(n) + "_result.txt";
		}
		else if ((n >= 58) && (n <= 60)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/out" + std::to_string(n - 57) + "_result.txt";
		}
		else if ((n >= 61) && (n <= 67)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/add" + std::to_string(n - 61) + "_result.txt";
		}
		else if ((n >= 68) && (n <= 71)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat" + std::to_string(n - 68) + "_result.txt";
		}
		else if ((n >= 72) && (n <= 74)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat4_" + std::to_string(n - 71) + "_result.txt";
		}
		else if ((n >= 75) && (n <= 82)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/cat" + std::to_string(n - 70) + "_result.txt";
		}
		else if ((n >= 83) && (n <= 84)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/up" + std::to_string(n - 83) + "_result.txt";
		}
		else if ((n >= 85) && (n <= 87)) {
			outdata_path = "F:/VSstudio/Yolov5/Yolov5/outdata/max" + std::to_string(n - 84) + "_result.txt";
		}
	
	
		//addr
		unsigned int read_addr = 0xB0000000;
		if ((n == 0) || (n == 2) || (n == 5) || (n == 7) || (n == 9) || (n == 13) || (n == 16) || (n == 19) || (n == 23)
			|| (n == 26) || (n == 29) || (n == 31) || (n == 33) || (n == 37) || (n == 40) || (n == 48) || (n == 52) || (n == 53)
			|| (n == 63) || (n == 72) || (n == 75)
			|| (n == 76)) {
			read_addr = 0xB0000000;
		}
		else if ((n == 1) || (n == 3) || (n == 8) || (n == 11) || (n == 17) || (n == 21) || (n == 27) || (n == 32)
			|| (n == 34) || (n == 54) || (n == 65) || (n == 68) || (n == 69) || (n == 70)
			|| (n == 71) || (n == 73)) {
			read_addr = 0xC0000000;
		}
		else if ((n == 4) || (n == 10) || (n == 18) || (n == 28) || (n == 35) || (n == 38) || (n == 39)
			|| (n == 41) || (n == 44) || (n == 47) || (n == 55) || (n == 74) || (n == 83)
			|| (n == 84) || (n == 85) || (n == 61) || (n == 62) || (n == 64) || (n == 66) || (n == 67)) {
			read_addr = 0xD0000000;
		}
		else if ((n == 6) || (n == 12) || (n == 14) || (n == 20) || (n == 22) || (n == 24) || (n == 30)
			|| (n == 36) || (n == 43) || (n == 49) || (n == 77) || (n == 78) || (n == 79) || (n == 80)
			|| (n == 81) || (n == 82) || (n == 86)) {
			read_addr = 0xE0000000;
		}
		else if ((n == 42) || (n == 46) || (n == 50) || (n == 56) || (n == 87)) {
			read_addr = 0xF0000000;
		}
		else if ((n == 15) || (n == 57)) {
			read_addr = 0xA0000000;
		}
		else if ((n == 25) || (n == 51)) {
			read_addr = 0xA5000000;
		}
		else if ((n == 45)) {
			read_addr = 0xAA000000;
		}
		else if (n == 58) {
			read_addr = 0xA3000000;
		}
		else if (n == 59) {
			read_addr = 0xA8000000;
		}
		else if (n == 60) {
			read_addr = 0xAC000000;
		}
	
	
	
		std::cout << ": " << n << std::endl;
		yolo.start_calc();
		std::cout << "㿪ʼ " << std::endl;
	
	
	
		auto start = std::chrono::high_resolution_clock::now();

		long long fpga_cycles = yolo.calculate_end();
		if (fpga_cycles == -1) {
			std::cout << "Error: FPGA communication failed or protocol mismatch." << std::endl;
		}
		else {
			// 成功获取！
			// 假设 FPGA 频率是 300MHz (根据实际情况修改)

			double time_ms = fpga_cycles / (fpga_freq_mhz * 1000.0); // ĵλʾ
			std::cout << "FPGA Cycles: " << fpga_cycles << std::endl;
			std::cout << "FPGA Time: " << time_ms << " ms (assuming 300MHz)" << std::endl;
		}

		auto stop = std::chrono::high_resolution_clock::now();
		auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start).count();
		std::cout << "1 Elapsed time: " << duration / 1000.0 << " ms\n";
	
	
	
		yolo.write_img(outdata_path, size, read_addr);
	
	
		std::cout << "дɣس˳...:" << n << std::endl;

		
		std::cout << "ϵ" << count << std::endl;
		count = count + 1;
	}
	


	//释放常量区的指针
	yolo.start_calc();


	std::cout << "3接受到结果 进行nms...:" << std::endl;
	yolo.nms(img);


	yolo.save_yolo_layers_to_file("F:\\python\\yolov5\\output.bin");

#endif



	Sleep(100);
	printf("4555");
	//yolo.nms(img);

	//while (true) 
	//{

	//}

	

	//return 0;
}


