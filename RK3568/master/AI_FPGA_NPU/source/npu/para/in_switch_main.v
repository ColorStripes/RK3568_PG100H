module in_switch_main #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_IN = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input  [4 : 0]        start ,


    input   [DATA_WIDTH-1 : 0]   s_data_0   ,
    input                        s_valid_0  ,
    input                        s_last_0   ,
    output                       s_ready_0  , 

    //命令接口
    output  [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_0  ,
    output  [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_0   ,
    output                          s_cmd_valid_0 ,
    input                           s_cmd_ready_0 ,


    //1
    input   [DATA_WIDTH-1 : 0]   s_data_1   ,
    input                        s_valid_1  ,
    input                        s_last_1   ,
    output                       s_ready_1  , 

    //命令接口
    output  [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_1  ,
    output  [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_1   ,
    output                          s_cmd_valid_1 ,
    input                           s_cmd_ready_1 ,


///////////////////////////////////////////
    output  [DATA_WIDTH-1 : 0]    conv_m_data      ,
    output                        conv_m_valid     ,
    output                        conv_m_last      ,
    input                         conv_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_m_cmd_len   ,
    input                         conv_m_cmd_valid ,
    output                        conv_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]   conv_weight_data      ,
    output                       conv_weight_valid     ,
    output                       conv_weight_last      ,
    input                        conv_weight_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_weight_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_weight_cmd_len   ,
    input                         conv_weight_cmd_valid ,
    output                        conv_weight_cmd_ready ,



    output  [DATA_WIDTH-1 : 0]   sppf_m_data      ,
    output                       sppf_m_valid     ,
    output                       sppf_m_last      ,
    input                        sppf_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  sppf_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  sppf_m_cmd_len   ,
    input                         sppf_m_cmd_valid ,
    output                        sppf_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]    upsample_m_data      ,
    output                        upsample_m_valid     ,
    output                        upsample_m_last      ,
    input                         upsample_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  upsample_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  upsample_m_cmd_len   ,
    input                         upsample_m_cmd_valid ,
    output                        upsample_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]   focus_m_data      ,
    output                       focus_m_valid     ,
    output                       focus_m_last      ,
    input                        focus_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  focus_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  focus_m_cmd_len   ,
    input                         focus_m_cmd_valid ,
    output                        focus_m_cmd_ready 


);






in_switch_main0 #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN    (CHA_PAR_IN    ),                          //输入通道并行度
    .INT           (INT           )                           //每个数的位宽
)
in_switch_main0(
    .clk(clk)              ,
    .rst(rst)              ,

    .start(start[3 : 0]) ,


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
    .conv_m_data (conv_m_data )     ,
    .conv_m_valid(conv_m_valid)     ,
    .conv_m_last (conv_m_last )     ,
    .conv_m_ready(conv_m_ready)     ,

    .conv_m_cmd_addr (conv_m_cmd_addr ) ,
    .conv_m_cmd_len  (conv_m_cmd_len  ) ,
    .conv_m_cmd_valid(conv_m_cmd_valid) ,
    .conv_m_cmd_ready(conv_m_cmd_ready) ,



    .sppf_m_data (sppf_m_data )     ,
    .sppf_m_valid(sppf_m_valid)     ,
    .sppf_m_last (sppf_m_last )     ,
    .sppf_m_ready(sppf_m_ready)     ,

    .sppf_m_cmd_addr (sppf_m_cmd_addr ) ,
    .sppf_m_cmd_len  (sppf_m_cmd_len  ) ,
    .sppf_m_cmd_valid(sppf_m_cmd_valid) ,
    .sppf_m_cmd_ready(sppf_m_cmd_ready) ,


    .upsample_m_data (upsample_m_data )     ,
    .upsample_m_valid(upsample_m_valid)     ,
    .upsample_m_last (upsample_m_last )     ,
    .upsample_m_ready(upsample_m_ready)     ,

    .upsample_m_cmd_addr (upsample_m_cmd_addr ) ,
    .upsample_m_cmd_len  (upsample_m_cmd_len  ) ,
    .upsample_m_cmd_valid(upsample_m_cmd_valid) ,
    .upsample_m_cmd_ready(upsample_m_cmd_ready) 

);






in_switch_main1 #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CHA_PAR_IN    (CHA_PAR_IN    ),                          //输入通道并行度
    .INT           (INT           )                           //每个数的位宽
)
in_switch_main1(
    .clk(clk)              ,
    .rst(rst)              ,

    .start({start[4], start[1 : 0]}) ,

    .s_data_1 (s_data_1 )  ,
    .s_valid_1(s_valid_1)  ,
    .s_last_1 (s_last_1 )  ,
    .s_ready_1(s_ready_1)  , 

    //命令接口
    .s_cmd_addr_1 (s_cmd_addr_1 ) ,
    .s_cmd_len_1  (s_cmd_len_1  ) ,
    .s_cmd_valid_1(s_cmd_valid_1) ,
    .s_cmd_ready_1(s_cmd_ready_1) ,


///////////////////////////////////////////
    .conv_weight_data (conv_weight_data )     ,
    .conv_weight_valid(conv_weight_valid)     ,
    .conv_weight_last (conv_weight_last )     ,
    .conv_weight_ready(conv_weight_ready)     ,

    .conv_weight_cmd_addr (conv_weight_cmd_addr ) ,
    .conv_weight_cmd_len  (conv_weight_cmd_len  ) ,
    .conv_weight_cmd_valid(conv_weight_cmd_valid) ,
    .conv_weight_cmd_ready(conv_weight_cmd_ready) ,



    .focus_m_data (focus_m_data )     ,
    .focus_m_valid(focus_m_valid)     ,
    .focus_m_last (focus_m_last )     ,
    .focus_m_ready(focus_m_ready)     ,

    .focus_m_cmd_addr (focus_m_cmd_addr ) ,
    .focus_m_cmd_len  (focus_m_cmd_len  ) ,
    .focus_m_cmd_valid(focus_m_cmd_valid) ,
    .focus_m_cmd_ready(focus_m_cmd_ready) 

);



endmodule