module ov5640_top #(
    //DVP输出的位宽
    parameter DATA_WIDTH = 16,

    //AXI
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter AXI_DATA_WIDTH = 128,

    //I2C
    parameter   SLAVE_ADDR = 7'h3c   ,  //I2C从机地址
    parameter   BIT_CTRL   = 1'b1           , //OV5640的字节地址为16位  0:8位 1:16位
    parameter   CLK_FREQ   = 26'd50_000_000, //模块输入的时钟频率
    parameter   I2C_FREQ   = 18'd250_000,    //IIC_SCL的时钟频率

    //摄像
    parameter  H_CMOS_DISP = 11'd1280  , //CMOS分辨率--行
    parameter  V_CMOS_DISP = 11'd720   , //CMOS分辨率--列	
    parameter  TOTAL_H_PIXEL = 12'd2570, //水平总像素大小 (28.58帧)
    parameter  TOTAL_V_PIXEL = 12'd980 , //垂直总像素大小 (28.58帧)
    parameter  CAM_DATA_LEN  = H_CMOS_DISP * V_CMOS_DISP * DATA_WIDTH/8 / 16, //1280*720 * 2 /16

    //摄像头输出控制基地址
    parameter BASE_ADDR = 32'h2000_0000,

    //板卡设备
    parameter DEVICE = "PG"
)(
    // input         pl_clk                ,  //总时钟
    input         clk_50m               ,
    input         clk_50m_rst_n         ,
    //摄像头接口
    input         cam_pclk              ,  //cmos 数据像素时钟
    input         cam_vsync             ,  //cmos 场同步信
    input         cam_href              ,  //cmos 行同步信
    input [7 : 0] cam_data              ,  //cmos 数据
    output        cam_rst_n             ,  //cmos 复位信号，低电平有效
    output        cam_pwdn              ,  //电源休眠模式选择 0：正常模 1：电源休眠模
    output        cam_scl               ,  //cmos SCCB_SCL
    inout         cam_sda               ,  //cmos SCCB_SDA   


    //摄像头控制寄存器
    input                             s_axi_awvalid         /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_awready         /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_awaddr          /*synthesis PAP_MARK_DEBUG="1"*/,

    input                             s_axi_wvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_wready          /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_wdata           /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH/8-1 : 0]   s_axi_wstrb           /*synthesis PAP_MARK_DEBUG="1"*/,

    output                            s_axi_bvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    input                             s_axi_bready          /*synthesis PAP_MARK_DEBUG="1"*/,
    output [ 1 : 0]                   s_axi_bresp           /*synthesis PAP_MARK_DEBUG="1"*/,

    input                             s_axi_arvalid         /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_arready         /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_araddr          /*synthesis PAP_MARK_DEBUG="1"*/,

    output                            s_axi_rvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    input                             s_axi_rready          /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_ADDR_WIDTH-1 : 0]     s_axi_rdata           /*synthesis PAP_MARK_DEBUG="1"*/,
    output [ 1 : 0]                   s_axi_rresp           /*synthesis PAP_MARK_DEBUG="1"*/,



    //摄像头AXI_stream数据
    input                          video_clk      /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          video_rst      /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_ADDR_WIDTH-1 : 0]  cam_cmd_addr    /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_LEN_WIDTH-1 : 0]   cam_cmd_len     /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         cam_cmd_valid   /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          cam_cmd_ready   /*synthesis PAP_MARK_DEBUG="1"*/,

    output [AXI_DATA_WIDTH-1 : 0] cam_s_data       /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        cam_s_data_valid /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        cam_s_data_last  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                         cam_s_data_ready /*synthesis PAP_MARK_DEBUG="1"*/,

    //请求DMA来搬运数据
    input                         xdma_clk  ,
    output  [1 : 0]               xdma_irq   /*synthesis PAP_MARK_DEBUG="1"*/

);


    // wire clk_50m;
    // wire video_clk;
    // wire locked;
    // wire clk_50m_rst_n = locked     ;
