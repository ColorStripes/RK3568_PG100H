module conv_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
              //并行度//
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              //图片数据//
              MAX_IN_COL = 320,                          //输入的IMG的最大列数
              COL_WIDTH = $clog2(MAX_IN_COL),
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              MAX_OUT_COL = 320,                         //输出的IMG的最大列数
              MAX_OUT_ROW = 320,                         //输出的IMG的最大行数
              //图片通道//
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
            //   CHA_IN_WIDTH = $clog2(CHA_IMG_IN),
              CHA_IMG_OUT = 256,                         //输出的IMG的最大通道数
            //   CHA_OUT_WIDTH = $clog2(CHA_IMG_OUT),
              //数据位宽//
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH_IN = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_WIDTH_OUT = CHA_PAR_OUT * INT,             //数据传输位宽    输入并行度 * INT8
              CALULATE_DATA_WIDTH = 2*INT + 4 + $clog2(CHA_PAR_IN),    //conv 和 add的传输位宽
              //权重参数//
              WEIGHT_SUM = 296960,  //每次取一小部分weight
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //一个weight点的字节数
              WEIGHT_LEN = 131072,  //每次取一小部分weight
              WEIGHT33_LEN = 32768,
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN),
              //偏置位宽//
              BIAS_NUM = 1 ,                             //一行拼接的bias个数
              BIAS_WIDTH = 32 * BIAS_NUM,                //偏置的位宽
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //尺度位宽//
              SCALE_WIDTH = 16,                          //scale的小数位数
              //一行数据的最大字节数//
              MAX_IN_LEN = 10240,                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
            //   MAX_OUT_LEN = 5120,                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
            //   OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //计算次数//
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),             //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),
              MUL_DELAY = 4                                                   //conv的乘法器延迟    
)
(
    input          clk              ,
    input          rst              ,
    
    input          type             ,                   //1 is 1*1 ; 0 is 3*3
    input          start            ,
    input          stride           ,
    input          en_relu          ,
    

    input  [COL_WIDTH : 0]   col_num          , //col_num = col
    input  [ROW_WIDTH : 0]   row_num          ,

    input  [CALULATE_CNT_WIDTH : 0]      calculate_num         ,
    input  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num     ,
    input  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num    ,
    

    input  [SCALE_WIDTH-1 : 0]  scale_3            ,
    input  [INT-1 : 0]          zero_1             ,
    input  [INT-1 : 0]          zero_3             ,


    input  [AXI_DATA_WIDTH-1 : 0]  s_addr              ,            //特征图数据输入地址
    input  [IN_LEN_WIDTH : 0]      in_col_channel_num  , //col_channel_num = col * channel
    input  [DATA_WIDTH_IN-1 : 0]   s_data      ,
    input                          s_valid     ,
    input                          s_last      ,
    output                         s_ready     ,


    input  [AXI_DATA_WIDTH-1 : 0]  weight_addr  ,       //权重地址
    input  [WEIGHT_LEN_WIDTH : 0]  weight_len   ,
    input  [WEIGHT_SUM_WIDTH : 0]  weight_sum   ,
    input  [DATA_WIDTH_IN-1 : 0]   weight           ,
    input                          weight_valid     ,
    input                          weight_last      ,
    output                         weight_ready     ,





    //in_buf的命令接口
    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len   ,
    output                         s_cmd_valid ,
    input                          s_cmd_ready ,
    
    //weight_bias的命令接口
    output [AXI_ADDR_WIDTH-1 : 0]  weight_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  weight_cmd_len   ,
    output                         weight_cmd_valid ,
    input                          weight_cmd_ready ,




    output [DATA_WIDTH_OUT-1 : 0]  m_data      ,
    output                         m_valid     ,
    output                         m_last      ,
    input                          m_req       

);

