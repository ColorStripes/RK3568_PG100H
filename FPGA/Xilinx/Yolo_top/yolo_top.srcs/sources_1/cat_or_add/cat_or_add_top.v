module cat_or_add_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CAT_ADD = 1,
              //并行度//
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = CHA_PAR_IN,                  //输出通道并行度
              //图片数据//
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              //MAX_OUT_ROW = MAX_IN_ROW,                  //输出的IMG的最大行数
              //图片通道//
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),          //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM), 
              //数据位宽//
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH_IN = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_WIDTH_OUT = CHA_PAR_OUT * INT,             //数据传输位宽    输入并行度 * INT8
              //尺度位宽//
              SCALE_WIDTH = 16,                          //scale的位数
              SCALE_FRACTION_WIDTH = 15,
              //一行数据的最大字节数//
              MAX_IN_LEN = 10240,                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              //MAX_OUT_LEN = MAX_IN_LEN * 2,                  //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              //OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //读出数据所需要的延迟
              READ_DELAY = 1,                           
              //乘法器延迟 
              MUL_DELAY = 4                                                      
)
(
    input          clk              ,
    input          rst              ,
    
    input          start            ,

    input  [IN_LEN_WIDTH : 0]           in_col_channel_num , //col_channel_num = col * channel
    input  [ROW_WIDTH : 0]              row_num            ,
    //输入通道计算次数
    input  [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num  ,


    input  [SCALE_WIDTH-1 : 0]   scale_1  ,
    input  [SCALE_WIDTH-1 : 0]   scale_2  ,
    input  [SCALE_WIDTH*2-1 : 0] scale_3  ,
    input  [INT-1 : 0]           zero_1   ,
    input  [INT-1 : 0]           zero_2   ,


    input  [AXI_DATA_WIDTH-1 : 0]  s_addr_0      ,            //特征图数据输入地址
    input  [DATA_WIDTH_IN-1 : 0] s_data_0      ,
    input                        s_valid_0     ,
    input                        s_last_0      ,
    output                       s_ready_0     ,
    
    input  [AXI_DATA_WIDTH-1 : 0]  s_addr_1      ,            //特征图数据输入地址
    input  [DATA_WIDTH_IN-1 : 0] s_data_1      ,
    input                        s_valid_1     ,
    input                        s_last_1      ,
    output                       s_ready_1     ,


    //in_buf的命令接口
    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_0  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_0   ,
    output                         s_cmd_valid_0 ,
    input                          s_cmd_ready_0 ,

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_1  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_1   ,
    output                         s_cmd_valid_1 ,
    input                          s_cmd_ready_1 ,


    output [DATA_WIDTH_OUT-1 : 0]  m_data      ,
    output                         m_valid     ,
    output                         m_last      ,
    input                          m_req     



);


///////////////////////////////////////// 计算所需数据的算子级别寄存器 /////////////////////////////////

    reg                                start_reg             ;
    reg  [IN_LEN_WIDTH : 0]            in_col_channel_num_reg;
    reg  [ROW_WIDTH : 0]               row_num_reg           ;
    reg  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num_reg ;
    reg  [SCALE_WIDTH-1 : 0]           scale_1_reg           ;
    reg  [SCALE_WIDTH-1 : 0]           scale_2_reg           ;
    reg  [SCALE_WIDTH*2-1 : 0]         scale_3_reg           ;
    reg  [INT-1 : 0]                   zero_1_reg            ;
    reg  [INT-1 : 0]                   zero_2_reg            ;
    reg  [AXI_DATA_WIDTH-1 : 0]        s_addr_0_reg          ;
    reg  [AXI_DATA_WIDTH-1 : 0]        s_addr_1_reg          ;
    always @(posedge clk) begin
        if(start) begin
            in_col_channel_num_reg <= in_col_channel_num;
            row_num_reg            <= row_num           ;
            calculate_cin_num_reg  <= calculate_cin_num ;
            scale_1_reg            <= scale_1           ;
            scale_2_reg            <= scale_2           ;
            scale_3_reg            <= scale_3           ;
            zero_1_reg             <= zero_1            ;
            zero_2_reg             <= zero_2            ;
            s_addr_0_reg           <= s_addr_0          ;
            s_addr_1_reg           <= s_addr_1          ;
        end
        start_reg              <= start             ;
    end


//////////////////////////////////////////  整体控制模块  ///////////////////////////////////////////////////

////////当前模块的output/////////
//各请求信号
wire calculate_req;


cat_or_add_ctrl #(
    .MAX_IN_ROW(MAX_IN_ROW)                          //输入的IMG的最大行数
)
ctrl(
    .clk(clk)          ,
    .rst(rst)          ,
    .start(start_reg)       ,

    .row_num(row_num_reg)  ,

    //from in_buf
    .s_valid(in_buf_m_valid_1)  ,
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
wire [DATA_WIDTH_IN-1 : 0] in_buf_m_data_0      ;
wire [DATA_WIDTH_IN-1 : 0] in_buf_m_data_1      ;
wire                       in_buf_m_valid_0     ;
wire                       in_buf_m_valid_1     ;
wire                       in_buf_m_last      ;


cat_or_add_in_buf_top #(
    .CAT_ADD(CAT_ADD),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN(CHA_PAR_IN),                        //输入通道并行度
    .MAX_IN_LEN(MAX_IN_LEN),                        //此模块所接受的最大字节数  也就是一行*所有通道的字节数
    .MAX_IN_ROW(MAX_IN_ROW),                        //输入的IMG的最大行数
    .CHA_IMG_IN(CHA_IMG_IN),                        //输入的IMG的最大通道数
    .INT(INT),                                      //每个数的位宽
    .READ_DELAY(READ_DELAY)                         //读出数据所需要的延迟
              
)
in_buf(
    .clk(clk)              ,
    .rst(rst)              ,

    .start(start_reg)           ,

    //from DMA
    .base_addr_0(s_addr_0_reg)      ,
    .base_addr_1(s_addr_1_reg)      ,
    .in_col_channel_num(in_col_channel_num_reg) , //in_col_channel_num = col * channel
    .row_num(row_num_reg)            ,
    //输入通道计算次数
    .calculate_cin_num(calculate_cin_num_reg),

    //from DMA
    .s_data_0(s_data_0)      ,
    .s_valid_0(s_valid_0)    ,
    .s_last_0(s_last_0)      ,
    .s_ready_0(s_ready_0)    ,

    .s_data_1(s_data_1)      ,
    .s_valid_1(s_valid_1)    ,
    .s_last_1(s_last_1)      ,
    .s_ready_1(s_ready_1)    ,


    //to add
    .m_req   (in_buf_m_req)     ,
    .m_data_0  (in_buf_m_data_0)    ,
    .m_data_1  (in_buf_m_data_1)    ,
    .m_valid_0 (in_buf_m_valid_0)   ,
    .m_valid_1 (in_buf_m_valid_1)   ,
    .m_last  (in_buf_m_last)    ,


    //传给DMA命令接口
    .cmd_addr_0(s_cmd_addr_0)        ,
    .cmd_len_0(s_cmd_len_0)          ,
    .cmd_valid_0(s_cmd_valid_0)      ,
    .cmd_ready_0(s_cmd_ready_0)      ,

    .cmd_addr_1(s_cmd_addr_1)        ,
    .cmd_len_1(s_cmd_len_1)          ,
    .cmd_valid_1(s_cmd_valid_1)      ,
    .cmd_ready_1(s_cmd_ready_1)      
);



