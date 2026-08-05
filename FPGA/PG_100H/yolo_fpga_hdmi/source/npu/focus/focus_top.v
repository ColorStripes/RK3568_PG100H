module focus_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
              //并行度//
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 16,                  //输出通道并行度
              //图片数据//
              MAX_IN_ROW = 640,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              //MAX_OUT_ROW = MAX_IN_ROW / 2,              //输出的IMG的最大行数
              //图片通道//
              CHA_IMG_IN = 3,                          //输入的IMG的最大通道数
              //数据位宽//
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH_IN = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_WIDTH_OUT = CHA_PAR_OUT * INT,             //数据传输位宽    输入并行度 * INT8
              //一行数据的最大字节数//
              MAX_IN_LEN = 2560,                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              //MAX_OUT_LEN = MAX_IN_LEN * 2,                  //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              //OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //读出数据所需要的延迟
              READ_DELAY = 1                                                                           
)
(
    input          clk              ,
    input          rst              ,
    
    input          start            ,

    input  [IN_LEN_WIDTH : 0]   in_col_channel_num   , //col_channel_num = col * channel
    input  [ROW_WIDTH : 0]      row_num          ,


    
    input  [AXI_DATA_WIDTH-1 : 0]  s_addr      ,            //特征图数据输入地址
    input  [DATA_WIDTH_IN-1 : 0] s_data      ,
    input                        s_valid     ,
    input                        s_last      ,
    output                       s_ready     ,

    //in_buf的命令接口
    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len   ,
    output                         s_cmd_valid ,
    input                          s_cmd_ready ,


    output [DATA_WIDTH_OUT-1 : 0]  m_data      ,
    output                         m_valid     ,
    output                         m_last      ,
    input                          m_req     


);



///////////////////////////////////////// 计算所需数据的算子级别寄存器 /////////////////////////////////

    reg                           start_reg             ;
    reg  [IN_LEN_WIDTH : 0]       in_col_channel_num_reg;
    reg  [ROW_WIDTH : 0]          row_num_reg           ;
    reg  [AXI_DATA_WIDTH-1 : 0]   s_addr_reg            ;
    always @(posedge clk) begin
        if(start) begin
            row_num_reg             <= row_num           ;
            s_addr_reg              <= s_addr            ;
            in_col_channel_num_reg  <= in_col_channel_num;
        end
        start_reg               <= start             ;
    end

//////////////////////////////////////////  整体控制模块  ///////////////////////////////////////////////////


////////当前模块的output/////////
//各请求信号
wire calculate_req;


focus_ctrl #(
    .MAX_IN_ROW(MAX_IN_ROW / 2)                          //输入的IMG的最大行数
)
ctrl(
    .clk(clk)          ,
    .rst(rst)          ,
    .start(start_reg)       ,

    .row_num(row_num_reg >> 1)  ,

    //from in_buf
    .s_valid(in_buf_m_valid)  ,
    .s_last(in_buf_m_last)    ,
    //to in_buf
    .s_req(in_buf_m_req)      ,             

    //from out_buf
    .calculate_req(m_req)               //说明计算模块可以接受新的计算数据 请求给数据

);




//////////////////////////////////////////  输入buf  ///////////////////////////////////////////////////
//各信号输入
wire in_buf_m_req;
//当前模块的output
//传入add
wire [DATA_WIDTH_IN-1 : 0] in_buf_m_data      ;
wire                       in_buf_m_valid     ;
wire                       in_buf_m_last      ;


focus_in_buf_top #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                        //输入通道并行度
    .CHA_PAR_OUT(CHA_PAR_OUT),
    .CHA_IMG_IN(CHA_IMG_IN) ,                       //输入的IMG的最大通道数
    .MAX_IN_LEN(MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有通道的字节数
    .MAX_IN_ROW(MAX_IN_ROW),                        //输入的IMG的最大行数
    .INT(INT),                                      //每个数的位宽
    .READ_DELAY(READ_DELAY)                         //读出数据所需要的延迟
              
)
in_buf(
    .clk(clk)              ,
    .rst(rst)              ,

    .start(start_reg)           ,

    //from DMA
    .base_addr(s_addr_reg)      ,
    .in_col_channel_num(in_col_channel_num_reg) , //in_col_channel_num = col * channel
    .row_num(row_num_reg)            ,


    //from DMA
    .s_data(s_data)      ,
    .s_valid(s_valid)    ,
    .s_last(s_last)      ,
    .s_ready(s_ready)    ,


    //to out_buf
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



    assign m_data = in_buf_m_data;
    assign m_valid = in_buf_m_valid;
    assign m_last = in_buf_m_last;


endmodule