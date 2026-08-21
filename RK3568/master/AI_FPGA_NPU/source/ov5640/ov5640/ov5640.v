module ov5640 #(
    //DVP输出的位宽
    parameter   DATA_WIDTH = 16,
    //I2C
    parameter   SLAVE_ADDR = 7'h3c   ,  //I2C从机地址
    parameter   BIT_CTRL   = 1'b1           , //OV5640的字节地址为16位  0:8位 1:16位
    parameter   CLK_FREQ   = 26'd50_000_000, //模块输入的时钟频率
    parameter   I2C_FREQ   = 18'd250_000,    //IIC_SCL的时钟频率

    //摄像
    parameter  H_CMOS_DISP = 11'd1280  , //CMOS分辨率--行
    parameter  V_CMOS_DISP = 11'd720   , //CMOS分辨率--列	
    parameter  TOTAL_H_PIXEL = 12'd2570, //水平总像素大小
    parameter  TOTAL_V_PIXEL = 12'd980 , //垂直总像素大小
    //板卡设备
    parameter DEVICE = "PG"
)(
    

	input              clk_50m            ,  // Clock i2c的参考时钟
	input              rst_n              ,  // Asynchronous reset active low

    output             ov_rst_n           /*synthesis PAP_MARK_DEBUG="1"*/,  //SCCB配置完成

	input              cam_pclk           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos 数据像素时钟
    input              cam_vsync          /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos 场同步信号
    input              cam_href           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos 行同步信号
    input   [7:0]      cam_data           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos 数据
    output             cam_rst_n          /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos 复位信号，低电平有效
    output             cam_pwdn           /*synthesis PAP_MARK_DEBUG="1"*/,  //电源休眠模式选择 0：正常模式 1：电源休眠模式
    output             cam_scl            /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos SCCB_SCL线
    inout              cam_sda            /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos SCCB_SDA线    

    input                      video_clk          ,  // 读出摄像头数据时钟
    input                      video_rst          ,
    output                     video_vsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //帧有效信号    
    output                     video_hsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //行有效信号  //没用
    output                     video_valid        /*synthesis PAP_MARK_DEBUG="1"*/,  //8bit转16bit数据有效使能信号
    output [DATA_WIDTH-1:0]    video_data         /*synthesis PAP_MARK_DEBUG="1"*/   //有效数据   

    // //用户接口                              
    // output                      cmos_frame_vsync ,  //帧有效信号    
    // output                      cmos_frame_href  ,  //行有效信号    //没用
    // output                      cmos_frame_valid ,  //8bit转16bit数据有效使能信号
    // output  [DATA_WIDTH-1 : 0]  cmos_frame_data     //有效数据        
	
);

// wire cam_pclk_bufg/*synthesis PAP_MARK_DEBUG="1"*/;
// GTP_CLKBUFG u_pclk_bufg (
//     .CLKOUT(cam_pclk_bufg),
//     .CLKIN(cam_pclk)
// );

//=========================================================
// 顶层极简复位控制：只管前 5ms 的物理死锁
// 50MHz 时钟下，5ms = 250,000 个周期
//=========================================================
reg [$clog2(CLK_FREQ/1000*7) : 0] power_on_cnt; // 18位足够存 250,000
reg                               i2c_start_en;

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        power_on_cnt  <= 18'd0;
        i2c_start_en  <= 1'b0; // 强行按住底层的 I2C 模块
    end 
    else begin
        if (power_on_cnt < CLK_FREQ/1000*7) begin 
            power_on_cnt <= power_on_cnt + 1'b1;
        end 
        else begin
            // 5ms 到了！同时松手！
            i2c_start_en  <= 1'b1; // I2C 模块苏醒，开始接力跑它自己的 20ms
        end
    end
end

assign cam_rst_n = i2c_start_en;
assign cam_pwdn  = 1'b0;

//SCCB配置完成才抓取摄像头
assign ov_rst_n = rst_n & cam_init_done;






wire            rst_n           ; 
wire            i2c_dri_clk     ;   //I2C操作时钟
wire            i2c_done        ;   //I2C读写完成信号
wire   [7:0]    i2c_data_r      ;   //I2C读到的数据
wire            i2c_exec        ;   //I2C触发信号
wire   [23:0]   i2c_data        ;   //I2C写地址+数据
wire            i2c_rh_wl       ;   //I2C读写控制信号
wire            cam_init_done   ;   //摄像头出初始化完成信号 






wire            dri_clk     ;

