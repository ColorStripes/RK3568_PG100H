`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-01-29 20:31  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1

module hdmi_loop #(
    parameter   DATA_WIDTH = 16,
    //板卡设备
    parameter DEVICE = "PG"

)(
    
    input             clk_10m            ,  // Clock i2c的参考时钟
	input             rst_n              ,  // Asynchronous reset active low

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

    //HDMI OUT
    input                      video_clk          ,  // 读出摄像头数据时钟
    input                      video_rst          ,
    output                     video_vsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //帧有效信号    
    output                     video_hsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //行有效信号  //没用
    output                     video_valid        /*synthesis PAP_MARK_DEBUG="1"*/,  //8bit转16bit数据有效使能信号
    output [DATA_WIDTH-1:0]    video_data         /*synthesis PAP_MARK_DEBUG="1"*/   //有效数据   

);




    ms72xx_ctl ms72xx_ctl(
        .clk         (  clk_10m    ), //input       clk,
        .rst_n       (  rstn_out   ), //input       rstn,
                                
        .init_over   (  init_over  ), //output      init_over,
        .iic_tx_scl  (  iic_tx_scl ), //output      iic_scl,
        .iic_tx_sda  (  iic_tx_sda ), //inout       iic_sda
        .iic_scl     (  iic_scl    ), //output      iic_scl,
        .iic_sda     (  iic_sda    )  //inout       iic_sda
    );

    assign  led_int  =  init_over; 




    reg [15:0]  rstn_1ms       ;
    always @(posedge clk_10m)
    begin
    	if(!rst_n)
    	    rstn_1ms <= 16'd0;
    	else
    	begin
    		if(rstn_1ms == 16'h2710)
    		    rstn_1ms <= rstn_1ms;
    		else
    		    rstn_1ms <= rstn_1ms + 1'b1;
    	end
    end
    
    assign rstn_out = (rstn_1ms == 16'h2710);





    wire    [DATA_WIDTH-1 : 0]    hdmi_data_in;
    assign  hdmi_data_in = {r_in[7:3], g_in[7:2], b_in[7:3]};








    ov5640_cdc #(
        .DATA_WIDTH(DATA_WIDTH),        ////////////////
        .DEVICE(DEVICE)
    )
    ov5640_cdc(
        .cam_clk(pixclk_in),
        .cam_rst(!rst_n),

        .s_data (hdmi_data_in)     , //////////////
        .s_valid(de_in)    ,
        .s_hsync(hs_in)    ,
        .s_vsync(vs_in)    ,

        .video_clk  (video_clk  ), 
        .video_rst  (video_rst  ),
        .video_data (video_data ),
        .video_valid(video_valid),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync) 
    );



endmodule
