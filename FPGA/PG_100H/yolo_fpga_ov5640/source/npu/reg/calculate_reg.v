//2025.6.8
//`include ".\YOLO_FPGA.srcs\sources_1\reg\defines.v"
`include "defines.v"
module calculate_reg #(
              //并行度
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
              //DMA传输字节数
              MAX_IN_LEN = 10240,                       //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_OUT_LEN = 5120,                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),              
              //偏置参数//
              BIAS_NUM = 2 ,                             //一行拼接的bias个数
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //权重参数//
            //   WEIGHT_NUM = CHA_IMG_IN * CHA_IMG_OUT,     //weight的实际数量 ci * co 也就是weight的数量
            //   WEIGHT_NUM_WIDTH = $clog2(WEIGHT_NUM),
              //ci*co*9是weight总字节数 一个bias是128位的也就是16字节数，所以加上co*16，但bias只有32位是有效的  
              WEIGHT_SUM = CHA_IMG_IN * CHA_IMG_OUT * 9 + CHA_IMG_OUT * 16,  //每次取一小部分weight
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //一个weight点的字节数
              WEIGHT_LEN = CHA_IMG_IN * CHA_IMG_OUT,  
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN),
              //AXI相关
              AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32
) 
(
    input clk,
    input rst,

    input                        wen   ,
    input [AXI_ADDR_WIDTH-1 : 0] waddr ,
    input [AXI_DATA_WIDTH-1 : 0] wdata ,

    //输入输出地址
    output reg [AXI_DATA_WIDTH-1 : 0]  s_addr_0 ,            //特征图数据输入地址
    output reg [AXI_DATA_WIDTH-1 : 0]  s_addr_1 ,            //特征图数据输入地址
    output reg [AXI_DATA_WIDTH-1 : 0]  m_addr   ,            //计算完成特征图数据输入地址
    output reg [AXI_DATA_WIDTH-1 : 0]  weight_addr,          //权重地址
    //起始信号 (5个模块)
    output reg [6 : 0]            start    ,
    //类型寄存器 （7个类型）
    output reg [7 : 0]            type     ,
    //步长信号
    output reg                    stride   ,
    //RELU
    output reg                    relu     ,
    //列数、行数寄存器
    output reg [COL_WIDTH : 0]    col_num  ,
    output reg [ROW_WIDTH : 0]    row_num  ,
    //计算次数寄存器
    output reg [CALULATE_CNT_WIDTH : 0]     calculate_num     ,
    output reg [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num ,
    output reg [OUT_CALULATE_CNT_WIDTH : 0] calculate_cout_num,
    //计算结束寄存器
    output reg                              calculate_end     ,
    // //通道数寄存器 // 
    // output reg [CHA_IN_WIDTH : 0]           channel_in_num    ,
    // output reg [CHA_OUT_WIDTH : 0]          channel_out_num   ,
    //输入输出字节计数器
    output reg [IN_LEN_WIDTH : 0]           in_col_channel_num  , //col_channel_num = col * channel
    output reg [OUT_LEN_WIDTH : 0]          out_col_channel_num , //col_channel_num = col * channel
    //scale和zero_point
    output reg [SCALE_WIDTH-1 : 0]          scale_1,
    output reg [SCALE_WIDTH-1 : 0]          scale_2,
    output reg [SCALE_WIDTH*2-1 : 0]        scale_3,      //concat  //    input  [SCALE_WIDTH-1 : 0]  scale_3      //  conv
    output reg [INT-1 : 0]                  zero_1 ,
    output reg [INT-1 : 0]                  zero_2 ,
    output reg [INT-1 : 0]                  zero_3 ,
    //weight
    output reg [WEIGHT_LEN_WIDTH : 0]  weight_len  ,
    output reg [WEIGHT_SUM_WIDTH : 0]  weight_sum      


);

    




    always @(posedge clk) begin
        if(rst) begin
            //地址信息
            s_addr_0 <= 0;
            s_addr_1 <= 0;
            m_addr   <= 0;
            weight_addr <= 0;
            //起始信号 (4个模块)
            start <= 0;
            //类型寄存器 （6个类型）
            type <= 0;
            //步长信号
            stride <= 0;
            //relu
            relu <= 0;
            //列数、行数寄存器
            col_num <= 0;
            row_num <= 0;
            //计算次数寄存器
            calculate_num      <= 0;
            calculate_cin_num  <= 0;
            calculate_cout_num <= 0;
            //计算结束寄存器
            calculate_end <= 0;
            // //通道数寄存器 // 
            // channel_in_num   <= 0;
            // channel_out_num  <= 0;
            //输入输出字节计数器
            in_col_channel_num  <= 0;
            out_col_channel_num <= 0;
            //scale和zero_point
            scale_1 <= 0;
            scale_2 <= 0;
            scale_3 <= 0;
            zero_1  <= 0;
            zero_2  <= 0;
            zero_3  <= 0;
            //weight
            weight_len <= 0;
            weight_sum <= 0;
            
        end
        else if(wen) begin
            case(waddr)
                //DMA地址信息
                `S_ADDR_0:begin
                    s_addr_0 <= wdata;
                end
                `S_ADDR_1:begin
                    s_addr_1 <= wdata;
                end
                `M_ADDR:begin
                    m_addr   <= wdata;
                end
                `WEIGHT_ADDR:begin
                    weight_addr <= wdata;
                end
                //起始信号 (4个模块)
                `START:begin
                    start    <= wdata[6 : 0];
                end
                //类型寄存器 （6个类型）
                `TYPE:begin
                    type     <= wdata[7 : 0];
                end
                `STRIDE:begin
                    stride   <= wdata[0];
                end
                //RELU
                `RELU:begin
                    relu     <= wdata[0];
                end
                //列数、行数寄存器
                `COL_NUM:begin
                    col_num  <= wdata[COL_WIDTH : 0];
                end
                `ROW_NUM:begin
                    row_num  <= wdata[ROW_WIDTH : 0];
                end
                //计算次数寄存器
                `CALCULATE_NUM:begin
                    calculate_num      <= wdata[CALULATE_CNT_WIDTH : 0];
                end
                `CALCULATE_CIN_NUM:begin
                    calculate_cin_num  <= wdata[IN_CALULATE_CNT_WIDTH : 0];
                end
                `CALCULATE_COUT_NUM:begin
                    calculate_cout_num <= wdata[OUT_CALULATE_CNT_WIDTH : 0];
                end
                `CALCULATE_END:begin
                    calculate_end  <= wdata[0];
                end
                //输入输出字节计数器
                `IN_COL_CHANNEL_NUM:begin
                    in_col_channel_num  <= wdata[IN_LEN_WIDTH : 0];
                end
                `OUT_COL_CHANNEL_NUM:begin
                    out_col_channel_num <= wdata[OUT_LEN_WIDTH : 0];
                end
                //scale和zero_point
                `SCALE_1:begin
                    scale_1 <= wdata[SCALE_WIDTH-1 : 0];
                end
                `SCALE_2:begin
                    scale_2 <= wdata[SCALE_WIDTH-1 : 0];
                end
                `SCALE_3:begin
                    scale_3 <= wdata[SCALE_WIDTH*2-1 : 0];
                end
                `ZERO_1:begin
                    zero_1  <= wdata[INT-1 : 0];
                end
                `ZERO_2:begin
                    zero_2  <= wdata[INT-1 : 0];
                end
                `ZERO_3:begin
                    zero_3  <= wdata[INT-1 : 0];
                end
                //weight
                `WEIGHT_SUM_REG:begin
                    weight_sum <= wdata[WEIGHT_SUM_WIDTH : 0];
                end
                `WEIGHT_LEN_REG:begin
                    weight_len <= wdata[WEIGHT_LEN_WIDTH : 0];
                end
                // `WEIGHT_NUM_REG:begin
                //     weight_num <= wdata[WEIGHT_NUM_WIDTH : 0];
                // end
                default:begin
                    
                end
            endcase
        end
    end


endmodule