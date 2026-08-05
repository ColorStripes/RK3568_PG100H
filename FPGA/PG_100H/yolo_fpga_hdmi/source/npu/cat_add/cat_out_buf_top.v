module cat_out_buf_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    
    parameter CHA_PAR_OUT = 16,                                      //输出通道并行度
              CHA_IMG_OUT = 128,                                     //图片输出最大通道数
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),       //输出计算次数
              CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              MAX_OUT_LEN = 5120,                                   //此模块所输出的最大字节数  也就是输出一行*通道的字节数
              LEN_WIDTH = $clog2(MAX_OUT_LEN),
              MAX_OUT_ROW = 320,                                    //输出的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_OUT_ROW),
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT,                       //数据传输位宽    输出并行度 * INT8
              DATA_DEPTH = (MAX_OUT_LEN / CHA_PAR_OUT),               //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
              READ_DELAY = 1                                        //读出数据所需要的延迟
)
(
    input          clk              ,
    input          rst              ,

    input                       start            ,

    
    input  [AXI_DATA_WIDTH-1 : 0]    base_addr          ,
    input  [LEN_WIDTH : 0]           out_col_channel_num, //out_col_channel_num = col * channel
    input  [ROW_WIDTH : 0]           row_num            ,
    input  [CALULATE_CNT_WIDTH : 0]  calculate_cout_num ,     //输出通道计算次数 



    input  [DATA_WIDTH-1 : 0]   s_data      ,
    input                       s_valid     ,
    input                       s_last      ,
    output                      s_req       ,

    output [DATA_WIDTH-1 : 0]   m_data ,
    output                      m_last ,
    output                      m_valid,
    input                       m_ready, 

    output [AXI_ADDR_WIDTH-1 : 0]  cmd_addr         ,
    output [AXI_DATA_WIDTH-1 : 0]  cmd_len          ,
    output                         cmd_valid        ,
    input                          cmd_ready        ,

    output           calculate_end,
    input            calculate_end_receive
);


wire [DATA_WIDTH-1 : 0]      out_m_data     ;
wire                         out_m_valid    ;
wire                         out_m_last     ;
wire                         out_m_ready    ;

wire [AXI_ADDR_WIDTH-1 : 0]  out_cmd_addr   ;
wire [AXI_DATA_WIDTH-1 : 0]  out_cmd_len    ;
wire                         out_cmd_valid  ;
wire                         out_cmd_ready  ;

wire                         out_calculate_end        ;
wire                         out_calculate_end_receive;

wire [DATA_WIDTH-1 : 0] ping_s_data ;
wire                    ping_s_valid;
wire                    ping_s_last ;
wire                    ping_s_req  ;

wire [DATA_WIDTH-1 : 0] ping_m_data ;
wire                    ping_m_valid;
wire                    ping_m_last ;
wire                    ping_m_req  ;




wire [DATA_WIDTH-1 : 0] pang_s_data ;
wire                    pang_s_valid;
wire                    pang_s_last ;
wire                    pang_s_req;

wire [DATA_WIDTH-1 : 0] pang_m_data ;
wire                    pang_m_valid;
wire                    pang_m_last ;
wire                    pang_m_req  ;


cat_out_buf_ctrl #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_OUT(CHA_PAR_OUT),                                    //输出通道并行度
    .CHA_IMG_OUT(CHA_IMG_OUT),                                    //图片输出最大通道数
    .MAX_OUT_LEN(MAX_OUT_LEN),                                    //此模块所输出的最大字节数  也就是输出一行*通道的字节数
    .MAX_OUT_ROW(MAX_OUT_ROW),                                    //输出的IMG的最大行数
    .INT(INT)                                                     //每个数的位宽
)
out_buf_ctrl_inst (
    .clk(clk)              ,
    .rst(rst)              ,

    .start(start)            ,
    
    .base_addr(base_addr),              //写内存的起始基地址
    .out_col_channel_num(out_col_channel_num),                  //m_data_len   输出一行的数据
    .row_num(row_num),
    .calculate_cout_num(calculate_cout_num),     //输出通道计算次数 


    //当前模块接受数据
    .s_data(s_data)  ,
    .s_valid(s_valid),
    .s_last(s_last) ,
    .s_req(s_req),                  //req是有数进就拉低请求的是一行 ready是有数进 请求的是一个 进到最后一个才拉低   


    //fifo向下级模块输出数据
    .m_data (out_m_data) ,
    .m_last (out_m_last) ,
    .m_valid(out_m_valid),
    .m_ready(out_m_ready), 

    //ping接受数据
    .ping_s_data(ping_s_data)    ,
    .ping_s_valid(ping_s_valid)  ,
    .ping_s_last(ping_s_last)   ,
    .ping_s_req(ping_s_req)  ,

    //ping向fifo输出数据
    .ping_m_data(ping_m_data)   ,
    .ping_m_valid(ping_m_valid)  ,
    .ping_m_last(ping_m_last)   ,
    .ping_m_req(ping_m_req)    ,


    .pang_s_data(pang_s_data)    ,
    .pang_s_valid(pang_s_valid)  ,
    .pang_s_last(pang_s_last)   ,
    .pang_s_req(pang_s_req)    ,


    .pang_m_data(pang_m_data),
    .pang_m_valid(pang_m_valid),
    .pang_m_last(pang_m_last),
    .pang_m_req(pang_m_req),
 
    
    .calculate_end(out_calculate_end),
    .calculate_end_receive(out_calculate_end_receive),        

    //指令数据
    .cmd_addr (out_cmd_addr ),
    .cmd_len  (out_cmd_len  ),
    .cmd_valid(out_cmd_valid),
    .cmd_ready(out_cmd_ready)          
);






