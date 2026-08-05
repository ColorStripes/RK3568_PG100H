///////////////////////////////////寄存器地址//////////////////////////////////////
//DMA地址信息
`define S_ADDR_0                                32'h0000_0001     
`define S_ADDR_1                                32'h0000_0002     
`define M_ADDR                                  32'h0000_0003
`define WEIGHT_ADDR                             32'h0000_0004     
//起始信号 (4个模块)
`define START                                   32'h0000_0005
//类型寄存器 （6个类型）
`define TYPE                                    32'h0000_0006
//步长信号
`define STRIDE                                  32'h0000_0007
//relu信号
`define RELU                                    32'h0000_0008
//列数、行数寄存器
`define COL_NUM                                 32'h0000_0009
`define ROW_NUM                                 32'h0000_000a
//计算次数寄存器
`define CALCULATE_NUM                           32'h0000_000b
`define CALCULATE_CIN_NUM                       32'h0000_000c
`define CALCULATE_COUT_NUM                      32'h0000_000d
//计算结束寄存器
`define CALCULATE_END                           32'h0000_000e
//输入输出字节计数器
`define IN_COL_CHANNEL_NUM                      32'h0000_000f
`define OUT_COL_CHANNEL_NUM                     32'h0000_0010
//scale和zero_point
`define SCALE_1                                 32'h0000_0011
`define SCALE_2                                 32'h0000_0012
`define SCALE_3                                 32'h0000_0013
`define ZERO_1                                  32'h0000_0014
`define ZERO_2                                  32'h0000_0015
`define ZERO_3                                  32'h0000_0016
//weight
`define WEIGHT_SUM_REG                          32'h0000_0017
`define WEIGHT_LEN_REG                          32'h0000_0018

//`define WEIGHT_NUM_REG                          32'h0000_0019
//通道数寄存器 // 
// `define CHANNEL_IN_NUM                          32'h0000_001a
// `define CHANNEL_OUT_NUM                         32'h0000_001b