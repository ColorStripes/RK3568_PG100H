// `include ".\YOLO_FPGA.srcs\sources_1\npu_top\config.v"
`include "config.v"
module npu_top # (
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
              //并行度//
    parameter CHA_PAR_IN  = `CHA_PAR_IN,                           //输入通道并行度
              CHA_PAR_OUT = `CHA_PAR_OUT,                           //输出通道并行度
              CONV_CHA_PAR_IN = `CONV_CHA_PAR_IN,                   //卷积并行度
              CONV_CHA_PAR_OUT = `CONV_CHA_PAR_OUT,
              //图片数据//
              MAX_IN_COL = `MAX_IN_COL,                          //输入的IMG的最大列数
              MAX_IN_ROW = `MAX_IN_ROW,                          //输入的IMG的最大行数
              MAX_OUT_COL = `MAX_OUT_COL,                         //输出的IMG的最大列数
              MAX_OUT_ROW = `MAX_OUT_ROW,                         //输出的IMG的最大行数
              COL_WIDTH = (MAX_IN_COL >= MAX_OUT_COL) ? $clog2(MAX_IN_COL) : $clog2(MAX_OUT_COL),
              ROW_WIDTH = (MAX_IN_ROW >= MAX_OUT_ROW) ? $clog2(MAX_IN_ROW) : $clog2(MAX_OUT_ROW),
              //图片通道//
              CHA_IMG_IN  = `CHA_IMG_IN,                          //输入的IMG的最大通道数
            //   CHA_IN_WIDTH = $clog2(CHA_IMG_IN),
              CHA_IMG_OUT = `CHA_IMG_OUT,                         //输出的IMG的最大通道数
            //   CHA_OUT_WIDTH = $clog2(CHA_IMG_OUT),
              //数据位宽//
              INT = `INT,                                   //每个数的位宽
              DATA_WIDTH_IN = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_WIDTH_OUT = CHA_PAR_OUT * INT,             //数据传输位宽    输入并行度 * INT8
              //权重参数//
            //   WEIGHT_NUM = `WEIGHT_NUM,     //weight的实际数量 ci * co 也就是weight的数量
            //   WEIGHT_NUM_WIDTH = $clog2(WEIGHT_NUM),
            //   WEIGHT_LEN = CHA_IMG_IN * CHA_IMG_OUT * 9 + (CHA_IMG_OUT / BIAS_NUM) * CHA_PAR_IN,      //每个行拼2个bias
              WEIGHT_LEN =  `WEIGHT_LEN,
              WEIGHT33_LEN = `WEIGHT33_LEN,   
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN),
              WEIGHT_SUM =  `WEIGHT_SUM,   
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //偏置位宽//
              BIAS_NUM = `BIAS_NUM ,                             //一行拼接的bias个数
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //尺度位宽//
              SCALE_WIDTH = `SCALE_WIDTH,                          //scale的位数     对于其他scale的位数就是小数位数
              //一行数据的最大字节数//
              MAX_IN_LEN  = `MAX_IN_LEN,                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_OUT_LEN = `MAX_OUT_LEN,                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //计算次数//
              MAX_IN_CALULATE_NUM = CHA_PAR_IN > CONV_CHA_PAR_IN ? (CHA_IMG_IN / CONV_CHA_PAR_IN) : (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = CHA_PAR_OUT > CONV_CHA_PAR_OUT ? (CHA_IMG_OUT / CONV_CHA_PAR_OUT) : (CHA_IMG_OUT / CHA_PAR_OUT),         //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),
              READ_DELAY = `READ_DELAY
)
(

    input                               clk,
    input                               rst,


    //REG的传输接口 （AXI_lite）
    input                               s_axi_awvalid,
    output                              s_axi_awready, 
    input [AXI_ADDR_WIDTH-1 : 0]        s_axi_awaddr,


    input                               s_axi_wvalid,
    output                              s_axi_wready, 
    input [AXI_DATA_WIDTH-1 : 0]        s_axi_wdata,
    input [AXI_DATA_WIDTH/8-1 : 0]      s_axi_wstrb,

    output                              s_axi_bvalid,
    input                               s_axi_bready,
    output  [1 : 0]                     s_axi_bresp,

    input                               s_axi_arvalid, 
    output                              s_axi_arready, 
    input  [AXI_ADDR_WIDTH-1 : 0]       s_axi_araddr,


    output                              s_axi_rvalid,
    input                               s_axi_rready, 
    output [AXI_DATA_WIDTH-1 : 0]       s_axi_rdata,
    output [1 : 0]                      s_axi_rresp,


    //in的输入
    input  [DATA_WIDTH_IN-1 : 0]   s_data_0      ,
    input                          s_valid_0     ,
    input                          s_last_0      ,
    output                         s_ready_0     , 

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_0  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_0   ,
    output                         s_cmd_valid_0 ,
    input                          s_cmd_ready_0 ,
    //1
    input  [DATA_WIDTH_IN-1 : 0]   s_data_1      ,
    input                          s_valid_1     ,
    input                          s_last_1      ,
    output                         s_ready_1     , 

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_1  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_1   ,
    output                         s_cmd_valid_1 ,
    input                          s_cmd_ready_1 ,

    //out的输出
    output [DATA_WIDTH_OUT-1 : 0]   out_m_data  ,
    output                          out_m_last  ,
    output                          out_m_valid ,
    input                           out_m_ready , 

    output [AXI_ADDR_WIDTH-1 : 0]   out_m_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]   out_m_cmd_len   ,
    output                          out_m_cmd_valid ,
    input                           out_m_cmd_ready ,

    output                          out_calculate_end         ,//////////////////
    input                           out_calculate_end_receive ,



    ///////////// 并行算子输入 /////////////////////////
    //in的输入  为para_conv_weight
    input  [DATA_WIDTH_IN-1 : 0]   s_data_2      ,
    input                          s_valid_2     ,
    input                          s_last_2      ,
    output                         s_ready_2     , 

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_2  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_2   ,
    output                         s_cmd_valid_2 ,
    input                          s_cmd_ready_2 ,



    //in的输入  为para_cat_0
    input  [DATA_WIDTH_IN-1 : 0]   s_data_3      ,
    input                          s_valid_3     ,
    input                          s_last_3      ,
    output                         s_ready_3     ,

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_3  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_3   ,
    output                         s_cmd_valid_3 ,
    input                          s_cmd_ready_3 ,


    //in的输入  为para_cat_1
    input  [DATA_WIDTH_IN-1 : 0]   s_data_4      ,
    input                          s_valid_4     ,
    input                          s_last_4      ,
    output                         s_ready_4     ,

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_4  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_4   ,
    output                         s_cmd_valid_4 ,
    input                          s_cmd_ready_4 

                                                      
);

    //reg 的单独写入口
    wire                        wen   ;
    wire [AXI_ADDR_WIDTH-1 : 0] waddr ;
    wire [AXI_DATA_WIDTH-1 : 0] wdata ;
    //地址接口
    wire [AXI_DATA_WIDTH-1 : 0]  s_addr_0 ;            //特征图数据输入地址
    wire [AXI_DATA_WIDTH-1 : 0]  s_addr_1 ;            //特征图数据输入地址
    wire [AXI_DATA_WIDTH-1 : 0]  m_addr   ;            //计算完成特征图数据输入地址
    wire [AXI_DATA_WIDTH-1 : 0]  weight_addr;          //权重地址
    //起始信号 (5个模块)
    wire [6 : 0]            start    ;
    //类型寄存器 （7个类型）
    wire [7 : 0]            type     ;
    //步长信号
    wire                    stride   ;
    //relu
    wire                    relu     ;
    //列数、行数寄存器
    wire [COL_WIDTH : 0]    col_num  ;
    wire [ROW_WIDTH : 0]    row_num  ;

    //计算次数寄存器
    wire [CALULATE_CNT_WIDTH : 0]     calculate_num     ;
    wire [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num ;
    wire [OUT_CALULATE_CNT_WIDTH : 0] calculate_cout_num;
    //计算结束寄存器
    wire                              reset     ;
    //输入输出字节计数器
    wire [IN_LEN_WIDTH : 0]           in_col_channel_num  ; //col_channel_num = col * channel
    wire [OUT_LEN_WIDTH : 0]          out_col_channel_num ; //col_channel_num = col * channel
    //scale和zero_point
    wire [SCALE_WIDTH-1 : 0]          scale_1;
    wire [SCALE_WIDTH-1 : 0]          scale_2;
    wire [SCALE_WIDTH*2-1 : 0]        scale_3;      //concat  //    input  [SCALE_WIDTH-1 : 0]  scale_3      //  conv
    wire [INT-1 : 0]                  zero_1 ;
    wire [INT-1 : 0]                  zero_2 ;
    wire [INT-1 : 0]                  zero_3 ;
    //weight
    wire  [WEIGHT_LEN_WIDTH : 0]  weight_len ;
    wire  [WEIGHT_SUM_WIDTH : 0]  weight_sum ;
    //wire  [WEIGHT_NUM_WIDTH : 0]  weight_num ; 

axi_lite_reg # (
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //REG
    .CHA_PAR_IN(CHA_PAR_IN),                          //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                        //输出通道并行度
    .CONV_CHA_PAR_IN (CONV_CHA_PAR_IN ),                  //卷积并行度
    .CONV_CHA_PAR_OUT(CONV_CHA_PAR_OUT),
    //图片数据//
    .MAX_IN_COL(MAX_IN_COL),                          //输入的IMG的最大列数
    .MAX_IN_ROW(MAX_IN_ROW),                          //输入的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(CHA_IMG_IN),                          //输入的IMG的最大通道数
    .CHA_IMG_OUT(CHA_IMG_OUT),                        //输出的IMG的最大通道数
    //尺度，zero，data数据位宽
    .INT(INT),
    .SCALE_WIDTH(SCALE_WIDTH),     
    //偏置参数//
    .BIAS_NUM(BIAS_NUM) ,                             //一行拼接的bias个数   
    //weight参数
    // .WEIGHT_NUM(WEIGHT_NUM),
    .WEIGHT_LEN(WEIGHT_LEN),
    //DMA传输字节数
    .MAX_IN_LEN(MAX_IN_LEN),                       //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    .MAX_OUT_LEN(MAX_OUT_LEN)                      //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度

)
axi_lite_reg_inst(
    .clk(clk),
    .rst(rst),

    // Advanced extensible Interface
    .s_axi_awvalid  (s_axi_awvalid),
    .s_axi_awready  (s_axi_awready), 
    .s_axi_awaddr   (s_axi_awaddr ),


    .s_axi_wvalid   (s_axi_wvalid),
    .s_axi_wready   (s_axi_wready), 
    .s_axi_wdata    (s_axi_wdata ),
    .s_axi_wstrb    (s_axi_wstrb ),

    .s_axi_bvalid   (s_axi_bvalid),
    .s_axi_bready   (s_axi_bready),
    .s_axi_bresp    (s_axi_bresp ),

    .s_axi_arvalid  (s_axi_arvalid), 
    .s_axi_arready  (s_axi_arready), 
    .s_axi_araddr   (s_axi_araddr ),


    .s_axi_rvalid   (s_axi_rvalid),
    .s_axi_rready   (s_axi_rready), 
    .s_axi_rdata    (s_axi_rdata ),
    .s_axi_rresp    (s_axi_rresp ),


    ////////////////////REG相关////////////////////////////
    //单独写入接口
    .wen  (wen  ),
    .waddr(waddr),
    .wdata(wdata),
    //输入输出地址
    .s_addr_0   (s_addr_0   ),            //特征图数据输入地址
    .s_addr_1   (s_addr_1   ),            //特征图数据输入地址
    .m_addr     (m_addr     ),            //计算完成特征图数据输入地址
    .weight_addr(weight_addr),          //权重地址
    //起始信号 (5个模块)
    .start (start)   ,
    //类型寄存器 （7个类型）
    .type  (type)   ,
    //步长信号
    .stride (stride)  ,
    //relu
    .relu(relu),
    //列数、行数寄存器
    .col_num (col_num) ,
    .row_num (row_num) ,
    //计算次数寄存器
    .calculate_num     (calculate_num     ),
    .calculate_cin_num (calculate_cin_num ),
    .calculate_cout_num(calculate_cout_num),
    //计算结束寄存器
    .calculate_end(reset)     ,
//    //通道数寄存器 // 
//    .channel_in_num (channel_in_num )   ,
//    .channel_out_num(channel_out_num)   ,
    //输入输出字节计数器
    .in_col_channel_num (in_col_channel_num ) , //col_channel_num = col * channel
    .out_col_channel_num(out_col_channel_num) , //col_channel_num = col * channel
    //scale和zero_point
    .scale_1(scale_1),
    .scale_2(scale_2),
    .scale_3(scale_3),      //concat  //    input  [SCALE_WIDTH-1 : 0]  scale_3      //  conv
    .zero_1 (zero_1 ),
    .zero_2 (zero_2 ),
    .zero_3 (zero_3 ),
    //weight
    .weight_len (weight_len ) ,
    .weight_sum (weight_sum )     

);

