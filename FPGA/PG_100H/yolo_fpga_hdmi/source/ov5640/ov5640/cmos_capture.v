//DVP接收
module cmos_capture #(
    parameter DATA_WIDTH = 16,
              DELAY = DATA_WIDTH/8
)(
    input                 rst_n            ,  //复位信号    
    //摄像头接口                           
    input                 cam_pclk         ,  //cmos 数据像素时钟
    input                 cam_vsync        ,  //cmos 场同步信号
    input                 cam_href         ,  //cmos 行同步信号
    input  [7:0]          cam_data         ,                      
    //用户接口                              
    output                      cmos_frame_vsync ,  //帧有效信号    
    output                      cmos_frame_href  ,  //行有效信号
    output                      cmos_frame_valid ,  //8bit转16bit数据有效使能信号
    output  [DATA_WIDTH-1 : 0]  cmos_frame_data     //有效数据        
);


    wire            pos_vsync        ; 

    //寄存器全部配置完成后，先等待10帧数据
    //待寄存器配置生效后再开始采集图像
    parameter  WAIT_FRAME = 4'd10    ;            //寄存器数据稳定等待的帧个数 
    
    //对帧数进行计数
    reg    [3:0]    cmos_ps_cnt      ;            //等待帧数稳定计数器
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n)
            cmos_ps_cnt <= 4'd0;
        else if(pos_vsync && (cmos_ps_cnt < WAIT_FRAME))
            cmos_ps_cnt <= cmos_ps_cnt + 4'd1;
    end

    //帧有效标志
    reg             frame_val_flag   ;            //帧有效的标志 
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n)
            frame_val_flag <= 1'b0;
        else if((cmos_ps_cnt == WAIT_FRAME) && pos_vsync)
            frame_val_flag <= 1'b1;
        else;    
    end 

    
    //*****************************************************
    //**                    main code
    //*****************************************************
    /////////////////拼接延迟///////////
    reg [DELAY-1 : 0] cam_vsync_d, cam_href_d;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_vsync_d <= 1'b0;
            cam_href_d  <= 1'b0;
        end
        else begin
            cam_vsync_d <= {cam_vsync_d[DELAY-2 : 0], cam_vsync}; 
            cam_href_d  <= {cam_href_d[DELAY-2 : 0] , cam_href}; 
        end
    end

    reg cam_href_up;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_href_up <= 1'b0;
        end
        else begin
            cam_href_up <= cam_href_d[DELAY-1];
        end
    end








    reg    [DATA_WIDTH-1 : 0]   cmos_data_t      ;            //用于8位转DATA_WIDTH位的临时寄存器
    //8位数据转16位RGB565数据        
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cmos_data_t <= {DATA_WIDTH{1'b0}};
        end
        else if(cam_href && (temp_cnt == DATA_WIDTH/8 - 1)) begin
            cmos_data_t <= {cam_data_temp[DATA_WIDTH-1-8 : 0], cam_data};
        end
    end

    reg [DATA_WIDTH-1-8 : 0] cam_data_temp;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_data_temp <= {DATA_WIDTH-8{1'b0}};
        end
        else if(cam_href) begin
            cam_data_temp <= (cam_data_temp << 8) | cam_data;
        end
        else begin
            cam_data_temp <= {DATA_WIDTH-8{1'b0}};
        end
    end

    reg [1 : 0] temp_cnt;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            temp_cnt <= 2'd0;
        end      
        else if(cam_href) begin
            if(temp_cnt == DATA_WIDTH/8 - 1) begin
                temp_cnt <= 2'd0;
            end
            else begin
                temp_cnt <= temp_cnt + 1'b1;
            end
        end
        else begin
            temp_cnt <= 2'd0;
        end
    end


    reg valid_flag;
    //产生输出数据有效信号(cmos_frame_valid)
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            valid_flag <= 1'b0;
        end
        else if(cam_href && (temp_cnt == DATA_WIDTH/8 - 1)) begin
            valid_flag <= 1'b1;
        end	
        else begin
            valid_flag <= 1'b0;
        end
    end 


    //采输入场同步信号的上升沿           
    assign pos_vsync = (~cam_vsync_d[DELAY-1]) & cam_vsync_d[DELAY-1-1]; 

    //输出帧有效信号
    assign  cmos_frame_vsync = frame_val_flag  ?  cam_vsync_d[DELAY-1]  :  1'b0; 

    //输出行有效信号
    // assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d[DELAY-1] & (~cam_href_up) :  1'b0; 
    assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d[DELAY-1] :  1'b0; 


    //输出数据使能有效信号
    assign  cmos_frame_valid = frame_val_flag  ?  valid_flag  :  1'b0; 

    //输出数据
    assign  cmos_frame_data  = frame_val_flag  ?  cmos_data_t  :  1'b0; 




endmodule