cat_out_buf #(
              .CHA_PAR_OUT(CHA_PAR_OUT),                     //输出通道并行度
              .CHA_IMG_OUT(CHA_IMG_OUT),                     //图片输出最大通道数
              .MAX_CALULATE_NUM(MAX_OUT_CALULATE_NUM),
              .DATA_DEPTH(DATA_DEPTH),
              .READ_DELAY(READ_DELAY),                       //读出数据所需要的延迟
              .INT(INT)                                      //每个数的位宽
)
ping_buf(
    .clk(clk),
    .rst(rst),

    .start(start),
    .calculate_cout_num(calculate_cout_num),      //输出计算次数 

    //当前模块接受数据
    .s_data(ping_s_data)  ,
    .s_valid(ping_s_valid),
    .s_last(ping_s_last) ,
    .s_req(ping_s_req),                  //req是有数进就拉低请求的是一行 ready是有数进 请求的是一个 进到最后一个才拉低              


    //下级模块接受数据
    .m_data(ping_m_data) ,
    .m_last(ping_m_last) ,
    .m_valid(ping_m_valid),
    .m_req(ping_m_req)                   //这里是m_req 因为是下级FIFO请求

);




cat_out_buf #(
              .CHA_PAR_OUT(CHA_PAR_OUT),                     //输出通道并行度
              .CHA_IMG_OUT(CHA_IMG_OUT),                     //图片输出最大通道数
              .MAX_CALULATE_NUM(MAX_OUT_CALULATE_NUM),
              .DATA_DEPTH(DATA_DEPTH),
              .READ_DELAY(READ_DELAY),                       //读出数据所需要的延迟
              .INT(INT)                                      //每个数的位宽
)
pang_buf(
    .clk(clk),
    .rst(rst),

    .start(start),
    .calculate_cout_num(calculate_cout_num),      //输出计算次数 

    //当前模块接受数据
    .s_data(pang_s_data)  ,
    .s_valid(pang_s_valid),
    .s_last(pang_s_last) ,
    .s_req(pang_s_req),                  //req是有数进就拉低请求的是一行 ready是有数进 请求的是一个 进到最后一个才拉低     


    //下级模块接受数据
    .m_data(pang_m_data) ,
    .m_last(pang_m_last) ,
    .m_valid(pang_m_valid),
    .m_req(pang_m_req)                   //这里是m_req 因为是下级FIFO请求

);


    pipe #(
        .WIDTH(DATA_WIDTH+1)
    )
    pipe_out(
        .clk(clk),
        .rst(rst),

        .up_valid(out_m_valid),
        .up_ready(out_m_ready),
        .data_in ({out_m_last, out_m_data}),


        .down_valid(m_valid),
        .down_ready(m_ready),
        .data_out  ({m_last, m_data})
    );


    pipe #(
        .WIDTH(AXI_ADDR_WIDTH + AXI_DATA_WIDTH)
    )
    pipe_out_cmd(
        .clk(clk),
        .rst(rst),

        .up_valid(out_cmd_valid),
        .up_ready(out_cmd_ready),
        .data_in ({out_cmd_addr, out_cmd_len}),


        .down_valid(cmd_valid),
        .down_ready(cmd_ready),
        .data_out  ({cmd_addr, cmd_len})
    );


    pipe #(
        .WIDTH(1)
    )
    pipe_out_end(
        .clk(clk),
        .rst(rst),

        .up_valid(out_calculate_end),
        .up_ready(out_calculate_end_receive),
        .data_in (),


        .down_valid(calculate_end),
        .down_ready(calculate_end_receive),
        .data_out  ()
    );

endmodule