///////////////////////////////////////////////////////////////////
    // wire [5 : 0] start_11111;
    // assign start[5 : 0] = start_11111[5 : 0];
    // assign start[0] = start_11111[0] & type[0];
    // assign start[5] = start_11111[0] & type[1];


    //用于算子的瞬时start
    reg [6 : 0] start_d;
    always @(posedge clk) begin
        if(rst) begin
            start_d <= 7'd0;
        end
        else begin
            start_d <= start;
        end
    end
///////////////////////////////////////////////////////////////////

    wire [DATA_WIDTH_IN-1 : 0]   in_conv_data      ;
    wire                         in_conv_valid     ;
    wire                         in_conv_last      ;
    wire                         in_conv_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  in_conv_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  in_conv_cmd_len   ;
    wire                         in_conv_cmd_valid ;
    wire                         in_conv_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]   para_conv_s_data     ;
    wire                         para_conv_s_valid    ;
    wire                         para_conv_s_last     ;
    wire                         para_conv_s_ready    ;
 
    wire [AXI_ADDR_WIDTH-1 : 0]  para_conv_s_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0]  para_conv_s_cmd_len  ;
    wire                         para_conv_s_cmd_valid;
    wire                         para_conv_s_cmd_ready;
in_conv_switch #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                                //输入通道并行度
    .INT(INT)     
)
in_conv_switch(
    .clk(clk)              ,
    .rst(rst)              ,

    .start_para((start[5] | start[6])) ,


    .s_data_0 (s_data_0 )  ,
    .s_valid_0(s_valid_0)  ,
    .s_last_0 (s_last_0 )  ,
    .s_ready_0(s_ready_0)  , 

    //命令接口
    .s_cmd_addr_0 (s_cmd_addr_0 ) ,
    .s_cmd_len_0  (s_cmd_len_0  ) ,
    .s_cmd_valid_0(s_cmd_valid_0) ,
    .s_cmd_ready_0(s_cmd_ready_0) ,



///////////////////////////////////////////
    .conv_m_data     (para_conv_s_data ) ,
    .conv_m_valid    (para_conv_s_valid) ,
    .conv_m_last     (para_conv_s_last ) ,
    .conv_m_ready    (para_conv_s_ready) ,

    .conv_m_cmd_addr (para_conv_s_cmd_addr ) ,
    .conv_m_cmd_len  (para_conv_s_cmd_len  ) ,
    .conv_m_cmd_valid(para_conv_s_cmd_valid) ,
    .conv_m_cmd_ready(para_conv_s_cmd_ready) ,


    .m_data (in_conv_data )     ,
    .m_valid(in_conv_valid)     ,
    .m_last (in_conv_last )     ,
    .m_ready(in_conv_ready)     ,

    .m_cmd_addr (in_conv_cmd_addr ) ,
    .m_cmd_len  (in_conv_cmd_len  ) ,
    .m_cmd_valid(in_conv_cmd_valid) ,
    .m_cmd_ready(in_conv_cmd_ready)  


);