i2c_dri #(
    .SLAVE_ADDR(SLAVE_ADDR), //I2C从机地址
    .CLK_FREQ  (CLK_FREQ  ), //模块输入的时钟频率
    .I2C_FREQ  (I2C_FREQ  )  //IIC_SCL的时钟频率
)
i2c_dri(                                                            
    .clk  (clk_50m)  ,    
    .rst_n(rst_n)    ,   
                                         
    //i2c interface                      
    .i2c_exec   (i2c_exec  ),  //I2C触发执行信号
    .bit_ctrl   (BIT_CTRL  ),  //字地址位控制(16b/8b)
    .i2c_rh_wl  (i2c_rh_wl ),  //I2C读写控制信号
    .i2c_addr   (i2c_data[23:8]),  //I2C器件内地址
    .i2c_data_w (i2c_data[7:0]),  //I2C要写的数据
    .i2c_data_r (i2c_data_r),  //I2C读出的数据
    .i2c_done   (i2c_done  ),  //I2C一次操作完成
    .i2c_ack    (),            //I2C应答标志 0:应答 1:未应答
    .scl        (cam_scl   ),  //I2C的SCL时钟信号
    .sda        (cam_sda   ),  //I2C的SDA信号
                                       
    //user interface                   
    .dri_clk(dri_clk)       //驱动I2C操作的驱动时钟
);



ov5640_i2c_rgb565_cfg #(
    .I2C_FREQ  (I2C_FREQ  )  //IIC_SCL的时钟频率
)
ov5640_i2c_rgb565_cfg(  
    .clk(dri_clk)    ,     //时钟信号 SCL的4倍频
    .rst_n(rst_n & i2c_start_en)    ,     //复位信号，低电平有效
    
    .i2c_data_r   (i2c_data_r),  //I2C读出的数据   
    .i2c_done     (i2c_done),    //I2C寄存器配置完成信号 
    .cmos_h_pixel (H_CMOS_DISP),
    .cmos_v_pixel (V_CMOS_DISP),
    .total_h_pixel(TOTAL_H_PIXEL), //水平总像素大小
    .total_v_pixel(TOTAL_V_PIXEL),  //垂直总像素大小
    .i2c_exec     (i2c_exec),     //I2C触发执行信号   
    .i2c_data     (i2c_data),     //I2C要配置的地址与数据(高16位地址,低8位数据)
    .i2c_rh_wl    (i2c_rh_wl),     //I2C读写控制信号
    .init_done    (cam_init_done) //初始化完成信号
);




// // 在 hdmi_loop.v 中添加第一级寄存器
// (* IOB = "TRUE" *)reg         cam_vsync_r, cam_href_r;
// (* IOB = "TRUE" *)reg [7:0]   cam_data_r;
// always @(posedge cam_pclk) begin 
//     cam_vsync_r <= cam_vsync;   
//     cam_href_r  <= cam_href;
//     cam_data_r  <= cam_data;
// end


cmos_capture #(
    .DATA_WIDTH(DATA_WIDTH)
)
cmos_capture(
    .rst_n (ov_rst_n)           ,  //复位信号    
    //摄像头接口                           
    .cam_pclk   (cam_pclk) ,   //cmos 数据像素时钟
    .cam_vsync  (cam_vsync),  //cmos 场同步信号
    .cam_href   (cam_href) ,  //cmos 行同步信号
    .cam_data   (cam_data) ,                       
    //用户接口                              
    .cmos_frame_vsync(cmos_frame_vsync),  //帧有效信号    
    .cmos_frame_href (cmos_frame_href ),  //行有效信号
    .cmos_frame_valid(cmos_frame_valid),  //数据有效使能信号
    .cmos_frame_data (cmos_frame_data )   //有效数据        
);




wire                    cmos_frame_vsync /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    cmos_frame_href  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    cmos_frame_valid /*synthesis PAP_MARK_DEBUG="1"*/;
wire [DATA_WIDTH-1 : 0] cmos_frame_data  /*synthesis PAP_MARK_DEBUG="1"*/;

// wire [23:0]             cmos_frame_datas;

// assign cmos_frame_datas = {
//     cmos_frame_data[15:11], cmos_frame_data[15:13], // R: 5位 + 高3位
//     cmos_frame_data[10:5] , cmos_frame_data[10:9] , // G: 6位 + 高2位
//     cmos_frame_data[4:0]  , cmos_frame_data[4:2]    // B: 5位 + 高3位
// };




reg         cam_vsync_r, cam_href_r;
reg [7:0]   cam_data_r;

reg [DATA_WIDTH-1 : 0] cmos_frame_data_r;
reg cmos_frame_valid_r, cmos_frame_href_r, cmos_frame_vsync_r;
always @(negedge cam_pclk) begin 
    cmos_frame_data_r <= cmos_frame_data ; 
    cmos_frame_valid_r <= cmos_frame_valid;
    cmos_frame_href_r <= cmos_frame_href ;
    cmos_frame_vsync_r <= cmos_frame_vsync;
end


ov5640_cdc #(
    .DATA_WIDTH(DATA_WIDTH),        ////////////////
    .DEVICE(DEVICE)
)
ov5640_cdc(
    .cam_clk(cam_pclk),
    .cam_rst(!cam_rst_n),

    .s_data (cmos_frame_data_r )    , //////////////
    .s_valid(cmos_frame_valid_r)    ,
    .s_hsync(cmos_frame_href_r )    ,
    .s_vsync(cmos_frame_vsync_r)    ,

    .video_clk  (video_clk  ), 
    .video_rst  (video_rst  ),
    .video_data (video_data ),
    .video_valid(video_valid),
    .video_hsync(video_hsync),
    .video_vsync(video_vsync) 
);


endmodule