///////////////////////////////////////// 计算所需数据的算子级别寄存器 /////////////////////////////////

    reg                                type_reg              ;
    reg                                start_reg             ;
    reg                                stride_reg            ;
    reg                                en_relu_reg           ;
    reg  [COL_WIDTH : 0]               col_num_reg           ;
    reg  [ROW_WIDTH : 0]               row_num_reg           ;
    reg  [CALULATE_CNT_WIDTH : 0]      calculate_num_reg     ;
    reg  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num_reg ;
    reg  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num_reg;
    reg  [SCALE_WIDTH-1 : 0]           scale_3_reg           ;
    reg  [INT-1 : 0]                   zero_1_reg            ;
    reg  [INT-1 : 0]                   zero_3_reg            ;
    reg  [AXI_DATA_WIDTH-1 : 0]        s_addr_reg            ;
    reg  [IN_LEN_WIDTH : 0]            in_col_channel_num_reg;
    reg  [AXI_DATA_WIDTH-1 : 0]        weight_addr_reg       ;
    reg  [WEIGHT_LEN_WIDTH : 0]        weight_len_reg        ;
    reg  [WEIGHT_SUM_WIDTH : 0]        weight_sum_reg        ;
    always @(posedge clk) begin
        if(start) begin
            type_reg                <= type              ;
            stride_reg              <= stride            ;
            en_relu_reg             <= en_relu           ;
            col_num_reg             <= col_num           ;
            row_num_reg             <= row_num           ;
            calculate_num_reg       <= calculate_num     ;
            calculate_cin_num_reg   <= calculate_cin_num ;
            calculate_cout_num_reg  <= calculate_cout_num;
            scale_3_reg             <= scale_3           ;
            zero_1_reg              <= zero_1            ;
            zero_3_reg              <= zero_3            ;
            s_addr_reg              <= s_addr            ;
            in_col_channel_num_reg  <= in_col_channel_num;
            weight_addr_reg         <= weight_addr       ;
            weight_len_reg          <= weight_len        ;
            weight_sum_reg          <= weight_sum        ;
        end
        start_reg               <= start             ;
    end


//////////////////////////////////////////  整体卷积控制模块  ///////////////////////////////////////////////////

////////当前模块的output/////////
//各请求信号
wire                       in_ctrl_m_valid   ;
wire                       in_ctrl_m_last    ;

wire                       weight_m_valid     ;
wire                       weight_m_last      ;

// wire mul_last;
wire add_last;

// wire calculate_req;

//传入in_ctrl
wire in_ctrl_m_req;
//传入weight
wire weight_m_req;
//传入weight
wire bias_req;
//传入add
wire calculate_first ;
wire calculate_last  ;

//传入weight
wire calculate_end;

conv_ctrl #(
    .CHA_PAR_IN(CHA_PAR_IN),                          //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                        //输出通道并行度
    .MAX_IN_ROW(MAX_IN_ROW),                          //输入的IMG的最大行数
    .CHA_IMG_IN(CHA_IMG_IN),                          //输入的IMG的最大通道数
    .CHA_IMG_OUT(CHA_IMG_OUT),                        //输出的IMG的最大通道数 
    .MUL_DELAY(MUL_DELAY)                             //conv的乘法器延迟          
)
ctrl(
    .clk(clk)         ,
    .rst(rst)         ,
    .type(type_reg)             ,
    .start(start_reg)           ,
    .stride(stride_reg)         ,

    //from DMA
    .row_num(row_num_reg)                       ,
    .calculate_num(calculate_num_reg)           ,
    .calculate_cin_num(calculate_cin_num_reg)   ,      //输入计算次数 


    //from in_ctrl
    .data_valid(in_ctrl_m_valid)   ,
    .data_last(in_ctrl_m_last)     ,
    //to in_ctrl
    .data_req(in_ctrl_m_req)       ,               //向conv33_in_ctrl请求三行数据

    //from weight
    .weight_valid(weight_m_valid) ,
    .weight_last(weight_m_last)   ,
    //to weight
    .weight_req(weight_m_req)     ,

    //from weight
    .bias_valid(bias_valid) ,
    .bias_last(bias_last)   ,
    //to weight
    .bias_req(bias_req)     ,

    //from out_buf
    .calculate_req(m_req)   ,            //说明计算模块可以接受新的计算数据 请求给数据
    //to add
    .calculate_first(calculate_first)  ,
    .calculate_last(calculate_last)    ,

    
    
    
    // .mul_last(mul_last),      /////////////////  mul计算最后一组了  
    .add_last(add_last),         //bias使用完毕      

    .calculate_end(calculate_end)
);