////////////////////////////////////////////////////////////
    wire [DATA_WIDTH_IN-1 : 0]   conv_weight1_data      ;
    wire                         conv_weight1_valid     ;
    wire                         conv_weight1_last      ;
    wire                         conv_weight1_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  conv_weight1_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  conv_weight1_cmd_len   ;
    wire                         conv_weight1_cmd_valid ;
    wire                         conv_weight1_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]   conv_weight2_data      ;
    wire                         conv_weight2_valid     ;
    wire                         conv_weight2_last      ;
    wire                         conv_weight2_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  conv_weight2_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  conv_weight2_cmd_len   ;
    wire                         conv_weight2_cmd_valid ;
    wire                         conv_weight2_cmd_ready ;




    assign conv_weight1_data  = s_data_2 ;
    assign conv_weight1_valid = s_valid_2;
    assign conv_weight1_last  = s_last_2 ;
    assign s_ready_2 = conv_weight1_ready;

    assign s_cmd_addr_2  = conv_weight1_cmd_addr ;
    assign s_cmd_len_2   = conv_weight1_cmd_len  ;
    assign s_cmd_valid_2 = conv_weight1_cmd_valid;
    assign conv_weight1_cmd_ready = s_cmd_ready_2;


    //conv_para的输出
    wire [DATA_WIDTH_IN-1 : 0]    para_conv_m_data  ;
    wire                          para_conv_m_last  ;
    wire                          para_conv_m_valid ;
    wire                          para_conv_m_ready ; 


    wire [AXI_ADDR_WIDTH-1 : 0] para_conv_m_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0] para_conv_m_cmd_len  ;
    wire                        para_conv_m_cmd_valid;
    wire                        para_conv_m_cmd_ready;

    wire                        para_conv_calculate_end        ;
    wire                        para_conv_calculate_end_receive;

conv11_para_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN (`CONV_CHA_PAR_IN),                           //输入通道并行度
    .CHA_PAR_OUT(`CONV11_CHA_PAR_OUT),                           //输出通道并行度          //修改为16
    //图片数据//
    .MAX_IN_COL(`CONV_MAX_IN_COL),                          //输入的IMG的最大列数
    .MAX_IN_ROW(`CONV_MAX_IN_ROW),                          //输入的IMG的最大行数
    .MAX_OUT_COL(`CONV_MAX_OUT_COL),                         //输出的IMG的最大列数
    .MAX_OUT_ROW(`CONV_MAX_OUT_ROW),                         //输出的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`CONV_CHA_IMG_IN),                          //输入的IMG的最大通道数
    .CHA_IMG_OUT(`CONV_CHA_IMG_OUT),                         //输出的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                   //每个数的位宽
    //weight数据
    //.WEIGHT_NUM(`CONV_WEIGHT_NUM),
    .WEIGHT_LEN(`CONV_WEIGHT_LEN),
    .WEIGHT33_LEN(`CONV_WEIGHT33_LEN),
    .WEIGHT_SUM(`CONV_WEIGHT_SUM),
    //偏置位宽//
    .BIAS_NUM(`CONV_BIAS_NUM) ,                             //一行拼接的bias个数
    //尺度位宽//
    .SCALE_WIDTH(`CONV_SCALE_WIDTH),                          //scale的小数位数
    //一行数据的最大字节数//
    .MAX_IN_LEN(`CONV_MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    .MAX_OUT_LEN(`CONV11_MAX_OUT_LEN),                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
    //conv的乘法器延迟  
    .MUL_DELAY(`CONV_MUL_DELAY)                                                    
)
conv_para_top_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .type(type[1])            ,                   //1 is 1*1 ; 0 is 3*3
    .start((start[5] & !start_d[5]) || (start[6] & !start_d[6]))          ,
    .stride(stride)           ,
    .en_relu(relu)            ,
    

    .col_num(col_num)          , //col_num = col
    .row_num(row_num)          ,

    .calculate_num(calculate_num)              ,
    .calculate_cin_num(calculate_cin_num)      ,
    .calculate_cout_num(calculate_cout_num)    ,
    

    .scale_3(scale_3[SCALE_WIDTH-1 : 0]),
    .zero_1(zero_1)            ,
    .zero_3(zero_3)            ,

    
    .in_col_channel_num(in_col_channel_num)  , //col_channel_num = col * channel
    .s_addr(s_addr_0)      ,            //特征图数据输入地址

    .s_data (para_conv_s_data )     ,
    .s_valid(para_conv_s_valid)     ,
    .s_last (para_conv_s_last )     ,
    .s_ready(para_conv_s_ready)     ,

    //in_buf的命令接口
    .s_cmd_addr (para_conv_s_cmd_addr ) ,
    .s_cmd_len  (para_conv_s_cmd_len  ) ,
    .s_cmd_valid(para_conv_s_cmd_valid) ,
    .s_cmd_ready(para_conv_s_cmd_ready) ,


    .weight_addr(weight_addr)   ,       //权重地址
    .weight_len (weight_len)    ,
    .weight_sum (weight_sum)    ,
    // .bias_len   (bias_len)      ,

    .weight       (conv_weight1_data )  ,
    .weight_valid (conv_weight1_valid)  ,
    .weight_last  (conv_weight1_last )  ,
    .weight_ready (conv_weight1_ready)  ,

    //weight_bias的命令接口
    .weight_cmd_addr  (conv_weight1_cmd_addr ),
    .weight_cmd_len   (conv_weight1_cmd_len  ),
    .weight_cmd_valid (conv_weight1_cmd_valid),
    .weight_cmd_ready (conv_weight1_cmd_ready),




    .out_col_channel_num(out_col_channel_num)    ,
    .m_addr(m_addr)         ,

    .m_data  (para_conv_m_data )    ,
    .m_valid (para_conv_m_valid)    ,
    .m_last  (para_conv_m_last )    ,
    .m_ready (para_conv_m_ready)    ,


    .m_cmd_addr (para_conv_m_cmd_addr )  ,
    .m_cmd_len  (para_conv_m_cmd_len  )  ,
    .m_cmd_valid(para_conv_m_cmd_valid)  ,
    .m_cmd_ready(para_conv_m_cmd_ready)  ,


    .calculate_end        (para_conv_calculate_end        )  ,
    .calculate_end_receive(para_conv_calculate_end_receive)



);


    //conv16_para的输出
    wire [DATA_WIDTH_IN-1 : 0]    para_conv16_m_data  ;
    wire                          para_conv16_m_last  ;
    wire                          para_conv16_m_valid ;
    wire                          para_conv16_m_ready ; 


    wire [AXI_ADDR_WIDTH-1 : 0] para_conv16_m_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0] para_conv16_m_cmd_len  ;
    wire                        para_conv16_m_cmd_valid;
    wire                        para_conv16_m_cmd_ready;


    wire [DATA_WIDTH_IN-1 : 0]   out_conv_data      ;
    wire                         out_conv_valid     ;
    wire                         out_conv_last      ;
    wire                         out_conv_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  out_conv_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  out_conv_cmd_len   ;
    wire                         out_conv_cmd_valid ;
    wire                         out_conv_cmd_ready ;

