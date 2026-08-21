module hdmi_top #(
    //DVP输出的位宽
    parameter DATA_WIDTH = 16,

    //AXI
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter AXI_DATA_WIDTH = 128,

    //摄像
    parameter  H_CMOS_DISP = 11'd1920  , //CMOS分辨率--行
    parameter  V_CMOS_DISP = 11'd1080  , //CMOS分辨率--列	
    parameter  CAM_DATA_LEN  = (H_CMOS_DISP * V_CMOS_DISP * DATA_WIDTH/8) / (AXI_DATA_WIDTH/8), //1280*720 * 2 /16

    //摄像头输出控制基地址
    parameter BASE_ADDR = 32'h2000_0000,

    //板卡设备
    parameter DEVICE = "PG"
)(
    input         clk_10m               ,
    input         clk_10m_rst_n         ,

    //HDMI接口

    //ms72XX
    output            rstn_out,

    // FMC I2C 
    output            iic_scl,
    inout             iic_sda, 

    output            iic_tx_scl,
    inout             iic_tx_sda, 

    //HDMI IN
    input             pixclk_in,                            
    input             vs_in , 
    input             hs_in , 
    input             de_in ,
    input     [7:0]   r_in  , 
    input     [7:0]   g_in  , 
    input     [7:0]   b_in  ,  

    //摄像头控制寄存器
    input                             s_axi_awvalid         ,
    output                            s_axi_awready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_awaddr          ,

    input                             s_axi_wvalid          ,
    output                            s_axi_wready          ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_wdata           ,
    input  [AXI_ADDR_WIDTH/8-1 : 0]   s_axi_wstrb           ,

    output                            s_axi_bvalid          ,
    input                             s_axi_bready          ,
    output [ 1 : 0]                   s_axi_bresp           ,

    input                             s_axi_arvalid         ,
    output                            s_axi_arready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_araddr          ,

    output                            s_axi_rvalid          ,
    input                             s_axi_rready          ,
    output [AXI_ADDR_WIDTH-1 : 0]     s_axi_rdata           ,
    output [ 1 : 0]                   s_axi_rresp           ,

    //摄像头AXI_stream数据
    input                          video_clk      ,
    input                          video_rst      ,
    output [AXI_ADDR_WIDTH-1 : 0]  cam_cmd_addr    ,
    output [AXI_LEN_WIDTH-1 : 0]   cam_cmd_len     ,
    output                         cam_cmd_valid   ,
    input                          cam_cmd_ready   ,

    output [AXI_DATA_WIDTH-1 : 0] cam_s_data       ,
    output                        cam_s_data_valid ,
    output                        cam_s_data_last  ,
    input                         cam_s_data_ready ,

    //请求DMA来搬运数据
    input                         xdma_clk  ,
    output  [1 : 0]               xdma_irq   

);

    wire                    video_vsync ;
    wire                    video_hsync ;
    wire                    video_valid ;
    wire [DATA_WIDTH-1 : 0] video_data  ;