//////////////////////////////////////////  输入buf  ///////////////////////////////////////////////////
//各信号输入
wire in_buf_m_req;
//当前模块的output
//传入in_ctrl
wire [DATA_WIDTH_IN-1 : 0] in_buf_m_data      ;
wire                       in_buf_m_valid     ;
wire                       in_buf_m_last      ;
conv_in_buf_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                  //输入通道并行度
    .MAX_IN_LEN(MAX_IN_LEN),                  //此模块所接受的最大字节数  也就是一行*通道的字节数
    .MAX_IN_ROW(MAX_IN_ROW),                  //输入的IMG的最大行数
    .INT(INT),                                //每个数的位宽
    .READ_DELAY(1)                            //读出数据所需要的延迟
              
)
in_buf(
    .clk(clk)              ,
    .rst(rst)              ,
    .start(start_reg)            ,

    //from DMA
    .base_addr(s_addr_reg)           ,
    .in_col_channel_num(in_col_channel_num_reg) , //col_num = col * channel
    .row_num(row_num_reg)            ,

    //from DMA
    .s_data(s_data)      ,
    .s_valid(s_valid)    ,
    .s_last(s_last)      ,
    .s_ready(s_ready)    ,
    
    //to in_ctrl
    .m_req   (in_buf_m_req)     ,
    .m_data  (in_buf_m_data)    ,
    .m_valid (in_buf_m_valid)   ,
    .m_last  (in_buf_m_last)    ,
    
    //传给DMA命令接口
    .cmd_addr(s_cmd_addr)        ,
    .cmd_len(s_cmd_len)          ,
    .cmd_valid(s_cmd_valid)      ,
    .cmd_ready(s_cmd_ready) 
);



//////////////////////////////////////////  计算所需数据  ///////////////////////////////////////////////////

////////当前模块的output/////////
//传入conv
wire [DATA_WIDTH_IN-1 : 0] in_ctrl_m_data_0  ;
wire [DATA_WIDTH_IN-1 : 0] in_ctrl_m_data_1  ;
wire [DATA_WIDTH_IN-1 : 0] in_ctrl_m_data_2  ;
//wire                       in_ctrl_m_valid   ;
//wire                       in_ctrl_m_last    ;
conv_in_ctrl #(
    .CHA_PAR_IN(CHA_PAR_IN),                          //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                        //输出通道并行度
    .MAX_IN_COL(MAX_IN_COL),                          //输入的IMG的最大列数
    .MAX_IN_ROW(MAX_IN_ROW),                          //输入的IMG的最大行数
    .CHA_IMG_IN(CHA_IMG_IN),                          //输入的IMG的最大通道数
    .CHA_IMG_OUT(CHA_IMG_OUT),                        //输出的IMG的最大通道数
    .MAX_IN_LEN(MAX_IN_LEN),                          //此模块所接受的最大字节数
    .INT(INT),                                        //每个数的位宽
    .READ_DELAY(1)
)
in_ctrl(
    .clk(clk)             ,
    .rst(rst)             ,
    .start(start_reg)         ,

    //from DMA
    .stride(stride_reg)         ,
    .zero_1(zero_1_reg)           ,
    .col_num(col_num_reg)       ,   //col_num = col
    .row_num(row_num_reg)       ,
    .calculate_cin_num (calculate_cin_num_reg ),
    .calculate_cout_num(calculate_cout_num_reg),

    //from in_buf
    .s_data  (in_buf_m_data)  , 
    .s_valid (in_buf_m_valid) ,
    .s_last  (in_buf_m_last)  ,
    //to in_buf
    .s_req   (in_buf_m_req)   ,

    //to conv
    .m_data_0(in_ctrl_m_data_0)        ,  //下一级模块的请求
    .m_data_1(in_ctrl_m_data_1)        ,
    .m_data_2(in_ctrl_m_data_2)        ,
    .m_valid(in_ctrl_m_valid)          ,
    .m_last (in_ctrl_m_last)           ,
    //to ctrl
    .m_req  (in_ctrl_m_req)          
);



////////当前模块的output//////
//传入conv
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_0    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_1    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_2    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_3    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_4    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_5    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_6    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_7    ;
wire [DATA_WIDTH_IN-1 : 0] weight_m_data_8    ;
// wire                       weight_m_valid     ;
// wire                       weight_m_last      ;
//传入add
wire [BIAS_WIDTH-1 : 0]  bias   ;
wire                     bias_valid  ;
wire                     bias_last   ;