out_conv_switch #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_OUT(CHA_PAR_OUT),                              //输入通道并行度
    .INT(INT)                                               //每个数的位宽

)
out_conv_switch(
    .clk(clk)              ,
    .rst(rst)              ,

    .start_para(start[5]) ,


    .s_data (para_conv_m_data )  ,
    .s_valid(para_conv_m_valid)  ,
    .s_last (para_conv_m_last )  ,
    .s_ready(para_conv_m_ready)  , 

    //命令接口
    .s_cmd_addr (para_conv_m_cmd_addr ) ,
    .s_cmd_len  (para_conv_m_cmd_len  ) ,
    .s_cmd_valid(para_conv_m_cmd_valid) ,
    .s_cmd_ready(para_conv_m_cmd_ready) ,



///////////////////////////////////////////
    .conv_m_data     (para_conv16_m_data ) ,
    .conv_m_valid    (para_conv16_m_valid) ,
    .conv_m_last     (para_conv16_m_last ) ,
    .conv_m_ready    (para_conv16_m_ready) ,

    .conv_m_cmd_addr (para_conv16_m_cmd_addr ) ,
    .conv_m_cmd_len  (para_conv16_m_cmd_len  ) ,
    .conv_m_cmd_valid(para_conv16_m_cmd_valid) ,
    .conv_m_cmd_ready(para_conv16_m_cmd_ready) ,


    .m_data (out_conv_data )     ,
    .m_valid(out_conv_valid)     ,
    .m_last (out_conv_last )     ,
    .m_ready(out_conv_ready)     ,

    .m_cmd_addr (out_conv_cmd_addr ) ,
    .m_cmd_len  (out_conv_cmd_len  ) ,
    .m_cmd_valid(out_conv_cmd_valid) ,
    .m_cmd_ready(out_conv_cmd_ready)  


);



wire [DATA_WIDTH_IN-1 : 0]   in_data_data      ;
wire                         in_data_valid     ;
wire                         in_data_last      ;
wire                         in_data_ready     ;

wire [AXI_ADDR_WIDTH-1 : 0]  in_data_cmd_addr  ;
wire [AXI_DATA_WIDTH-1 : 0]  in_data_cmd_len   ;
wire                         in_data_cmd_valid ;
wire                         in_data_cmd_ready ;
in_data_switch #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                                //输入通道并行度
    .INT(INT)     
)
in_data_switch(
    .clk(clk),
    .rst(rst),


    .start_para(start[5])  ,

    .s_data (in_conv_data )     ,
    .s_valid(in_conv_valid)     ,
    .s_last (in_conv_last )     ,
    .s_ready(in_conv_ready)     ,

    .s_cmd_addr (in_conv_cmd_addr ) ,
    .s_cmd_len  (in_conv_cmd_len  ) ,
    .s_cmd_valid(in_conv_cmd_valid) ,
    .s_cmd_ready(in_conv_cmd_ready) ,

    .para_data (para_conv16_m_data )    ,
    .para_valid(para_conv16_m_valid)    ,
    .para_last (para_conv16_m_last )    ,
    .para_ready(para_conv16_m_ready)    ,

    .para_cmd_addr (para_conv16_m_cmd_addr )  ,
    .para_cmd_len  (para_conv16_m_cmd_len  )  ,
    .para_cmd_valid(para_conv16_m_cmd_valid)  ,
    .para_cmd_ready(para_conv16_m_cmd_ready)  ,



    //////////////////////////////////////////////////
    .m_data (in_data_data )     ,
    .m_valid(in_data_valid)     ,
    .m_last (in_data_last )     ,
    .m_ready(in_data_ready)     ,   

    .m_cmd_addr (in_data_cmd_addr ) ,
    .m_cmd_len  (in_data_cmd_len  ) ,
    .m_cmd_valid(in_data_cmd_valid) ,
    .m_cmd_ready(in_data_cmd_ready)  

);






    wire [DATA_WIDTH_IN-1 : 0]  conv_s_data      ;
    wire                        conv_s_valid     ;
    wire                        conv_s_last      ;
    wire                        conv_s_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  conv_s_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  conv_s_cmd_len   ;
    wire                         conv_s_cmd_valid ;
    wire                         conv_s_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]  conv_weight_data      ;
    wire                        conv_weight_valid     ;
    wire                        conv_weight_last      ;
    wire                        conv_weight_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  conv_weight_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]  conv_weight_cmd_len   ;
    wire                         conv_weight_cmd_valid ;
    wire                         conv_weight_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]   sppf_s_data      ;
    wire                         sppf_s_valid     ;
    wire                         sppf_s_last      ;
    wire                         sppf_s_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]   sppf_s_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]   sppf_s_cmd_len   ;
    wire                          sppf_s_cmd_valid ;
    wire                          sppf_s_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]   upsample_s_data      ;
    wire                         upsample_s_valid     ;
    wire                         upsample_s_last      ;
    wire                         upsample_s_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]   upsample_s_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]   upsample_s_cmd_len   ;
    wire                          upsample_s_cmd_valid ;
    wire                          upsample_s_cmd_ready ;


    wire [DATA_WIDTH_IN-1 : 0]   focus_s_data      ;
    wire                         focus_s_valid     ;
    wire                         focus_s_last      ;
    wire                         focus_s_ready     ;

    wire [AXI_ADDR_WIDTH-1 : 0]   focus_s_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]   focus_s_cmd_len   ;
    wire                          focus_s_cmd_valid ;
    wire                          focus_s_cmd_ready ;


in_switch_main #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                                //输入通道并行度
    .INT(INT)                                               //每个数的位宽
)
in_switch_main_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .start(start[4 : 0])   ,

    .s_data_0      (in_data_data )     ,
    .s_valid_0     (in_data_valid)     ,
    .s_last_0      (in_data_last )     ,
    .s_ready_0     (in_data_ready)     ,


    .s_cmd_addr_0  (in_data_cmd_addr ) ,
    .s_cmd_len_0   (in_data_cmd_len  ) ,
    .s_cmd_valid_0 (in_data_cmd_valid) ,
    .s_cmd_ready_0 (in_data_cmd_ready) ,


    .s_data_1      (s_data_1  ),
    .s_valid_1     (s_valid_1 ),
    .s_last_1      (s_last_1  ),
    .s_ready_1     (s_ready_1 ), 

    .s_cmd_addr_1  (s_cmd_addr_1),
    .s_cmd_len_1   (s_cmd_len_1 ),
    .s_cmd_valid_1 (s_cmd_valid_1),
    .s_cmd_ready_1 (s_cmd_ready_1),