// generate
//     if(DEVICE == "PG") begin
//         ov5640_clk ov5640_clk(
//           .clkout0(clk_50m),      // output 50M
//         //   .clkout1(video_clk),    // output 200M
//           .lock(locked),          // output
//           .clkin1(pl_clk)         // input
//         );
//     end
//     else if(DEVICE == "Xilinx") begin
//         ov5640_clk ov5640_clk
//         (
//             // Clock out ports
//             .clk_out1(clk_50m ),    // output 50M
//             // .clk_out2(video_clk ),  // output 200M
//             // Status and control signals
//             .locked(locked),        // output locked
//            // Clock in ports
//             .clk_in1(pl_clk)        // input clk_in1
//         );  
//     end
// endgenerate


    
    wire                    video_vsync ;
    wire                    video_hsync ;
    wire                    video_valid ;
    wire [DATA_WIDTH-1 : 0] video_data  ;

// ---------------- 新增修改区域：使用 GTP_IODELAY_E2 进行精细延迟调整 ----------------
    
    // 声明经过延迟调整后的信号
    wire         cam_vsync_dly;
    wire         cam_href_dly;
    wire [7 : 0] cam_data_dly;
    
    // 设置延迟步进值 (0~255)
    localparam IODELAY_STEP = 8'd40;

    // --- 控制信号延迟例化 ---
    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PARAMETER"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_vsync (
        .DO         (cam_vsync_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (cam_vsync),     
        .EN_N       (1'b0),
        .DELAY_STEP (8'b0)  
    );

    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PARAMETER"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_href (
        .DO         (cam_href_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (cam_href),     
        .EN_N       (1'b0),
        .DELAY_STEP (8'b0)  
    );

    // --- 数据信号(cam_data)延迟例化 ---
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : cam_data_iodelay
            GTP_IODELAY_E2 #(
                .DELAY_STEP_VALUE(IODELAY_STEP),
                .DELAY_STEP_SEL("PARAMETER"),
                .TDELAY_EN("FALSE") 
            ) u_iodelay_data (
                .DO         (cam_data_dly[i]),  
                .DELAY_SEL  (1'b0),
                .DI         (cam_data[i]),     
                .EN_N       (1'b0),
                .DELAY_STEP (8'b0)  
            );
        end
    endgenerate
// ---------------- 新增修改区域 结束 ----------------


    ov5640 #(
        //DVP数据
        .DATA_WIDTH(DATA_WIDTH),
        //I2C
        .SLAVE_ADDR(SLAVE_ADDR)   ,      //I2C从机地址
        .BIT_CTRL  (BIT_CTRL)     ,      //OV5640的字节地址为16位  0:8位 1:16位
        .CLK_FREQ  (CLK_FREQ)     ,      //模块输入的时钟频率
        .I2C_FREQ  (I2C_FREQ)     ,      //IIC_SCL的时钟频率

        //摄像
        .H_CMOS_DISP(H_CMOS_DISP), //CMOS分辨率--行
        .V_CMOS_DISP(V_CMOS_DISP), //CMOS分辨率--列	
        .TOTAL_H_PIXEL(TOTAL_H_PIXEL), //水平总像素大小
        .TOTAL_V_PIXEL(TOTAL_V_PIXEL), //垂直总像素大小

        //板卡设备
        .DEVICE(DEVICE)
    )
    ov5640(
        .clk_50m            (clk_50m      ),  // i2c的参考时钟Clock
        .rst_n              (clk_50m_rst_n),  // Asynchronous reset active low

        .ov_rst_n           (ov_rst_n ),
        .cam_pclk           (cam_pclk ),  //cmos 数据像素时钟
        // 使用经过延迟处理的信号替换原始管脚信号
        .cam_vsync          (cam_vsync_dly),  //cmos 场同步信号 
        .cam_href           (cam_href_dly ),  //cmos 行同步信号
        .cam_data           (cam_data_dly ),  //cmos 数据
        
        .cam_rst_n          (cam_rst_n),  //cmos 复位信号，低电平有效
        .cam_pwdn           (cam_pwdn ),  //电源休眠模式选择 0：正常模式 1：电源休眠模式
        .cam_scl            (cam_scl  ),  //cmos SCCB_SCL线
        .cam_sda            (cam_sda  ),  //cmos SCCB_SDA线     

        .video_clk          (video_clk  ),  // 整合后的RGB拿取时钟
        .video_rst          (video_rst  ),
        .video_vsync        (video_vsync),  //帧有效信号    
        .video_hsync        (video_hsync),  //行有效信号
        .video_valid        (video_valid),  //数据有效使能信号
        .video_data         (video_data )   //有效数据   
    
    );


    // wire video_rst = !locked;

    wire                        cam_en    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_1/*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_2/*synthesis PAP_MARK_DEBUG="1"*/;

    wire [1 : 0]  xdma_req  ;  
    wire [1 : 0]  xdma_ack  ; 
    ov5640_ddr #(
        .DATA_WIDTH(DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_LEN_WIDTH(AXI_LEN_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .CAM_DATA_LEN(CAM_DATA_LEN),     //1280*720*3/16
        .DEVICE(DEVICE)
    )
    ov5640_ddr(
        .axi_clk        (video_clk),
        .axi_rst        (video_rst), 

        .axi_cam_en     (cam_en    ),
        .cam_data_addr_1(cam_addr_1),
        .cam_data_addr_2(cam_addr_2),
        .cam_data_len   (CAM_DATA_LEN), //以16字节为单位

        .s_data         (video_data ),
        .s_data_valid   (video_valid),
        .s_hsync        (video_hsync),
        .s_vsync        (video_vsync),

        //AXI协议的
        .axi_data       (cam_s_data      ),
        .axi_data_valid (cam_s_data_valid),
        .axi_data_last  (cam_s_data_last ), 
        .axi_data_ready (cam_s_data_ready),

        .axi_cmd_addr   (cam_cmd_addr  ),
        .axi_cmd_len    (cam_cmd_len   ),
        .axi_cmd_valid  (cam_cmd_valid ),
        .axi_cmd_ready  (cam_cmd_ready ),

        .xdma_req       (xdma_req      ),
        .xdma_ack       (xdma_ack      ) 
    );



    ov5640_reg #(
        .BASE_ADDR(BASE_ADDR),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) 
    ov5640_reg(
        .clk                   (video_clk    ),
        .rst                   (video_rst    ),

        .s_axi_awvalid         (s_axi_awvalid),
        .s_axi_awready         (s_axi_awready),
        .s_axi_awaddr          (s_axi_awaddr ),

        .s_axi_wvalid          (s_axi_wvalid ),
        .s_axi_wready          (s_axi_wready ),
        .s_axi_wdata           (s_axi_wdata  ),
        .s_axi_wstrb           (s_axi_wstrb  ),

        .s_axi_bvalid          (s_axi_bvalid ),
        .s_axi_bready          (s_axi_bready ),
        .s_axi_bresp           (s_axi_bresp  ),

        .s_axi_arvalid         (s_axi_arvalid),
        .s_axi_arready         (s_axi_arready),
        .s_axi_araddr          (s_axi_araddr ),

        .s_axi_rvalid          (s_axi_rvalid ),
        .s_axi_rready          (s_axi_rready ),
        .s_axi_rdata           (s_axi_rdata  ),
        .s_axi_rresp           (s_axi_rresp  ),

        .xdma_ack              (xdma_ack     ),
        .cam_en                (cam_en       ),
        .cam_addr_1            (cam_addr_1   ), 
        .cam_addr_2            (cam_addr_2   )
    );




    // RGB的拿取时钟video_clk 到 xdma时钟域
    pipe_cdc #(
        .DATA_WIDTH   (2), // 【核心修改】可自由配置的数据位宽
        .DEST_SYNC_FF (4), // 目标时钟域同步触发器级数 (范围: 2-10)
        .INIT_SYNC_FF (0), // 仿真与上电初始值 (0或1)
        .SRC_INPUT_REG(1)  // 源时钟域输入是否先打一拍寄存 (0=否, 1=是)
    )
    pipe_cdc(
        .src_clk(video_clk),  // 源时钟
        .src_in(xdma_req),   // 跨域前的多比特总线
        .dest_clk(xdma_clk), // 目标时钟
        .dest_out(xdma_irq)  // 跨域后的安全多比特总线
    );



endmodule