conv_weight #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                          //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                        //输出通道并行度
    .CHA_IMG_IN(CHA_IMG_IN),
    .CHA_IMG_OUT(CHA_IMG_OUT),                        //输出的IMG的最大通道数
    .WEIGHT_LEN(WEIGHT_LEN),  						  //每次取一小部分weight
    .WEIGHT33_LEN(WEIGHT33_LEN),
    .WEIGHT_SUM(WEIGHT_SUM),  						  //每次取一小部分weight
    .INT(INT),                                        //每个数的位宽
    .BIAS_NUM(BIAS_NUM),                              //一行拼接的bias个数
    .MAX_IN_COL(MAX_IN_COL),
    .MAX_IN_ROW(MAX_IN_ROW),
    .READ_DELAY(1)
)
weight_bias(
    .clk(clk)         ,
    .rst(rst)         ,
    .type(type_reg)       ,
    .start(start_reg)     ,
    .stride(stride_reg)   ,

    .base_addr(weight_addr_reg),              //写内存的起始基地址
    .weight_sum(weight_sum_reg),			  //weight文件总字节数 包括bias  
    // .weight_len(weight_len_reg),              //1个weight点对应的字节数 CHA_IMG_IN * CHA_IMG_OUT 
    .bias_len(weight_len_reg),              //1个weight点对应的字节数 CHA_IMG_IN * CHA_IMG_OUT 


    .row_num(row_num_reg),

    .calculate_num(calculate_num_reg),                  //总计算次数
    .calculate_cout_num(calculate_cout_num_reg),        //通道数计算次数 并行度必须是2的整倍数
    // .channel_out_num(channel_out_num),    //有多少输出通道
    

    //from DMA
    .s_data(weight)       ,
    .s_valid(weight_valid),
    .s_last(weight_last)  ,
    .s_ready(weight_ready),

    
    //to conv
    .m_data_0(weight_m_data_0)    ,
    .m_data_1(weight_m_data_1)    ,
    .m_data_2(weight_m_data_2)    ,
    .m_data_3(weight_m_data_3)    ,
    .m_data_4(weight_m_data_4)    ,
    .m_data_5(weight_m_data_5)    ,
    .m_data_6(weight_m_data_6)    ,
    .m_data_7(weight_m_data_7)    ,
    .m_data_8(weight_m_data_8)    ,
    .m_valid(weight_m_valid)      ,
    .m_last (weight_m_last)       ,
    .m_req  (weight_m_req)        ,


    //to add (bias)
    .bias(bias)             ,
    .bias_valid(bias_valid) ,
    .bias_last(bias_last)   ,
    .bias_req(bias_req)     ,

    //from DMA
    .cmd_addr(weight_cmd_addr)     ,
    .cmd_len(weight_cmd_len)       ,
    .cmd_valid(weight_cmd_valid)   ,
    .cmd_ready(weight_cmd_ready)   ,

    .calculate_end(calculate_end)

);








/////////////////////////////////////////////  计算   ///////////////////////////////////////////////////////


////////当前模块的output//////
//传入ctrl
//wire mul_last;
//传入add
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_0    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_1    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_2    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_3    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_4    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_5    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_6    ;
// wire [2*INT+3+$clog2(CHA_PAR_IN) : 0]  conv_m_data_7    ;
wire [CHA_PAR_OUT * CALULATE_DATA_WIDTH-1  : 0]  conv_m_data    ;
wire                                   conv_m_valid     ;
wire                                   conv_m_last      ;