///////////////////////////////////////////
    .conv_m_data  (conv_s_data )    ,
    .conv_m_valid (conv_s_valid)    ,
    .conv_m_last  (conv_s_last )    ,
    .conv_m_ready (conv_s_ready)    ,

    .conv_m_cmd_addr (conv_s_cmd_addr  ) ,
    .conv_m_cmd_len  (conv_s_cmd_len   ) ,
    .conv_m_cmd_valid(conv_s_cmd_valid ) ,
    .conv_m_cmd_ready(conv_s_cmd_ready ) ,

    .conv_weight_data (conv_weight_data )     ,
    .conv_weight_valid(conv_weight_valid)     ,
    .conv_weight_last (conv_weight_last )     ,
    .conv_weight_ready(conv_weight_ready)     ,

    .conv_weight_cmd_addr (conv_weight_cmd_addr ) ,
    .conv_weight_cmd_len  (conv_weight_cmd_len  ) ,
    .conv_weight_cmd_valid(conv_weight_cmd_valid) ,
    .conv_weight_cmd_ready(conv_weight_cmd_ready) ,

    // .cat_add_m_data_0  (cat_add_s_data_0  )   ,
    // .cat_add_m_valid_0 (cat_add_s_valid_0 )   ,
    // .cat_add_m_last_0  (cat_add_s_last_0  )   ,
    // .cat_add_m_ready_0 (cat_add_s_ready_0 )   ,

    // .cat_add_m_cmd_addr_0  (cat_add_s_cmd_addr_0 ),
    // .cat_add_m_cmd_len_0   (cat_add_s_cmd_len_0  ),
    // .cat_add_m_cmd_valid_0 (cat_add_s_cmd_valid_0),
    // .cat_add_m_cmd_ready_0 (cat_add_s_cmd_ready_0),


    // .cat_add_m_data_1  (cat_add_s_data_1  )    ,
    // .cat_add_m_valid_1 (cat_add_s_valid_1 )    ,
    // .cat_add_m_last_1  (cat_add_s_last_1  )    ,
    // .cat_add_m_ready_1 (cat_add_s_ready_1 )    ,

    // .cat_add_m_cmd_addr_1  (cat_add_s_cmd_addr_1 ),
    // .cat_add_m_cmd_len_1   (cat_add_s_cmd_len_1  ),
    // .cat_add_m_cmd_valid_1 (cat_add_s_cmd_valid_1),
    // .cat_add_m_cmd_ready_1 (cat_add_s_cmd_ready_1),


    .sppf_m_data  (sppf_s_data  )    ,
    .sppf_m_valid (sppf_s_valid )    ,
    .sppf_m_last  (sppf_s_last  )    ,
    .sppf_m_ready (sppf_s_ready )    ,

    .sppf_m_cmd_addr  (sppf_s_cmd_addr  ),
    .sppf_m_cmd_len   (sppf_s_cmd_len   ),
    .sppf_m_cmd_valid (sppf_s_cmd_valid ),
    .sppf_m_cmd_ready (sppf_s_cmd_ready ),


    .upsample_m_data  (upsample_s_data  )    ,
    .upsample_m_valid (upsample_s_valid )    ,
    .upsample_m_last  (upsample_s_last  )    ,
    .upsample_m_ready (upsample_s_ready )    ,

    .upsample_m_cmd_addr  (upsample_s_cmd_addr  ),
    .upsample_m_cmd_len   (upsample_s_cmd_len   ),
    .upsample_m_cmd_valid (upsample_s_cmd_valid ),
    .upsample_m_cmd_ready (upsample_s_cmd_ready ),


    .focus_m_data  (focus_s_data  )    ,
    .focus_m_valid (focus_s_valid )    ,
    .focus_m_last  (focus_s_last  )    ,
    .focus_m_ready (focus_s_ready )    ,

    .focus_m_cmd_addr  (focus_s_cmd_addr ),
    .focus_m_cmd_len   (focus_s_cmd_len  ),
    .focus_m_cmd_valid (focus_s_cmd_valid),
    .focus_m_cmd_ready (focus_s_cmd_ready)


);









///////////////////////////////////////主算子//////////////////////////////////////////////////////






    //conv的输出
    wire [`CONV_CHA_PAR_OUT*INT-1 : 0]   conv_m_data  ;
    wire                                 conv_m_last  ;
    wire                                 conv_m_valid ;
    wire                                 conv_m_req   ; 
conv_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN (`CONV_CHA_PAR_IN),                           //输入通道并行度
    .CHA_PAR_OUT(`CONV_CHA_PAR_OUT),                           //输出通道并行度
    //图片数据//
    .MAX_IN_COL(`CONV_MAX_IN_COL),                          //输入的IMG的最大列数
    .MAX_IN_ROW(`CONV_MAX_IN_ROW),                          //输入的IMG的最大行数
    .MAX_OUT_COL(`CONV_MAX_OUT_COL),                         //输出的IMG的最大列数
    .MAX_OUT_ROW(`CONV_MAX_OUT_ROW),                         //输出的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`CONV_CHA_IMG_IN),                          //输入的IMG的最大通道数
    .CHA_IMG_OUT(`CONV_CHA_IMG_OUT),                         //输出的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                   //每个数的位宽
    //weight数据
    //.WEIGHT_NUM(`CONV_WEIGHT_NUM),
    .WEIGHT_LEN(`CONV_WEIGHT_LEN),
    .WEIGHT33_LEN(`CONV_WEIGHT33_LEN),
    .WEIGHT_SUM(`CONV_WEIGHT_SUM),
    //偏置位宽//
    .BIAS_NUM(`CONV_BIAS_NUM) ,                             //一行拼接的bias个数
    //尺度位宽//
    .SCALE_WIDTH(`CONV_SCALE_WIDTH),                          //scale的小数位数
    //一行数据的最大字节数//
    .MAX_IN_LEN(`CONV33_MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    // .MAX_OUT_LEN(`CONV_MAX_OUT_LEN),                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
    //conv的乘法器延迟  
    .MUL_DELAY(`CONV_MUL_DELAY)                                                    
)
conv_top_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .type(type[1])            ,                   //1 is 1*1 ; 0 is 3*3
    .start(start[0] & !start_d[0])          ,
    .stride(stride)           ,
    .en_relu(relu)            ,
    

    .col_num(col_num)          , //col_num = col
    .row_num(row_num)          ,

    .calculate_num(calculate_num)         ,
    .calculate_cin_num(calculate_cin_num)     ,
    .calculate_cout_num(calculate_cout_num)    ,
    

    .scale_3(scale_3[SCALE_WIDTH-1 : 0]),
    .zero_1(zero_1)            ,
    .zero_3(zero_3)            ,

    
    .in_col_channel_num(in_col_channel_num)  , //col_channel_num = col * channel

    .s_addr(s_addr_0)      ,            //特征图数据输入地址
    .s_data (conv_s_data )     ,
    .s_valid(conv_s_valid)     ,
    .s_last (conv_s_last )     ,
    .s_ready(conv_s_ready)     ,

    //in_buf的命令接口
    .s_cmd_addr (conv_s_cmd_addr ) ,
    .s_cmd_len  (conv_s_cmd_len  ) ,
    .s_cmd_valid(conv_s_cmd_valid) ,
    .s_cmd_ready(conv_s_cmd_ready) , 


    .weight_addr(weight_addr)   ,       //权重地址
    .weight_len (weight_len)    ,
    .weight_sum (weight_sum)    ,

    .weight       (conv_weight_data )  ,
    .weight_valid (conv_weight_valid)  ,
    .weight_last  (conv_weight_last )  ,
    .weight_ready (conv_weight_ready)  ,

    //weight_bias的命令接口
    .weight_cmd_addr  (conv_weight_cmd_addr ),
    .weight_cmd_len   (conv_weight_cmd_len  ),
    .weight_cmd_valid (conv_weight_cmd_valid),
    .weight_cmd_ready (conv_weight_cmd_ready),


    .m_data  (conv_m_data )    ,
    .m_valid (conv_m_valid)    ,
    .m_last  (conv_m_last )    ,
    .m_req   (conv_m_req  )    


);






    wire [DATA_WIDTH_OUT-1 : 0]  sppf_m_data      ;
    wire                         sppf_m_valid     ;
    wire                         sppf_m_last      ;
    wire                         sppf_m_req       ;
sppf_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN(`SPPF_CHA_PAR_IN),                          //输入通道并行度
    .CHA_PAR_OUT(`SPPF_CHA_PAR_OUT),                        //输出通道并行度
    //图片数据//
    .MAX_IN_COL(`SPPF_MAX_IN_COL),                          //输入的IMG的最大列数
    .MAX_IN_ROW(`SPPF_MAX_IN_ROW),                          //输入的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`SPPF_CHA_IMG_IN),                          //输入的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                   //每个数的位宽
    //一行数据的最大字节数//
    .MAX_IN_LEN(`SPPF_MAX_IN_LEN)                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度

)
sppf_top_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .start  (start[2] & !start_d[2])     ,
    
    

    .col_num             (col_num             ),
    .row_num             (row_num             ),

    .calculate_cin_num (calculate_cin_num)     ,
    
    .in_col_channel_num (in_col_channel_num)  , //col_channel_num = col * channel

    .s_addr (s_addr_0)      ,            //特征图数据输入地址
    .s_data  (sppf_s_data )   ,
    .s_valid (sppf_s_valid)   ,
    .s_last  (sppf_s_last )   ,
    .s_ready (sppf_s_ready)   ,

    //in_buf的命令接口
    .s_cmd_addr  (sppf_s_cmd_addr ) ,
    .s_cmd_len   (sppf_s_cmd_len  ) ,
    .s_cmd_valid (sppf_s_cmd_valid) ,
    .s_cmd_ready (sppf_s_cmd_ready) ,
    
    .m_data  (sppf_m_data  )    ,
    .m_valid (sppf_m_valid )    ,
    .m_last  (sppf_m_last  )    ,
    .m_req   (sppf_m_req   )      

);




    wire [DATA_WIDTH_OUT-1 : 0]  upsample_m_data      ;
    wire                         upsample_m_valid     ;
    wire                         upsample_m_last      ;
    wire                         upsample_m_req       ;
upsample_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN(`UPSAMPLE_CHA_PAR_IN),                           //输入通道并行度
    //图片数据//
    .MAX_IN_ROW(`UPSAMPLE_MAX_IN_ROW),                          //输入的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`UPSAMPLE_CHA_IMG_IN),                          //输入的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                   //每个数的位宽
    //一行数据的最大字节数//
    .MAX_IN_LEN(`UPSAMPLE_MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    //读出数据所需要的延迟
    .READ_DELAY(`UPSAMPLE_READ_DELAY)                                                                           
)
upsample_top_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .start  (start[3] & !start_d[3])     ,

    .in_col_channel_num(in_col_channel_num )  , //col_channel_num = col * channel
    .row_num(row_num)          ,
    //输入通道计算次数
    .calculate_cin_num(calculate_cin_num),


    
    .s_addr  (s_addr_0)      ,            //特征图数据输入地址
    .s_data  (upsample_s_data )    ,
    .s_valid (upsample_s_valid)    ,
    .s_last  (upsample_s_last )    ,
    .s_ready (upsample_s_ready)    ,

    //in_buf的命令接口
    .s_cmd_addr (upsample_s_cmd_addr ) ,
    .s_cmd_len  (upsample_s_cmd_len  ) ,
    .s_cmd_valid(upsample_s_cmd_valid) ,
    .s_cmd_ready(upsample_s_cmd_ready) ,


    .m_data  (upsample_m_data )     ,
    .m_valid (upsample_m_valid)     ,
    .m_last  (upsample_m_last )     ,
    .m_req   (upsample_m_req  )     

);







    wire [DATA_WIDTH_OUT-1 : 0]  focus_m_data      ;
    wire                         focus_m_valid     ;
    wire                         focus_m_last      ;
    wire                         focus_m_req       ;
