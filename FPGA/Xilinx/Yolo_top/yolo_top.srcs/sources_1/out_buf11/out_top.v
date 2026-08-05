module out_top #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_OUT = 16,                                      //输出通道并行度
              CHA_IMG_OUT = 128,                                    //图片输出最大通道数
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CONV_CHA_PAR_OUT),   //输出计算次数
              CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              MAX_OUT_LEN = 5120,                                   //此模块所输出的最大字节数  也就是输出一行*通道的字节数
              LEN_WIDTH = $clog2(MAX_OUT_LEN),
              MAX_OUT_ROW = 320,                                    //输出的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_OUT_ROW),
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT,                       //数据传输位宽    输出并行度 * INT8
              //conv
              CONV_CHA_PAR_OUT = 8,
              CONV_DATA_WIDTH  = CONV_CHA_PAR_OUT * INT,
              READ_DELAY = 1                                        //读出数据所需要的延迟
)
(
    input          clk              ,
    input          rst              ,

    input  [5 : 0]              start            ,
    input  [6 : 0]              type             ,
    input                       stride           ,                            //0为1步长 1为2步长

    input  [AXI_DATA_WIDTH-1 : 0]    base_addr          ,
    input  [LEN_WIDTH : 0]           out_col_channel_num, //out_col_channel_num = col * channel
    input  [ROW_WIDTH : 0]           row_num            ,
    input  [CALULATE_CNT_WIDTH : 0]  calculate_cout_num ,     //输出通道计算次数 



    input  [CONV_DATA_WIDTH-1 : 0]  conv_s_data_0      ,
    input                           conv_s_valid_0     ,
    input                           conv_s_last_0      ,
    output                          conv_s_req_0       ,

    input  [CONV_DATA_WIDTH-1 : 0]  conv_s_data_1      ,
    input                           conv_s_valid_1     ,
    input                           conv_s_last_1      ,
    output                          conv_s_req_1       ,


    input  [DATA_WIDTH-1 : 0]   cat_add_s_data      ,
    input                       cat_add_s_valid     ,
    input                       cat_add_s_last      ,
    output                      cat_add_s_req       ,

    input  [DATA_WIDTH-1 : 0]   sppf_s_data      ,
    input                       sppf_s_valid     ,
    input                       sppf_s_last      ,
    output                      sppf_s_req       ,

    input  [DATA_WIDTH-1 : 0]   upsample_s_data      ,
    input                       upsample_s_valid     ,
    input                       upsample_s_last      ,
    output                      upsample_s_req       ,

    input  [DATA_WIDTH-1 : 0]   focus_s_data      ,
    input                       focus_s_valid     ,
    input                       focus_s_last      ,
    output                      focus_s_req       ,



    output [DATA_WIDTH-1 : 0]   m_data  ,
    output                      m_last  ,
    output                      m_valid ,
    input                       m_ready , 

    output [AXI_ADDR_WIDTH-1 : 0]  cmd_addr         ,
    output [AXI_DATA_WIDTH-1 : 0]  cmd_len          ,
    output                         cmd_valid        ,
    input                          cmd_ready        ,

    output           calculate_end     ,
    input            calculate_end_receive

);



    //////////////////////////  conv_start ////////////////////
    wire conv_start;
    assign conv_start = start[0] | start[5];
    /////////////////////////////




    wire [DATA_WIDTH-1 : 0]   s_data   ;
    wire                      s_valid  ;
    wire                      s_last   ;
    wire                      s_req    ;

    out_switch #(
        .CHA_PAR_OUT(CHA_PAR_OUT),                             //输出通道并行度
        .INT(INT),                                             //每个数的位宽
        //conv
        .CONV_CHA_PAR_OUT(CONV_CHA_PAR_OUT)
    )
    out_switch_inst(
        .clk(clk)              ,
        .rst(rst)              ,

        .start(start)            ,

        .conv_s_data_0     (conv_s_data_0)    ,
        .conv_s_valid_0    (conv_s_valid_0)   ,
        .conv_s_last_0     (conv_s_last_0)    ,
        .conv_s_req_0      (conv_s_req_0)     ,

        .conv_s_data_1     (conv_s_data_1)    ,
        .conv_s_valid_1    (conv_s_valid_1)   ,
        .conv_s_last_1     (conv_s_last_1)    ,
        .conv_s_req_1      (conv_s_req_1)     ,

        .cat_add_s_data  (cat_add_s_data)     ,
        .cat_add_s_valid (cat_add_s_valid)    ,
        .cat_add_s_last  (cat_add_s_last)     ,
        .cat_add_s_req   (cat_add_s_req)      ,

        .sppf_s_data     (sppf_s_data)    ,
        .sppf_s_valid    (sppf_s_valid)   ,
        .sppf_s_last     (sppf_s_last)    ,
        .sppf_s_req      (sppf_s_req)     ,


        .upsample_s_data  (upsample_s_data)    ,
        .upsample_s_valid (upsample_s_valid)   ,
        .upsample_s_last  (upsample_s_last)    ,
        .upsample_s_req   (upsample_s_req)     ,

        .focus_s_data    (focus_s_data)      ,
        .focus_s_valid   (focus_s_valid)     ,
        .focus_s_last    (focus_s_last)      ,
        .focus_s_req     (focus_s_req)       ,


        .s_data  (s_data)  ,
        .s_valid (s_valid) ,
        .s_last  (s_last)  ,
        .s_req   (s_req)    

    );



    //用于out_buf的瞬时start
    reg [5 : 0] start_d;
    always @(posedge clk) begin
        if(rst) begin
            start_d <= 6'd0;
        end
        else begin
            start_d <= start;
        end
    end

    wire out_buf_start = |(start & ~start_d);




    out_buf_top #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .CONV_CHA_PAR_OUT(CONV_CHA_PAR_OUT),            //conv输出的并行度
        .CHA_PAR_OUT(CHA_PAR_OUT),                      //输出通道并行度
        .CHA_IMG_OUT(CHA_IMG_OUT),                      //图片输出最大通道数
        .MAX_OUT_LEN(MAX_OUT_LEN),                      //此模块所输出的最大字节数  也就是输出一行*通道的字节数
        .MAX_OUT_ROW(MAX_OUT_ROW),                      //输出的IMG的最大行数
        .INT(INT),                                      //每个数的位宽
        .READ_DELAY(READ_DELAY)                         //读出数据所需要的延迟
    )
    out_buf_top_inst(
        .clk(clk)              ,
        .rst(rst)              ,

        .conv_start(conv_start)   ,
        .start(out_buf_start)     ,
        .type(type)             ,
        .stride(stride)           ,                    //0为1步长 1为2步长

        .base_addr(base_addr)                    ,
        .out_col_channel_num(out_col_channel_num),     //out_col_channel_num = col * channel
        .row_num(row_num)                        ,
        .calculate_cout_num(calculate_cout_num)  ,     //输出通道计算次数 



        .s_data   (s_data)  ,
        .s_valid  (s_valid) ,
        .s_last   (s_last)  ,
        .s_req    (s_req)   , 

        .m_data   (m_data ) ,
        .m_last   (m_last ) ,
        .m_valid  (m_valid) ,
        .m_ready  (m_ready) , 

        .cmd_addr  (cmd_addr )  ,
        .cmd_len   (cmd_len  )  ,
        .cmd_valid (cmd_valid)  ,
        .cmd_ready (cmd_ready)  ,

        .calculate_end(calculate_end),
        .calculate_end_receive(calculate_end_receive)
    );



endmodule