conv_conv #(
    .CHA_PAR_IN(CHA_PAR_IN),                    //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                  //输出通道并行度
    .INT(INT),                                  //每个数的位宽
    .MUL_DELAY(MUL_DELAY)                       //conv的乘法器延迟 
)
conv(
    .clk(clk)         ,
    .rst(rst)         ,

    .type(type_reg)       ,
    .start(start_reg)     ,

    //from weight
    .weight_0(weight_m_data_0)    ,
    .weight_1(weight_m_data_1)    ,
    .weight_2(weight_m_data_2)    ,
    .weight_3(weight_m_data_3)    ,
    .weight_4(weight_m_data_4)    ,
    .weight_5(weight_m_data_5)    ,
    .weight_6(weight_m_data_6)    ,
    .weight_7(weight_m_data_7)    ,
    .weight_8(weight_m_data_8)    ,
    .weight_valid(weight_m_valid) ,
    .weight_last(weight_m_last)   ,

    //from in_ctrl
    .s_data_0(in_ctrl_m_data_0)      ,
    .s_data_1(in_ctrl_m_data_1)      ,
    .s_data_2(in_ctrl_m_data_2)      ,
    .s_valid(in_ctrl_m_valid)   ,
    .s_last (in_ctrl_m_last)    ,

    //to add
    // .m_data_0(conv_m_data_0)    ,
    // .m_data_1(conv_m_data_1)    ,
    // .m_data_2(conv_m_data_2)    ,
    // .m_data_3(conv_m_data_3)    ,
    // .m_data_4(conv_m_data_4)    ,
    // .m_data_5(conv_m_data_5)    ,
    // .m_data_6(conv_m_data_6)    ,
    // .m_data_7(conv_m_data_7)    ,
    .m_data(conv_m_data)    ,
    .m_valid(conv_m_valid)  ,
    .m_last(conv_m_last)        

    // .mul_last(mul_last)      
);




////////当前模块的output//////
//传入out_buf
// wire [INT-1 : 0]  add_m_data_0    ;
// wire [INT-1 : 0]  add_m_data_1    ;
// wire [INT-1 : 0]  add_m_data_2    ;
// wire [INT-1 : 0]  add_m_data_3    ;
// wire [INT-1 : 0]  add_m_data_4    ;
// wire [INT-1 : 0]  add_m_data_5    ;
// wire [INT-1 : 0]  add_m_data_6    ;
// wire [INT-1 : 0]  add_m_data_7    ;
// wire [DATA_WIDTH_OUT-1 : 0]  add_m_data ;
// wire              add_m_valid     ;
// wire              add_m_last      ;

conv_add #(
    .CHA_PAR_IN(CHA_PAR_IN),                     //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),                   //输出通道并行度
    .MAX_OUT_COL(MAX_OUT_COL),                   //输出的IMG的最大列数
    .CHA_IMG_IN(CHA_IMG_IN),                     //输入的IMG的最大通道数
    .INT(INT),                                   //每个数的位宽
    .BIAS_NUM(BIAS_NUM),                         //一行拼接的bias个数
    .BIAS_WIDTH(BIAS_WIDTH),                     //偏置的位宽
    .SCALE_WIDTH(SCALE_WIDTH),                   //scale的小数位数
    .READ_DELAY(1),                              
    .MUL_DELAY(4)                                //scale乘法器延迟

)
add(
    .clk(clk)         ,
    .rst(rst)         ,
    .start(start_reg)       ,
    .stride(stride_reg)     ,

    //from DMA
    .scale_3(scale_3_reg)   ,
    .zero_3(zero_3_reg)    ,

    //from ctrl
    .calculate_first(calculate_first)  ,
    .calculate_last (calculate_last)   ,

    //from weight
    .bias(bias)             ,
    .bias_valid(bias_valid) ,
    .bias_last(bias_last)   ,

    //from conv
    // .s_data_0(conv_m_data_0)    ,
    // .s_data_1(conv_m_data_1)    ,
    // .s_data_2(conv_m_data_2)    ,
    // .s_data_3(conv_m_data_3)    ,
    // .s_data_4(conv_m_data_4)    ,
    // .s_data_5(conv_m_data_5)    ,
    // .s_data_6(conv_m_data_6)    ,
    // .s_data_7(conv_m_data_7)    ,
    .s_data(conv_m_data)    ,
    .s_valid(conv_m_valid)      ,
    .s_last(conv_m_last)        ,

    //to out_buf
    // .m_data_0(add_m_data_0) ,
    // .m_data_1(add_m_data_1) ,
    // .m_data_2(add_m_data_2) ,
    // .m_data_3(add_m_data_3) ,
    // .m_data_4(add_m_data_4) ,
    // .m_data_5(add_m_data_5) ,
    // .m_data_6(add_m_data_6) ,
    // .m_data_7(add_m_data_7) ,
    .m_data(m_data) ,
    .m_valid(m_valid)   ,
    .m_last(m_last) ,

    .en_relu(en_relu_reg)  ,
    .add_last(add_last)          //bias使用完毕  
);












































endmodule