focus_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN(`FOCUS_CHA_PAR_IN),                        //输入通道并行度
    .CHA_PAR_OUT(`FOCUS_CHA_PAR_OUT),                      //输出通道并行度
    //图片数据//
    .MAX_IN_ROW(`FOCUS_MAX_IN_ROW),                        //输入的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`FOCUS_CHA_IMG_IN),                        //输入的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                             //每个数的位宽
    //一行数据的最大字节数//
    .MAX_IN_LEN(`FOCUS_MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    //读出数据所需要的延迟
    .READ_DELAY(`FOCUS_READ_DELAY)                                                                           
)
focus_top_inst(
    .clk (clk)             ,
    .rst (rst)             ,
    
    .start  (start[4] & !start_d[4])     ,

    .in_col_channel_num(in_col_channel_num  ), //col_channel_num = col * channel
    .row_num           (row_num             ),


    
    .s_addr  (s_addr_0)      ,            //特征图数据输入地址
    .s_data  (focus_s_data )    ,
    .s_valid (focus_s_valid)    ,
    .s_last  (focus_s_last )    ,
    .s_ready (focus_s_ready)    ,

    //in_buf的命令接口
    .s_cmd_addr (focus_s_cmd_addr ) ,
    .s_cmd_len  (focus_s_cmd_len  ) ,
    .s_cmd_valid(focus_s_cmd_valid) ,
    .s_cmd_ready(focus_s_cmd_ready) ,


    .m_data  (focus_m_data )     ,
    .m_valid (focus_m_valid)     ,
    .m_last  (focus_m_last )     ,
    .m_req   (focus_m_req  )     
);




    wire [DATA_WIDTH_OUT-1 : 0]   out_data   ;
    wire                          out_valid  ;
    wire                          out_last   ;
    wire                          out_req    ;
    out_switch #(
        .CHA_PAR_OUT(CHA_PAR_OUT),                             //输出通道并行度
        .INT(INT),                                             //每个数的位宽
        //conv
        .CONV_CHA_PAR_OUT(`CONV_CHA_PAR_OUT)
    )
    out_switch_inst(
        .clk(clk)              ,
        .rst(rst)              ,

        .start(start[4 : 0])            ,

        .conv_s_data (conv_m_data )     ,
        .conv_s_valid(conv_m_valid)     ,
        .conv_s_last (conv_m_last )     ,
        .conv_s_req  (conv_m_req  )     ,


        // .cat_add_s_data (cat_add_m_data )     ,
        // .cat_add_s_valid(cat_add_m_valid)     ,
        // .cat_add_s_last (cat_add_m_last )     ,
        // .cat_add_s_req  (cat_add_m_req  )     ,

        .sppf_s_data  (sppf_m_data  )     ,
        .sppf_s_valid (sppf_m_valid )     ,
        .sppf_s_last  (sppf_m_last  )     ,
        .sppf_s_req   (sppf_m_req   )     ,


        .upsample_s_data (upsample_m_data )     ,
        .upsample_s_valid(upsample_m_valid)     ,
        .upsample_s_last (upsample_m_last )     ,
        .upsample_s_req  (upsample_m_req  )     ,


        .focus_s_data (focus_m_data )     ,
        .focus_s_valid(focus_m_valid)     ,
        .focus_s_last (focus_m_last )     ,
        .focus_s_req  (focus_m_req  )     ,


        .s_data  (out_data )  ,
        .s_valid (out_valid)  ,
        .s_last  (out_last )  ,
        .s_req   (out_req  )    

    );

    reg  [DATA_WIDTH_OUT-1 : 0]   out_data_reg ;
    reg                           out_valid_reg;
    reg                           out_last_reg ;
    // reg                           out_req_reg  ;
    always @(posedge clk) begin
        out_data_reg  <= out_data ;
        out_valid_reg <= out_valid;
        out_last_reg  <= out_last ;
        // out_req_reg   <= out_req  ;
    end




    wire [DATA_WIDTH_OUT-1 : 0] out_buf_data ;
    wire                        out_buf_last ;
    wire                        out_buf_valid;
    wire                        out_buf_ready;

    wire [AXI_ADDR_WIDTH-1 : 0] out_buf_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0] out_buf_cmd_len  ;
    wire                        out_buf_cmd_valid;
    wire                        out_buf_cmd_ready;

    wire                        out_add_calculate_end          ;
    wire                        out_add_calculate_end_receive  ;
    //////////////////////////  conv_start ////////////////////
    wire conv_start = start[0];
    // wire out_buf_start = |(start[4 : 0] & ~start_d[4 : 0]);
    wire out_buf_start = (|(start[4 : 2] & ~start_d[4 : 2])) | (start[0] & ~start_d[0]);
    /////////////////////////////
    out_buf_top #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .CONV_CHA_PAR_OUT(`CONV_CHA_PAR_OUT),           //conv输出的并行度
        .CHA_PAR_OUT(CHA_PAR_OUT),                      //输出通道并行度
        .CHA_IMG_OUT(CHA_IMG_OUT),                      //图片输出最大通道数
        .MAX_OUT_LEN(5120),                      //此模块所输出的最大字节数  也就是输出一行*通道的字节数
        .MAX_OUT_ROW(MAX_OUT_ROW),                      //输出的IMG的最大行数
        .INT(INT),                                      //每个数的位宽
        .READ_DELAY(READ_DELAY)                         //读出数据所需要的延迟
    )
    out_buf_top_inst(
        .clk(clk)              ,
        .rst(rst)              ,

        .conv_start(conv_start)   ,
        .start(out_buf_start)     ,
        .type(type)               ,
        .stride(stride)           ,                    //0为1步长 1为2步长

        .m_addr(m_addr)                          ,
        .row_num(row_num)                        ,
        .out_col_channel_num(out_col_channel_num),     //out_col_channel_num = col * channel
        .calculate_cout_num(calculate_cout_num)  ,     //输出通道计算次数 



        .s_data   (out_data_reg ) ,
        .s_valid  (out_valid_reg) ,
        .s_last   (out_last_reg ) ,
        .s_req    (out_req      ) , 

        .m_data   (out_buf_data )   ,
        .m_last   (out_buf_last )   ,
        .m_valid  (out_buf_valid)   ,
        .m_ready  (out_buf_ready)   , 


        .cmd_addr (out_buf_cmd_addr ) ,
        .cmd_len  (out_buf_cmd_len  ) ,
        .cmd_valid(out_buf_cmd_valid) ,
        .cmd_ready(out_buf_cmd_ready) ,


        .calculate_end        (out_add_calculate_end        )   ,
        .calculate_end_receive(out_add_calculate_end_receive)
    );







    wire  [DATA_WIDTH_OUT-1 : 0] add_m_data     ;
    wire                         add_m_valid    ;
    wire                         add_m_last     ;
    wire                         add_m_ready    ;
 
    wire [AXI_ADDR_WIDTH-1 : 0]  add_m_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0]  add_m_cmd_len  ;
    wire                         add_m_cmd_valid;
    wire                         add_m_cmd_ready;




    wire  [DATA_WIDTH_OUT-1 : 0] out_add_m_data     ;
    wire                         out_add_m_valid    ;
    wire                         out_add_m_last     ;
    wire                         out_add_m_ready    ;
 
    wire [AXI_ADDR_WIDTH-1 : 0]  out_add_m_cmd_addr ;
    wire [AXI_DATA_WIDTH-1 : 0]  out_add_m_cmd_len  ;
    wire                         out_add_m_cmd_valid;
    wire                         out_add_m_cmd_ready;
    out_add_switch #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .CHA_PAR_OUT(CHA_PAR_OUT),                            //输入通道并行度
        .INT(INT)                                             //每个数的位宽
    )
    out_add_switch(
        .clk(clk)              ,
        .rst(rst)              ,

        .start_para(type[7]) ,


        .s_data (out_buf_data   )  ,
        .s_valid(out_buf_valid  )  ,
        .s_last (out_buf_last   )  ,
        .s_ready(out_buf_ready  )  , 

        //命令接口
        .s_cmd_addr (out_buf_cmd_addr ) ,
        .s_cmd_len  (out_buf_cmd_len  ) ,
        .s_cmd_valid(out_buf_cmd_valid) ,
        .s_cmd_ready(out_buf_cmd_ready) ,



    ///////////////////////////////////////////
        .add_m_data     (add_m_data ) ,
        .add_m_valid    (add_m_valid) ,
        .add_m_last     (add_m_last ) ,
        .add_m_ready    (add_m_ready) ,

        .add_m_cmd_addr (add_m_cmd_addr ) ,
        .add_m_cmd_len  (add_m_cmd_len  ) ,
        .add_m_cmd_valid(add_m_cmd_valid) ,
        .add_m_cmd_ready(add_m_cmd_ready) ,


        .m_data     (out_add_m_data )     ,
        .m_valid    (out_add_m_valid)     ,
        .m_last     (out_add_m_last )     ,
        .m_ready    (out_add_m_ready)     ,

        .m_cmd_addr (out_add_m_cmd_addr ) ,
        .m_cmd_len  (out_add_m_cmd_len  ) ,
        .m_cmd_valid(out_add_m_cmd_valid) ,
        .m_cmd_ready(out_add_m_cmd_ready) 


    );









    wire [DATA_WIDTH_IN-1 : 0]   cat_add_s_data_0      ;
    wire                         cat_add_s_valid_0     ;
    wire                         cat_add_s_last_0      ;
    wire                         cat_add_s_ready_0     ;

    wire [AXI_ADDR_WIDTH-1 : 0]  cat_add_s_cmd_addr_0  ;
    wire [AXI_DATA_WIDTH-1 : 0]  cat_add_s_cmd_len_0   ;
    wire                         cat_add_s_cmd_valid_0 ;
    wire                         cat_add_s_cmd_ready_0 ;


    wire [DATA_WIDTH_IN-1 : 0]    cat_add_s_data_1      ;
    wire                          cat_add_s_valid_1     ;
    wire                          cat_add_s_last_1      ;
    wire                          cat_add_s_ready_1     ;

    wire [AXI_ADDR_WIDTH-1 : 0]   cat_add_s_cmd_addr_1  ;
    wire [AXI_DATA_WIDTH-1 : 0]   cat_add_s_cmd_len_1   ;
    wire                          cat_add_s_cmd_valid_1 ;
    wire                          cat_add_s_cmd_ready_1 ;

    in_cat_switch #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .CHA_PAR_IN(CHA_PAR_IN),                   //输入通道并行度
        .INT(INT)                                  //每个数的位宽
    )
    in_cat_switch(
        .clk(clk),
        .rst(rst),


        .start_para(type[7])  ,

        .s_data (s_data_3 )     ,
        .s_valid(s_valid_3)     ,
        .s_last (s_last_3 )     ,
        .s_ready(s_ready_3)     ,

        .s_cmd_addr (s_cmd_addr_3 ) ,
        .s_cmd_len  (s_cmd_len_3  ) ,
        .s_cmd_valid(s_cmd_valid_3) ,
        .s_cmd_ready(s_cmd_ready_3) ,

        .para_data (add_m_data )     ,
        .para_valid(add_m_valid)     ,
        .para_last (add_m_last )     ,
        .para_ready(add_m_ready)     ,

        .para_cmd_addr (add_m_cmd_addr ) ,
        .para_cmd_len  (add_m_cmd_len  ) ,
        .para_cmd_valid(add_m_cmd_valid) ,
        .para_cmd_ready(add_m_cmd_ready) ,





        //////////////////////////////////////////////////
        .m_data (cat_add_s_data_0 )     ,
        .m_valid(cat_add_s_valid_0)     ,
        .m_last (cat_add_s_last_0 )     ,
        .m_ready(cat_add_s_ready_0)     ,   

        .m_cmd_addr (cat_add_s_cmd_addr_0 ) ,
        .m_cmd_len  (cat_add_s_cmd_len_0  ) ,
        .m_cmd_valid(cat_add_s_cmd_valid_0) ,
        .m_cmd_ready(cat_add_s_cmd_ready_0) 


    );




    wire [DATA_WIDTH_OUT-1 : 0]  cat_add_m_data         ;
    wire                         cat_add_m_valid        ;
    wire                         cat_add_m_last         ;
    wire                         cat_add_m_ready        ;

    wire [AXI_ADDR_WIDTH-1 : 0]  cat_add_m_cmd_addr     ;
    wire [AXI_DATA_WIDTH-1 : 0]  cat_add_m_cmd_len      ;
    wire                         cat_add_m_cmd_valid    ;
    wire                         cat_add_m_cmd_ready    ;

    wire                         cat_add_calculate_end          ;
    wire                         cat_add_calculate_end_receive  ;

