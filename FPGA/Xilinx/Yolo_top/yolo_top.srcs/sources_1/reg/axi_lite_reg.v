module axi_lite_reg # (
    parameter AXI_DATA_WIDTH    = 32,
    parameter AXI_ADDR_WIDTH    = 32,
    //REG
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              CONV_CHA_PAR_IN = 16,                      //卷积输入通道并行度
              CONV_CHA_PAR_OUT = 4,                      //卷积输出通道并行度
              //图片数据//
              MAX_IN_COL = 320,                          //输入的IMG的最大列数
              COL_WIDTH = $clog2(MAX_IN_COL),
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              //图片通道//
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
            //   CHA_IN_WIDTH = $clog2(CHA_IMG_IN),
              CHA_IMG_OUT = 256,                         //输出的IMG的最大通道数
            //   CHA_OUT_WIDTH = $clog2(CHA_IMG_OUT),
              //计算次数//
              MAX_IN_CALULATE_NUM = CHA_PAR_IN > CONV_CHA_PAR_IN ? (CHA_IMG_IN / CONV_CHA_PAR_IN) : (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = CHA_PAR_OUT > CONV_CHA_PAR_OUT ? (CHA_IMG_OUT / CONV_CHA_PAR_OUT) : (CHA_IMG_OUT / CHA_PAR_OUT),         //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),
              //尺度，zero，data数据位宽
              INT = 8,
              SCALE_WIDTH = 16,  
              //偏置参数//
              BIAS_NUM = 2 ,                             //一行拼接的bias个数   
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //DMA传输字节数
              MAX_IN_LEN = 10240,                       //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_OUT_LEN = 5120,                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //权重参数//
            //   WEIGHT_NUM = CHA_IMG_IN * CHA_IMG_OUT,     //weight的实际数量 ci * co 也就是weight的数量
            //   WEIGHT_NUM_WIDTH = $clog2(WEIGHT_NUM),
              //ci*co*9是weight总字节数 一个bias是128位的也就是16字节数，所以加上co*16，但bias只有32位是有效的  
              WEIGHT_SUM = CHA_IMG_IN * CHA_IMG_OUT * 9 + CHA_IMG_OUT * 16,  //每次取一小部分weight
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //一个weight点的字节数
              WEIGHT_LEN = CHA_IMG_IN * CHA_IMG_OUT,  
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN)


)(
    input                               clk,
    input                               rst,

    // Advanced extensible Interface
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


    ////////////////////REG相关////////////////////////////
    //单独写入通道
	input                             wen,
    input [AXI_ADDR_WIDTH-1:0]      waddr,
    input [AXI_DATA_WIDTH-1:0]      wdata,

    //输入输出地址
    output [AXI_DATA_WIDTH-1 : 0]  s_addr_0 ,            //特征图数据输入地址
    output [AXI_DATA_WIDTH-1 : 0]  s_addr_1 ,            //特征图数据输入地址
    output [AXI_DATA_WIDTH-1 : 0]  m_addr   ,            //计算完成特征图数据输入地址
    output [AXI_DATA_WIDTH-1 : 0]  weight_addr,          //权重地址
    //起始信号 (5个模块)
    output [6 : 0]            start    ,
    //类型寄存器 （7个类型）
    output [7 : 0]            type     ,
    //步长信号
    output                    stride   ,
    //RELU
    output                    relu     ,
    //列数、行数寄存器
    output [COL_WIDTH : 0]    col_num  ,
    output [ROW_WIDTH : 0]    row_num  ,
    //计算次数寄存器
    output [CALULATE_CNT_WIDTH : 0]     calculate_num     ,
    output [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num ,
    output [OUT_CALULATE_CNT_WIDTH : 0] calculate_cout_num,
    //计算结束寄存器
    output                              calculate_end     ,
    //输入输出字节计数器
    output [IN_LEN_WIDTH : 0]           in_col_channel_num  , //col_channel_num = col * channel
    output [OUT_LEN_WIDTH : 0]          out_col_channel_num , //col_channel_num = col * channel
    //scale和zero_point
    output [SCALE_WIDTH-1 : 0]          scale_1,
    output [SCALE_WIDTH-1 : 0]          scale_2,
    output [SCALE_WIDTH*2-1 : 0]        scale_3,      //concat  //    input  [SCALE_WIDTH-1 : 0]  scale_3      //  conv
    output [INT-1 : 0]                  zero_1 ,
    output [INT-1 : 0]                  zero_2 ,
    output [INT-1 : 0]                  zero_3 ,
    //weight
    output [WEIGHT_LEN_WIDTH : 0]  weight_len  ,
    output [WEIGHT_SUM_WIDTH : 0]  weight_sum      

);




	wire                             axi_wen;   
    wire [AXI_ADDR_WIDTH-1:0]      axi_waddr;     
    wire [AXI_DATA_WIDTH-1:0]      axi_wdata;   

    axi_lite_interdace # (
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)

    )
    axi_lite_interdace_inst(
        .clk(clk),
        .rst(rst),   

        .wen(axi_wen)   ,
        .waddr(axi_waddr) ,
        .wdata(axi_wdata) ,


        // Advanced extensible Interface
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready), 
        .s_axi_awaddr (s_axi_awaddr),


        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready), 
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),

        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),
        .s_axi_bresp  (s_axi_bresp),

        .s_axi_arvalid(s_axi_arvalid), 
        .s_axi_arready(s_axi_arready), 
        .s_axi_araddr (s_axi_araddr),


        .s_axi_rvalid (s_axi_rvalid),//read data
        .s_axi_rready (s_axi_rready), 
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp)

    );





	reg                           reg_wen;
    reg [AXI_ADDR_WIDTH-1:0]      reg_waddr;
    reg [AXI_DATA_WIDTH-1:0]      reg_wdata;


    always @(posedge clk) begin
        if(rst) begin
            reg_wen <= 1'b0;
        end
        else begin
            reg_wen <= wen | axi_wen;
        end
    end

    always @(posedge clk) begin
        if(wen) begin
            reg_waddr <= waddr;
        end
        else if(axi_wen) begin
            reg_waddr <= axi_waddr;
        end
    end

    always @(posedge clk) begin
        if(wen) begin
            reg_wdata <= wdata;
        end
        else if(axi_wen) begin
            reg_wdata <= axi_wdata;
        end
    end



    calculate_reg #(
        //并行度
        .CHA_PAR_IN(CHA_PAR_IN),                           //输入通道并行度
        .CHA_PAR_OUT(CHA_PAR_OUT),                           //输出通道并行度
        .CONV_CHA_PAR_IN (CONV_CHA_PAR_IN ),                  //卷积并行度
        .CONV_CHA_PAR_OUT(CONV_CHA_PAR_OUT),
        //图片数据//
        .MAX_IN_COL(MAX_IN_COL),                          //输入的IMG的最大列数
        .MAX_IN_ROW(MAX_IN_ROW),                          //输入的IMG的最大行数
        //图片通道//
        .CHA_IMG_IN(CHA_IMG_IN),                          //输入的IMG的最大通道数
        .CHA_IMG_OUT(CHA_IMG_OUT),                         //输出的IMG的最大通道数
        //尺度，zero，data数据位宽
        .INT(INT),
        .SCALE_WIDTH(SCALE_WIDTH),    
        //偏置参数//
        .BIAS_NUM(BIAS_NUM) ,                             //一行拼接的bias个数 
        //weight参数
        // .WEIGHT_NUM(WEIGHT_NUM),
        .WEIGHT_LEN(WEIGHT_LEN),
        .WEIGHT_SUM(WEIGHT_SUM),
        //DMA传输字节数
        .MAX_IN_LEN(MAX_IN_LEN),                       //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
        .MAX_OUT_LEN(MAX_OUT_LEN),                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
        //AXI相关
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)

    )
    reg_inst (
        .clk(clk),
        .rst(rst),

        .wen(reg_wen)   ,
        .waddr(reg_waddr) ,
        .wdata(reg_wdata) ,

        //输入输出地址
        .s_addr_0(s_addr_0) ,            //特征图数据输入地址
        .s_addr_1(s_addr_1) ,            //特征图数据输入地址
        .m_addr(m_addr)   ,            //计算完成特征图数据输入地址
        .weight_addr(weight_addr),
        //起始信号 (4个模块)
        .start(start)    ,
        //类型寄存器 （6个类型）
        .type(type)     ,
        //步长信号
        .stride(stride)   ,
        //relu
        .relu(relu),
        //列数、行数寄存器
        .col_num(col_num)  ,
        .row_num(row_num)  ,
        //计算次数寄存器
        .calculate_num(calculate_num)     ,
        .calculate_cin_num(calculate_cin_num) ,
        .calculate_cout_num(calculate_cout_num),
        //计算结束寄存器
        .calculate_end(calculate_end)     ,
        // //通道数寄存器 // 
        // .channel_in_num(channel_in_num)    ,
        // .channel_out_num(channel_out_num)   ,
        //输入输出字节计数器
        .in_col_channel_num(in_col_channel_num)  , //col_channel_num = col * channel
        .out_col_channel_num(out_col_channel_num) , //col_channel_num = col * channel
        //scale和zero_point
        .scale_1(scale_1),
        .scale_2(scale_2),
        .scale_3(scale_3),      //concat  //    input  [SCALE_WIDTH-1 : 0]  scale_3      //  conv
        .zero_1(zero_1) ,
        .zero_2(zero_2) ,
        .zero_3(zero_3) ,
        //weight
        .weight_len(weight_len)  ,
        .weight_sum(weight_sum)    

    );





    

endmodule