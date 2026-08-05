module upsample_in_buf_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_IN = 16,                          //输入通道并行度
              MAX_IN_LEN = 5120,                        //此模块所接受的最大字节数  也就是一行*所有通道的字节数
              LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_IN_ROW = 320,                         //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              //图片通道//
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),          //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),

              INT = 8,                                  //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT,            //数据传输位宽    并行度 * INT8
              DATA_DEPTH = MAX_IN_LEN / CHA_PAR_IN,     //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
              READ_DELAY = 1                            //读出数据所需要的延迟
              
)
(
    input          clk              ,
    input          rst              ,

    input          start            ,
    input  [AXI_DATA_WIDTH-1 : 0]        base_addr          ,
    input  [LEN_WIDTH : 0]               in_col_channel_num , //in_col_channel_num = col * channel
    input  [ROW_WIDTH : 0]               row_num            ,
    //输入通道计算次数
    input  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num  ,

    input  [DATA_WIDTH-1 : 0]   s_data      ,
    input                       s_valid     ,
    input                       s_last      ,
    output                      s_ready     ,


    input                       m_req       ,
    output [DATA_WIDTH-1 : 0]   m_data      ,
    output                      m_valid     ,
    output                      m_last      ,

    output [AXI_ADDR_WIDTH-1 : 0]  cmd_addr         ,
    output [AXI_DATA_WIDTH-1 : 0]  cmd_len          ,
    output                         cmd_valid        ,
    input                          cmd_ready        

);



wire [DATA_WIDTH-1 : 0] ping_s_data ;
wire                    ping_s_valid;
wire                    ping_s_last ;
wire                    ping_s_ready;

wire                    ping_m_req  ;
wire [DATA_WIDTH-1 : 0] ping_m_data ;
wire                    ping_m_valid;
wire                    ping_m_last ;



wire [DATA_WIDTH-1 : 0] pang_s_data ;
wire                    pang_s_valid;
wire                    pang_s_last ;
wire                    pang_s_ready;

wire                    pang_m_req  ;
wire [DATA_WIDTH-1 : 0] pang_m_data ;
wire                    pang_m_valid;
wire                    pang_m_last ;



upsample_in_buf_ctrl #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),             //输入通道并行度
    .MAX_IN_LEN(MAX_IN_LEN),             //此模块所接受的最大字节数  也就是一行*通道的字节数
    .MAX_IN_ROW(MAX_IN_ROW),             //输入的IMG的最大行数
    .INT(INT)                            //每个数的位宽             
) 
in_buf_ctrl_inst (
    .clk(clk)               ,
    .rst(rst)               ,

    .start(start)           ,//起始信号
    .base_addr(base_addr)   ,//读取内存的起始基地址
    .in_col_channel_num(in_col_channel_num) ,//这是需要读取一行的总字节数 in_col_channel_num = col * channel
    .row_num(row_num)       ,//最大的行数  （多留一位是因为计数器会访问数值而没有-1）


    .s_data(s_data)         ,//接受数据
    .s_valid(s_valid)       ,
    .s_last(s_last)         ,
    .s_ready(s_ready)       ,

    .m_req(m_req)           ,//向下级传输数据
    .m_data(m_data)         ,
    .m_valid(m_valid)       ,
    .m_last(m_last)         ,




    .ping_s_data(ping_s_data)   ,//ping数据
    .ping_s_valid(ping_s_valid) ,
    .ping_s_last(ping_s_last)   ,
    .ping_s_ready(ping_s_ready) ,

    .ping_m_req(ping_m_req)     ,
    .ping_m_data(ping_m_data)  ,
    .ping_m_valid(ping_m_valid) ,
    .ping_m_last(ping_m_last)   ,




    .pang_s_data(pang_s_data)   ,//pang数据
    .pang_s_valid(pang_s_valid) ,
    .pang_s_last(pang_s_last)   ,
    .pang_s_ready(pang_s_ready) ,

    .pang_m_req(pang_m_req)     ,
    .pang_m_data(pang_m_data)   ,
    .pang_m_valid(pang_m_valid) ,
    .pang_m_last(pang_m_last)   ,


    .cmd_addr(cmd_addr)     ,//指令数据
    .cmd_len(cmd_len)       ,
    .cmd_valid(cmd_valid)   ,
    .cmd_ready(cmd_ready)      


);



upsample_in_buf #(
    .CHA_PAR_IN(CHA_PAR_IN),                     //输入通道并行度
    .CHA_IMG_IN(CHA_IMG_IN),
    .DATA_DEPTH(DATA_DEPTH),                     //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
    .READ_DELAY(READ_DELAY),                     //读出数据所需要的延迟
    .INT(INT)                                    //每个数的位宽        
) 
ping_buf (
    .clk(clk),
    .rst(rst),


    //一次读取并行度个字节数 需要读取多少次才能把一行数据读完 read_num = col * channel / CHA_PAR_IN
    .read_num(in_col_channel_num >> $clog2(CHA_PAR_IN)), 
    //输入通道计算次数
    .calculate_cin_num(calculate_cin_num),



    //当前模块接受数据
    .s_data(ping_s_data),
    .s_valid(ping_s_valid),
    .s_last(ping_s_last),
    .s_ready(ping_s_ready),

    //下级模块接受数据
    .m_req(ping_m_req),
    .m_data(ping_m_data),
    .m_valid(ping_m_valid),
    .m_last(ping_m_last)
                                          
);


upsample_in_buf #(
    .CHA_PAR_IN(CHA_PAR_IN),                     //输入通道并行度
    .CHA_IMG_IN(CHA_IMG_IN),
    .DATA_DEPTH(DATA_DEPTH),                     //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
    .READ_DELAY(READ_DELAY)                      //读出数据所需要的延迟    
) 
pang_buf (
    .clk(clk),
    .rst(rst),


    //一次读取并行度个字节数 需要读取多少次才能把一行数据读完 read_num = col * channel / CHA_PAR_IN
    .read_num(in_col_channel_num >> $clog2(CHA_PAR_IN)), 
    //输入通道计算次数
    .calculate_cin_num(calculate_cin_num),



    //当前模块接受数据
    .s_data(pang_s_data),
    .s_valid(pang_s_valid),
    .s_last(pang_s_last),
    .s_ready(pang_s_ready),

    //下级模块接受数据
    .m_req(pang_m_req),
    .m_data(pang_m_data),
    .m_valid(pang_m_valid),
    .m_last(pang_m_last)
                                          
);





endmodule