// ---------------- 新增修改区域：使用 GTP_IODELAY_E2 进行精细延迟调整 ----------------

    // 1. 声明经过 GTP_IODELAY_E2 调整后的信号
    wire         de_in_dly, vs_in_dly, hs_in_dly;
    wire [7:0]   r_in_dly, g_in_dly, b_in_dly;

    // 2. 统一设定延迟步进值 (0~255)
    // 提示：若依然有噪点，请修改此处 8'd0 为其他值 (如 8'd10, 8'd20 等) 重新编译寻找最佳采样窗口
    localparam IODELAY_STEP = 8'd40;

    // 3. 实例化 GTP_IODELAY_E2 原语
    // --- 控制信号延迟例化 ---
    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PARAMETER"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_de (
        .DO         (de_in_dly),  
        .DELAY_SEL  (1'b0),      // 固定接0 (针对输入延迟)
        .DI         (de_in),     
        .EN_N       (1'b0),      // 低电平使能
        .DELAY_STEP (8'b0)       // 使用PARAMETER模式时，动态输入端固定接地
    );

    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PARAMETER"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_vs (
        .DO         (vs_in_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (vs_in),     
        .EN_N       (1'b0),
        .DELAY_STEP (8'b0)  
    );

    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PARAMETER"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_hs (
        .DO         (hs_in_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (hs_in),     
        .EN_N       (1'b0),
        .DELAY_STEP (8'b0)  
    );

    // --- 数据信号(RGB)延迟例化 ---
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : hdmi_data_iodelay
            GTP_IODELAY_E2 #(
                .DELAY_STEP_VALUE(IODELAY_STEP),
                .DELAY_STEP_SEL("PARAMETER"),
                .TDELAY_EN("FALSE") 
            ) u_iodelay_r (
                .DO         (r_in_dly[i]),  
                .DELAY_SEL  (1'b0),
                .DI         (r_in[i]),     
                .EN_N       (1'b0),
                .DELAY_STEP (8'b0)  
            );

            GTP_IODELAY_E2 #(
                .DELAY_STEP_VALUE(IODELAY_STEP),
                .DELAY_STEP_SEL("PARAMETER"),
                .TDELAY_EN("FALSE") 
            ) u_iodelay_g (
                .DO         (g_in_dly[i]),  
                .DELAY_SEL  (1'b0),
                .DI         (g_in[i]),     
                .EN_N       (1'b0),
                .DELAY_STEP (8'b0)  
            );

            GTP_IODELAY_E2 #(
                .DELAY_STEP_VALUE(IODELAY_STEP),
                .DELAY_STEP_SEL("PARAMETER"),
                .TDELAY_EN("FALSE") 
            ) u_iodelay_b (
                .DO         (b_in_dly[i]),  
                .DELAY_SEL  (1'b0),
                .DI         (b_in[i]),     
                .EN_N       (1'b0),
                .DELAY_STEP (8'b0)  
            );
        end
    endgenerate

// 在 hdmi_loop.v 中添加第一级寄存器
(* IOB = "TRUE" *)reg         de_in_r, vs_in_r, hs_in_r;
(* IOB = "TRUE" *)reg [7:0]   r_in_r, g_in_r, b_in_r;
always @(negedge pixclk_in) begin 
    // 4. 修改为采样延迟后的信号
    de_in_r <= de_in_dly;
    vs_in_r <= vs_in_dly;
    hs_in_r <= hs_in_dly;
    r_in_r  <= r_in_dly;
    g_in_r  <= g_in_dly;
    b_in_r  <= b_in_dly;
end

// ---------------- 新增修改区域 结束 ----------------

hdmi_loop #(
    .DATA_WIDTH(DATA_WIDTH),
    //板卡设备
    .DEVICE(DEVICE)
)
hdmi_loop(
    
    .clk_10m(clk_10m)            ,  // Clock i2c的参考时钟
	.rst_n  (clk_10m_rst_n)      ,  // Asynchronous reset active low

    //ms72XX
    .rstn_out(rstn_out),

    // FMC I2C 
    .iic_scl(iic_scl),
    .iic_sda(iic_sda), 

    .iic_tx_scl(iic_tx_scl),
    .iic_tx_sda(iic_tx_sda), 

    //HDMI IN
    .pixclk_in(pixclk_in),                            
    .vs_in(vs_in_r) , 
    .hs_in(hs_in_r) , 
    .de_in(de_in_r) ,
    .r_in (r_in_r ) , 
    .g_in (g_in_r ) , 
    .b_in (b_in_r ) ,  

    //HDMI OUT
    .video_clk          (video_clk  ),  // 整合后的RGB拿取时钟
    .video_rst          (video_rst  ),
    .video_vsync        (video_vsync),  //帧有效信号    
    .video_hsync        (video_hsync),  //行有效信号
    .video_valid        (video_valid),  //数据有效使能信号
    .video_data         (video_data )   //有效数据   

);

    wire                        cam_en    ;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_1;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_2;

    wire [1 : 0]  xdma_req  ;  
    wire [1 : 0]  xdma_ack  ; 
    ov5640_ddr #(
        .DATA_WIDTH(DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_LEN_WIDTH(AXI_LEN_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .CAM_DATA_LEN(CAM_DATA_LEN),     //(1280*720*2) / (16)
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
        .DATA_WIDTH   (2), 
        .DEST_SYNC_FF (4), 
        .INIT_SYNC_FF (0), 
        .SRC_INPUT_REG(1)  
    )
    pipe_cdc(
        .src_clk(video_clk),  
        .src_in(xdma_req),   
        .dest_clk(xdma_clk), 
        .dest_out(xdma_irq)  
    );

endmodule