cat_add_para_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    //并行度//
    .CHA_PAR_IN(`CAT_ADD_CHA_PAR_IN),                           //输入通道并行度
    //图片数据//
    .MAX_IN_ROW(`CAT_ADD_MAX_IN_ROW),                          //输入的IMG的最大行数
    //图片通道//
    .CHA_IMG_IN(`CAT_ADD_CHA_IMG_IN),                          //输入的IMG的最大通道数
    //数据位宽//
    .INT(INT),                                   //每个数的位宽
    //尺度位宽//
    .SCALE_WIDTH(`CAT_ADD_SCALE_WIDTH),                          //scale的位数
    .SCALE_FRACTION_WIDTH(`CAT_ADD_SCALE_FRACTION_WIDTH),        //scale的小数位数
    //一行数据的最大字节数//
    .MAX_IN_LEN(`CAT_ADD_MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
    //读出数据所需要的延迟
    .READ_DELAY(`CAT_ADD_READ_DELAY),                           
    //乘法器延迟 
    .MUL_DELAY(`CAT_ADD_MUL_DELAY)                                                     
)
cat_add_para_top(

    .clk (clk)             ,
    .rst (rst)             ,
    
    .start  (start[1] & !start_d[1])     ,

    .type   (type[3])      ,

    .in_col_channel_num(in_col_channel_num ), //col_channel_num = col * channel
    .out_col_channel_num(out_col_channel_num ), //col_channel_num = col * channel
    .row_num(row_num)          ,
    //输入通道计算次数
    .calculate_cin_num(calculate_cin_num),
    .calculate_cout_num(calculate_cout_num),

    .scale_1(scale_1),
    .scale_2(scale_2),
    .scale_3(scale_3),
    .zero_1(zero_1)        ,
    .zero_2(zero_2)        ,


    .s_addr_0  (s_addr_0) ,            //特征图数据输入地址
    .s_data_0  (cat_add_s_data_0 )    ,
    .s_valid_0 (cat_add_s_valid_0)    ,
    .s_last_0  (cat_add_s_last_0 )    ,
    .s_ready_0 (cat_add_s_ready_0)    ,
    
    .s_addr_1  (s_addr_1) ,            //特征图数据输入地址
    .s_data_1  (s_data_4 )    ,
    .s_valid_1 (s_valid_4)    ,
    .s_last_1  (s_last_4 )    ,
    .s_ready_1 (s_ready_4)    ,


    //in_buf的命令接口
    .s_cmd_addr_0 (cat_add_s_cmd_addr_0 ) ,
    .s_cmd_len_0  (cat_add_s_cmd_len_0  ) ,
    .s_cmd_valid_0(cat_add_s_cmd_valid_0) ,
    .s_cmd_ready_0(cat_add_s_cmd_ready_0) ,

    .s_cmd_addr_1 (s_cmd_addr_4 ),
    .s_cmd_len_1  (s_cmd_len_4  ),
    .s_cmd_valid_1(s_cmd_valid_4),
    .s_cmd_ready_1(s_cmd_ready_4),

    

    .m_addr(m_addr)      ,
    .m_data (cat_add_m_data )     ,
    .m_valid(cat_add_m_valid)     ,
    .m_last (cat_add_m_last )     ,
    .m_ready(cat_add_m_ready)     ,

    .m_cmd_addr (cat_add_m_cmd_addr )    ,
    .m_cmd_len  (cat_add_m_cmd_len  )    ,
    .m_cmd_valid(cat_add_m_cmd_valid)    ,
    .m_cmd_ready(cat_add_m_cmd_ready)    ,



    .calculate_end        (cat_add_calculate_end        ) ,
    .calculate_end_receive(cat_add_calculate_end_receive) 


);







    out_data_switch #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .CHA_PAR_OUT(CHA_PAR_OUT),                 //输入通道并行度
        .INT(INT)                                  //每个数的位宽
    )
    out_data_switch(
        .clk(clk),
        .rst(rst),


        .start_para({start[6], start[1]})  ,

        .s_data (out_add_m_data )     ,
        .s_valid(out_add_m_valid)     ,
        .s_last (out_add_m_last )     ,
        .s_ready(out_add_m_ready)     ,

        .s_cmd_addr (out_add_m_cmd_addr ) ,
        .s_cmd_len  (out_add_m_cmd_len  ) ,
        .s_cmd_valid(out_add_m_cmd_valid) ,
        .s_cmd_ready(out_add_m_cmd_ready) ,

        .s_calculate_end        (out_add_calculate_end        ) ,
        .s_calculate_end_receive(out_add_calculate_end_receive) , 

        .para1_data (cat_add_m_data )     ,
        .para1_valid(cat_add_m_valid)     ,
        .para1_last (cat_add_m_last )     ,
        .para1_ready(cat_add_m_ready)     ,

        .para1_cmd_addr (cat_add_m_cmd_addr ) ,
        .para1_cmd_len  (cat_add_m_cmd_len  ) ,
        .para1_cmd_valid(cat_add_m_cmd_valid) ,
        .para1_cmd_ready(cat_add_m_cmd_ready) ,

        .para1_calculate_end        (cat_add_calculate_end        ) ,
        .para1_calculate_end_receive(cat_add_calculate_end_receive) , 


        .para2_data (out_conv_data )     ,
        .para2_valid(out_conv_valid)     ,
        .para2_last (out_conv_last )     ,
        .para2_ready(out_conv_ready)     ,

        .para2_cmd_addr (out_conv_cmd_addr ) ,
        .para2_cmd_len  (out_conv_cmd_len  ) ,
        .para2_cmd_valid(out_conv_cmd_valid) ,
        .para2_cmd_ready(out_conv_cmd_ready) ,

        .para2_calculate_end        (para_conv_calculate_end        ) ,
        .para2_calculate_end_receive(para_conv_calculate_end_receive) ,


        //////////////////////////////////////////////////
        .m_data (out_m_data )     ,
        .m_valid(out_m_valid)     ,
        .m_last (out_m_last )     ,
        .m_ready(out_m_ready)     ,   

        .m_cmd_addr (out_m_cmd_addr ) ,
        .m_cmd_len  (out_m_cmd_len  ) ,
        .m_cmd_valid(out_m_cmd_valid) ,
        .m_cmd_ready(out_m_cmd_ready) ,


        .m_calculate_end        (out_calculate_end        )  ,
        .m_calculate_end_receive(out_calculate_end_receive)


    );







    //清空start操作
    // reg out_calculate_end_d;
    // always @(posedge clk) begin
    //     out_calculate_end_d <= out_calculate_end;
    // end
    assign wen = out_calculate_end & out_calculate_end_receive;
    assign waddr = 32'h0000_0005;
    assign wdata = 32'h0000_0000;

endmodule