/////////////////////////////////////////////  计算   ///////////////////////////////////////////////////////

////////当前模块的output//////
//传入out_buf
wire [DATA_WIDTH_OUT-1 : 0]  add_m_data ;
wire              add_m_valid     ;
wire              add_m_last      ;



cat_or_add #(
    .CHA_PAR_IN(CHA_PAR_IN),                           //输入通道并行度
    .INT(INT),
    .SCALE_WIDTH(SCALE_WIDTH),                          //scale的小数位数
    .SCALE_FRACTION_WIDTH(SCALE_FRACTION_WIDTH),
    .MUL_DELAY(MUL_DELAY)
)
cat_add(
    .clk(clk)         ,
    .rst(rst)         ,

    .start(start_reg)     ,

    //from DMA
    .scale_1(scale_1_reg),
    .scale_2(scale_2_reg),
    .scale_3(scale_3_reg),
    .zero_1(zero_1_reg)        ,
    .zero_2(zero_2_reg)        ,


    .s_data_0 (in_buf_m_data_0) ,
    .s_data_1 (in_buf_m_data_1) ,
    .s_valid_0 (in_buf_m_valid_0)   ,
    .s_valid_1 (in_buf_m_valid_1)   ,
    .s_last   (in_buf_m_last)    ,


    .m_data (m_data)   ,
    .m_valid(m_valid)  ,
    .m_last (m_last)


);





endmodule