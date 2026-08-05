`include "config.v"
module top #(
    //eth
    parameter REPEAT_TIME = 16'hFFFF,           //重发ARP广播的间隔时间
              REPEAT_CNT  = 2,                  //重发ARP广播的次数
              //MAC的失效时间和存储数量
              INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16,
              //支持的以太网缓存深度
              TX_FIFO_DEPTH = 512,
              RX_FIFO_DEPTH = 2048,
              //支持的用户数据缓存的最大数据深度
              TX_DATA_DEPTH = 2048,                          
              RX_DATA_DEPTH = 2048,
    //eth_cmd
    parameter AXI_DATA_WIDTH         = 32,
              AXI_ADDR_WIDTH         = 32,
              DDR_DATA_WIDTH_IN      = 128,          //发送给DDR
              DDR_DATA_WIDTH_OUT     = 128,          //从DDR读出
              INSTRUCTION_DATA_DEPTH = 3101,
              DDR_DATA_DEPTH         = 512,
    //npu
    parameter CHA_PAR_IN  = `CHA_PAR_IN,                           //输入通道并行度
              CHA_PAR_OUT = `CHA_PAR_OUT,                           //输出通道并行度
              CONV_CHA_PAR_IN = `CONV_CHA_PAR_IN,                   //卷积并行度
              CONV_CHA_PAR_OUT = `CONV_CHA_PAR_OUT,
              //图片数据//
              MAX_IN_COL = `MAX_IN_COL,                          //输入的IMG的最大列数
              COL_WIDTH = $clog2(MAX_IN_COL),
              MAX_IN_ROW = `MAX_IN_ROW,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              MAX_OUT_ROW = `MAX_OUT_ROW,                         //输出的IMG的最大行数
              //图片通道//
              CHA_IMG_IN  = `CHA_IMG_IN,                          //输入的IMG的最大通道数
              CHA_IMG_OUT = `CHA_IMG_OUT,                         //输出的IMG的最大通道数
              //数据位宽//
              INT = `INT,                                   //每个数的位宽
              DATA_WIDTH_IN = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_WIDTH_OUT = CHA_PAR_OUT * INT,             //数据传输位宽    输入并行度 * INT8
              //权重参数//
              WEIGHT_LEN =  `WEIGHT_LEN,   
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN),
              WEIGHT_SUM =  `WEIGHT_SUM,   
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //偏置位宽//
              BIAS_NUM = `BIAS_NUM ,                             //一行拼接的bias个数
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //尺度位宽//
              SCALE_WIDTH = `SCALE_WIDTH,                          //scale的小数位数
              //一行数据的最大字节数//
              MAX_IN_LEN  = `MAX_IN_LEN,                        //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
              IN_LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_OUT_LEN = `MAX_OUT_LEN,                       //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
              OUT_LEN_WIDTH = $clog2(MAX_OUT_LEN),
              //计算次数//
              MAX_IN_CALULATE_NUM = CHA_PAR_IN > CONV_CHA_PAR_IN ? (CHA_IMG_IN / CONV_CHA_PAR_IN) : (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = CHA_PAR_OUT > CONV_CHA_PAR_OUT ? (CHA_IMG_OUT / CONV_CHA_PAR_OUT) : (CHA_IMG_OUT / CHA_PAR_OUT),         //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),
              READ_DELAY = `READ_DELAY
)(
    input sys_rst_n,

    
    // RGMII 接口连接到外部 PHY
    output         rgmii_tx_clk,
    output         rgmii_tx_ctl,
    output [3 : 0] rgmii_tx_data,

    input          rgmii_rx_clk,
    input          rgmii_rx_ctl,
    input  [3 : 0] rgmii_rx_data,
    output         phy_rst_n,



    ////////////////////////////////////////
    //系统主差分时钟
    input           C0_SYS_CLK_0_clk_n,
    input           C0_SYS_CLK_0_clk_p,
    //DDR
    output          C0_DDR4_0_act_n,
    output [16 : 0] C0_DDR4_0_adr,
    output [1 : 0]  C0_DDR4_0_ba,
    output          C0_DDR4_0_bg,
    output          C0_DDR4_0_ck_c,
    output          C0_DDR4_0_ck_t,
    output          C0_DDR4_0_cke,
    output          C0_DDR4_0_cs_n,
    inout  [3 : 0]  C0_DDR4_0_dm_n,
    inout  [31 : 0] C0_DDR4_0_dq,
    inout  [3 : 0]  C0_DDR4_0_dqs_c,
    inout  [3 : 0]  C0_DDR4_0_dqs_t,
    output          C0_DDR4_0_odt,
    output          C0_DDR4_0_reset_n
);

    //系统时钟与复位
    wire sys_rst = ~sys_rst_n;
    wire clk, rst;


    //CMD_S2MM CMDMM2S接口
    //in的输入
    wire [DATA_WIDTH_IN-1 : 0]   s_data_0      ;
    wire                         s_valid_0     ;
    wire                         s_last_0      ;
    wire                         s_ready_0     ; 
    
    wire [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_0  ;
    wire [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_0   ;
    wire                         s_cmd_valid_0 ;
    wire                         s_cmd_ready_0 ;
    //1
    wire [DATA_WIDTH_IN-1 : 0]   s_data_1      ;
    wire                         s_valid_1     ;
    wire                         s_last_1      ;
    wire                         s_ready_1     ; 
    
    wire [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_1  ;
    wire [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_1   ;
    wire                         s_cmd_valid_1 ;
    wire                         s_cmd_ready_1 ;

    //2
    wire [DATA_WIDTH_IN-1 : 0]   s_data_2      ;
    wire                         s_valid_2     ;
    wire                         s_last_2      ;
    wire                         s_ready_2     ;
    
    wire [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_2  ;
    wire [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_2   ;
    wire                         s_cmd_valid_2 ;
    wire                         s_cmd_ready_2 ;

    //3
    wire [DATA_WIDTH_IN-1 : 0]   s_data_3      ;
    wire                         s_valid_3     ;
    wire                         s_last_3      ;
    wire                         s_ready_3     ;
    
    wire [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_3  ;
    wire [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_3   ;
    wire                         s_cmd_valid_3 ;
    wire                         s_cmd_ready_3 ;

    //4
    wire [DATA_WIDTH_IN-1 : 0]   s_data_4      ;
    wire                         s_valid_4     ;
    wire                         s_last_4      ;
    wire                         s_ready_4     ;
    
    wire [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_4  ;
    wire [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_4   ;
    wire                         s_cmd_valid_4 ;
    wire                         s_cmd_ready_4 ;
    
    //out的输出
    wire [DATA_WIDTH_OUT-1 : 0]   out_m_data  ;
    wire                          out_m_last  ;
    wire                          out_m_valid ;
    wire                          out_m_ready ; 
    
    wire [AXI_ADDR_WIDTH-1 : 0]   out_m_cmd_addr  ;
    wire [AXI_DATA_WIDTH-1 : 0]   out_m_cmd_len   ;
    wire                          out_m_cmd_valid ;
    wire                          out_m_cmd_ready ;
    
    wire                          out_calculate_end;
    wire                          out_calculate_end_receive;
    
    
    










    //eth_DDR
    wire [AXI_ADDR_WIDTH-1 : 0]       s_ddr_cmd_addr   ;
    wire [AXI_DATA_WIDTH-1 : 0]       s_ddr_cmd_len    ;
    wire                              s_ddr_cmd_valid  ;
    wire                              s_ddr_cmd_ready  ;
    wire [DDR_DATA_WIDTH_OUT-1 : 0]   s_ddr_axis_data  ;
    wire [DDR_DATA_WIDTH_OUT/8-1 : 0] s_ddr_axis_keep  ;
    wire                              s_ddr_axis_valid ;
    wire                              s_ddr_axis_last  ;
    wire                              s_ddr_axis_ready ;



    wire [AXI_ADDR_WIDTH-1 : 0]      m_ddr_cmd_addr   ;
    wire [AXI_DATA_WIDTH-1 : 0]      m_ddr_cmd_len    ;
    wire                             m_ddr_cmd_valid  ;
    wire                             m_ddr_cmd_ready  ;
    wire [DDR_DATA_WIDTH_IN-1 : 0]   m_ddr_axis_data  ;
    wire [DDR_DATA_WIDTH_IN/8-1 : 0] m_ddr_axis_keep  ;
    wire                             m_ddr_axis_valid ;
    wire                             m_ddr_axis_last  ;
    wire                             m_ddr_axis_ready ;



    npu_ddr_wrapper npu_ddr_wrapper(
        .clk(clk),
        .rst(rst),
        .sys_rst(sys_rst),

        .C0_SYS_CLK_0_clk_n(C0_SYS_CLK_0_clk_n),
        .C0_SYS_CLK_0_clk_p(C0_SYS_CLK_0_clk_p),
        .C0_DDR4_0_act_n   (C0_DDR4_0_act_n   ),
        .C0_DDR4_0_adr     (C0_DDR4_0_adr     ),
        .C0_DDR4_0_ba      (C0_DDR4_0_ba      ),
        .C0_DDR4_0_bg      (C0_DDR4_0_bg      ),
        .C0_DDR4_0_ck_c    (C0_DDR4_0_ck_c    ),
        .C0_DDR4_0_ck_t    (C0_DDR4_0_ck_t    ),
        .C0_DDR4_0_cke     (C0_DDR4_0_cke     ),
        .C0_DDR4_0_cs_n    (C0_DDR4_0_cs_n    ),
        .C0_DDR4_0_dm_n    (C0_DDR4_0_dm_n    ),
        .C0_DDR4_0_dq      (C0_DDR4_0_dq      ),
        .C0_DDR4_0_dqs_c   (C0_DDR4_0_dqs_c   ),
        .C0_DDR4_0_dqs_t   (C0_DDR4_0_dqs_t   ),
        .C0_DDR4_0_odt     (C0_DDR4_0_odt     ),
        .C0_DDR4_0_reset_n (C0_DDR4_0_reset_n ),


        //eth接口
        .read_cmd_addr_0 (s_ddr_cmd_addr ),
        .read_cmd_len_0  (s_ddr_cmd_len  ),
        .read_cmd_valid_0(s_ddr_cmd_valid),
        .read_cmd_ready_0(s_ddr_cmd_ready),

        .read_data_0    (s_ddr_axis_data ),
        .read_keep_0    (s_ddr_axis_keep ),
        .read_valid_0   (s_ddr_axis_valid),
        .read_last_0    (s_ddr_axis_last ),
        .read_ready_0   (s_ddr_axis_ready),


        .write_cmd_addr_0 (m_ddr_cmd_addr ),
        .write_cmd_len_0  (m_ddr_cmd_len  ),
        .write_cmd_valid_0(m_ddr_cmd_valid),
        .write_cmd_ready_0(m_ddr_cmd_ready),

        .write_data_0    (m_ddr_axis_data ),
        .write_keep_0    (m_ddr_axis_keep ),
        .write_valid_0   (m_ddr_axis_valid),
        .write_last_0    (m_ddr_axis_last ),
        .write_ready_0   (m_ddr_axis_ready),


        //npu接口
        .read_cmd_addr_1 (s_cmd_addr_0 ),
        .read_cmd_len_1  (s_cmd_len_0  ),
        .read_cmd_valid_1(s_cmd_valid_0),
        .read_cmd_ready_1(s_cmd_ready_0),
        
        .read_data_1    (s_data_0 ),
        .read_keep_1    (), ///////////////输出
        .read_valid_1   (s_valid_0),
        .read_last_1    (s_last_0 ),
        .read_ready_1   (s_ready_0),


        .write_cmd_addr_1 (out_m_cmd_addr ),
        .write_cmd_len_1  (out_m_cmd_len  ),
        .write_cmd_valid_1(out_m_cmd_valid),
        .write_cmd_ready_1(out_m_cmd_ready),

        .write_data_1    (out_m_data ),
        .write_keep_1    ({DATA_WIDTH_OUT/8{1'b1}}),
        .write_valid_1   (out_m_valid),
        .write_last_1    (out_m_last ),
        .write_ready_1   (out_m_ready),


        //npu接口2
        .read_cmd_addr_2 (s_cmd_addr_1 ),
        .read_cmd_len_2  (s_cmd_len_1  ),
        .read_cmd_valid_2(s_cmd_valid_1),
        .read_cmd_ready_2(s_cmd_ready_1),
        
        .read_data_2    (s_data_1 ),
        .read_keep_2    (),///////////////输出
        .read_valid_2   (s_valid_1),
        .read_last_2    (s_last_1 ),
        .read_ready_2   (s_ready_1),


        //npu接口3
        .read_cmd_addr_3 (s_cmd_addr_2 ),
        .read_cmd_len_3  (s_cmd_len_2  ),
        .read_cmd_valid_3(s_cmd_valid_2),
        .read_cmd_ready_3(s_cmd_ready_2),
        
        .read_data_3    (s_data_2 ),
        .read_keep_3    (),///////////////输出
        .read_valid_3   (s_valid_2),
        .read_last_3    (s_last_2 ),
        .read_ready_3   (s_ready_2),


        //npu接口4
        .read_cmd_addr_4 (s_cmd_addr_3 ),
        .read_cmd_len_4  (s_cmd_len_3  ),
        .read_cmd_valid_4(s_cmd_valid_3),
        .read_cmd_ready_4(s_cmd_ready_3),
        
        .read_data_4    (s_data_3 ),
        .read_keep_4    (),///////////////输出
        .read_valid_4   (s_valid_3),
        .read_last_4    (s_last_3 ),
        .read_ready_4   (s_ready_3),


        //npu接口5
        .read_cmd_addr_5 (s_cmd_addr_4 ),
        .read_cmd_len_5  (s_cmd_len_4  ),
        .read_cmd_valid_5(s_cmd_valid_4),
        .read_cmd_ready_5(s_cmd_ready_4),
        
        .read_data_5    (s_data_4 ),
        .read_keep_5    (),///////////////输出
        .read_valid_5   (s_valid_4),
        .read_last_5    (s_last_4 ),
        .read_ready_5   (s_ready_4)


    );








    //REG的AXI_lite接口
    wire                              m_axi_awvalid;
    wire                              m_axi_awready; 
    wire  [AXI_ADDR_WIDTH-1 : 0]      m_axi_awaddr ;

    wire                              m_axi_wvalid;
    wire                              m_axi_wready; 
    wire  [AXI_DATA_WIDTH-1 : 0]      m_axi_wdata ;
    wire  [AXI_DATA_WIDTH/8-1 : 0]    m_axi_wstrb ;

    wire                              m_axi_bvalid;
    wire                              m_axi_bready;
    wire  [1 : 0]                     m_axi_bresp ;
 
    wire                              m_axi_arvalid; 
    wire                              m_axi_arready; 
    wire  [AXI_ADDR_WIDTH-1 : 0]      m_axi_araddr ;

    wire                              m_axi_rvalid;
    wire                              m_axi_rready; 
    wire  [AXI_DATA_WIDTH-1 : 0]      m_axi_rdata ;
    wire  [1 : 0]                     m_axi_rresp ;







    // 本地网络信息
    localparam [47:0] LOCAL_MAC  = 48'h00_0a_35_33_44_55;
    localparam [31:0] LOCAL_IP   = {8'd192, 8'd168, 8'd0, 8'd1};
    localparam [15:0] LOCAL_PORT = 16'd1234;

    // 目的信息
    localparam [31:0] DST_IP     = {8'd192, 8'd168, 8'd0, 8'd3};
    localparam [15:0] DST_PORT   = 16'd5677;



    // ETH_AXIS 信号
    wire  [7:0] s_eth_axis_data ;
    wire        s_eth_axis_valid;
    wire        s_eth_axis_last ;
    wire        s_eth_axis_ready;

    wire  [7:0] m_eth_axis_data ;
    wire        m_eth_axis_valid;
    wire        m_eth_axis_last ;
    wire        m_eth_axis_ready;


    eth #(
        .REPEAT_TIME(REPEAT_TIME),
        .REPEAT_CNT(REPEAT_CNT),
        .INVALID_TIME(INVALID_TIME),
        .CACHE_SIZE(CACHE_SIZE),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .TX_DATA_DEPTH(TX_DATA_DEPTH),
        .RX_DATA_DEPTH(RX_DATA_DEPTH),
        .READ_DELAY(1)
    )
    eth_inst(
        .clk(clk),
        .rst(rst),

        .loca_mac(LOCAL_MAC),
        .loca_ip(LOCAL_IP),
        .loca_port(LOCAL_PORT),

        .dst_ip(DST_IP),
        .dst_port(DST_PORT),

        // TX AXIS
        .s_axis_data (s_eth_axis_data),
        .s_axis_valid(s_eth_axis_valid),
        .s_axis_last (s_eth_axis_last),
        .s_axis_ready(s_eth_axis_ready),

        // RX AXIS
        .m_axis_data (m_eth_axis_data),
        .m_axis_valid(m_eth_axis_valid),
        .m_axis_last (m_eth_axis_last),
        .m_axis_ready(m_eth_axis_ready),

        // RGMII 物理接口
        .rgmii_tx_clk (rgmii_tx_clk),
        .rgmii_tx_ctl (rgmii_tx_ctl),
        .rgmii_tx_data(rgmii_tx_data),

        .rgmii_rx_clk (rgmii_rx_clk),
        .rgmii_rx_ctl (rgmii_rx_ctl),
        .rgmii_rx_data(rgmii_rx_data),
        .phy_rst_n(phy_rst_n)
        
    );




    eth2cmd #(
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH         ),
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH         ),
        .DDR_DATA_WIDTH_IN      (DDR_DATA_WIDTH_IN      ),
        .DDR_DATA_WIDTH_OUT     (DDR_DATA_WIDTH_OUT     ),
        .INSTRUCTION_DATA_DEPTH (INSTRUCTION_DATA_DEPTH ),
        .DDR_DATA_DEPTH         (DDR_DATA_DEPTH         )
    )
    eth2cmd(
        .clk(clk),
        .rst(rst),

        .calculate_end(out_calculate_end),
        .calculate_end_receive(out_calculate_end_receive),

        //eth用户数据
        //rx
        .s_eth_axis_data (m_eth_axis_data ) ,
        .s_eth_axis_valid(m_eth_axis_valid) ,
        .s_eth_axis_last (m_eth_axis_last ) ,
        .s_eth_axis_ready(m_eth_axis_ready) , 
        //tx
        .m_eth_axis_data (s_eth_axis_data ) ,
        .m_eth_axis_valid(s_eth_axis_valid) ,
        .m_eth_axis_last (s_eth_axis_last ) ,
        .m_eth_axis_ready(s_eth_axis_ready) ,



        //REG的AXI_lite接口
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready), 
        .m_axi_awaddr (m_axi_awaddr ),

        .m_axi_wvalid (m_axi_wvalid ),
        .m_axi_wready (m_axi_wready ), 
        .m_axi_wdata  (m_axi_wdata  ),
        .m_axi_wstrb  (m_axi_wstrb  ),

        .m_axi_bvalid (m_axi_bvalid ),
        .m_axi_bready (m_axi_bready ),
        .m_axi_bresp  (m_axi_bresp  ),

        .m_axi_arvalid(m_axi_arvalid), 
        .m_axi_arready(m_axi_arready), 
        .m_axi_araddr (m_axi_araddr ), 

        .m_axi_rvalid (m_axi_rvalid ),
        .m_axi_rready (m_axi_rready ), 
        .m_axi_rdata  (m_axi_rdata  ),
        .m_axi_rresp  (m_axi_rresp  ),



        //从DDR拿数据
        .s_ddr_cmd_addr  (s_ddr_cmd_addr  ) ,
        .s_ddr_cmd_len   (s_ddr_cmd_len   ) ,
        .s_ddr_cmd_valid (s_ddr_cmd_valid ) ,
        .s_ddr_cmd_ready (s_ddr_cmd_ready ) ,
        .s_ddr_axis_data (s_ddr_axis_data ) ,
        .s_ddr_axis_keep (s_ddr_axis_keep ) ,
        .s_ddr_axis_valid(s_ddr_axis_valid) ,
        .s_ddr_axis_last (s_ddr_axis_last ) ,
        .s_ddr_axis_ready(s_ddr_axis_ready) ,

        //发送给DDR
        .m_ddr_cmd_addr  (m_ddr_cmd_addr  ) ,
        .m_ddr_cmd_len   (m_ddr_cmd_len   ) ,
        .m_ddr_cmd_valid (m_ddr_cmd_valid ) ,
        .m_ddr_cmd_ready (m_ddr_cmd_ready ) ,
        .m_ddr_axis_data (m_ddr_axis_data ) ,
        .m_ddr_axis_keep (m_ddr_axis_keep ) ,
        .m_ddr_axis_valid(m_ddr_axis_valid) ,
        .m_ddr_axis_last (m_ddr_axis_last ) ,
        .m_ddr_axis_ready(m_ddr_axis_ready) 

    );



    wire [DATA_WIDTH_OUT-1 : 0] m_data ;
    wire                        m_last ;
    wire                        m_valid;
    wire                        m_ready;
    npu_top # (
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        //并行度//
        .CHA_PAR_IN (CHA_PAR_IN ),                          //输入通道并行度
        .CHA_PAR_OUT(CHA_PAR_OUT),                          //输出通道并行度
        .CONV_CHA_PAR_IN (CONV_CHA_PAR_IN ),                //卷积输入通道并行度
        .CONV_CHA_PAR_OUT(CONV_CHA_PAR_OUT),                //卷积输出通道并行度
        //图片数据//
        .MAX_IN_COL (MAX_IN_COL ),                          //输入的IMG的最大列数
        .MAX_IN_ROW (MAX_IN_ROW ),                          //输入的IMG的最大行数
        .MAX_OUT_ROW(MAX_OUT_ROW),                          //输出的IMG的最大行数
        //图片通道//
        .CHA_IMG_IN (CHA_IMG_IN ),                          //输入的IMG的最大通道数
        .CHA_IMG_OUT(CHA_IMG_OUT),                          //输出的IMG的最大通道数
        //数据位宽//
        .INT(INT),                                          //每个数的位宽
        .WEIGHT_LEN(WEIGHT_LEN),   
        .WEIGHT_SUM(WEIGHT_SUM), 
        //偏置位宽//
        .BIAS_NUM(BIAS_NUM),                                //一行拼接的bias个数
        //尺度位宽//
        .SCALE_WIDTH(SCALE_WIDTH),                          //scale的小数位数
        //一行数据的最大字节数//
        .MAX_IN_LEN (MAX_IN_LEN ),                          //此模块所接受的最大字节数  也就是一行*所有输入通道的字节数   不是！最大通道*最大行数=最大长度
        .MAX_OUT_LEN(MAX_OUT_LEN),                          //此模块所接受的最大字节数  也就是一行*所有输出通道的字节数   不是！最大通道*最大行数=最大长度
        .READ_DELAY (READ_DELAY )
    )
    npu_top_inst(
    
        .clk(clk),
        .rst(rst),
    
    
        //REG的传输接口 （AXI_lite）
        .s_axi_awvalid(m_axi_awvalid)  ,
        .s_axi_awready(m_axi_awready)  , 
        .s_axi_awaddr (m_axi_awaddr )  ,

        .s_axi_wvalid (m_axi_wvalid)   ,
        .s_axi_wready (m_axi_wready)   , 
        .s_axi_wdata  (m_axi_wdata )   ,
        .s_axi_wstrb  (m_axi_wstrb )   ,

        .s_axi_bvalid (m_axi_bvalid)   ,
        .s_axi_bready (m_axi_bready)   ,
        .s_axi_bresp  (m_axi_bresp )   ,

        .s_axi_arvalid(m_axi_arvalid)  , 
        .s_axi_arready(m_axi_arready)  , 
        .s_axi_araddr (m_axi_araddr )  ,

        .s_axi_rvalid (m_axi_rvalid)   ,
        .s_axi_rready (m_axi_rready)   , 
        .s_axi_rdata  (m_axi_rdata )   ,
        .s_axi_rresp  (m_axi_rresp )   ,
    
    
        //in的输入
        .s_data_0 (s_data_0 )     ,
        .s_valid_0(s_valid_0)     ,
        .s_last_0 (s_last_0 )     ,
        .s_ready_0(s_ready_0)     , 

        .s_cmd_addr_0 (s_cmd_addr_0 ) ,
        .s_cmd_len_0  (s_cmd_len_0  ) ,
        .s_cmd_valid_0(s_cmd_valid_0) ,
        .s_cmd_ready_0(s_cmd_ready_0) ,
        //1
        .s_data_1 (s_data_1 )     ,
        .s_valid_1(s_valid_1)     ,
        .s_last_1 (s_last_1 )     ,
        .s_ready_1(s_ready_1)     , 

        .s_cmd_addr_1 (s_cmd_addr_1 ) ,
        .s_cmd_len_1  (s_cmd_len_1  ) ,
        .s_cmd_valid_1(s_cmd_valid_1) ,
        .s_cmd_ready_1(s_cmd_ready_1) ,

        //2 para_conv_weight
        .s_data_2 (s_data_2 )     ,
        .s_valid_2(s_valid_2)     ,
        .s_last_2 (s_last_2 )     ,
        .s_ready_2(s_ready_2)     , 

        .s_cmd_addr_2 (s_cmd_addr_2 ) ,
        .s_cmd_len_2  (s_cmd_len_2  ) ,
        .s_cmd_valid_2(s_cmd_valid_2) ,
        .s_cmd_ready_2(s_cmd_ready_2) ,

        //3 para_cat_add_0
        .s_data_3 (s_data_3 )     ,
        .s_valid_3(s_valid_3)     ,
        .s_last_3 (s_last_3 )     ,
        .s_ready_3(s_ready_3)     , 

        .s_cmd_addr_3 (s_cmd_addr_3 ) ,
        .s_cmd_len_3  (s_cmd_len_3  ) ,
        .s_cmd_valid_3(s_cmd_valid_3) ,
        .s_cmd_ready_3(s_cmd_ready_3) ,

        //4 para_cat_add_1
        .s_data_4 (s_data_4 )     ,
        .s_valid_4(s_valid_4)     ,
        .s_last_4 (s_last_4 )     ,
        .s_ready_4(s_ready_4)     , 

        .s_cmd_addr_4 (s_cmd_addr_4 ) ,
        .s_cmd_len_4  (s_cmd_len_4  ) ,
        .s_cmd_valid_4(s_cmd_valid_4) ,
        .s_cmd_ready_4(s_cmd_ready_4) ,

        //out的输出
        .out_m_data (m_data ) ,
        .out_m_last (m_last ) ,
        .out_m_valid(m_valid) ,
        .out_m_ready(m_ready) , 

        .out_m_cmd_addr (out_m_cmd_addr ) ,
        .out_m_cmd_len  (out_m_cmd_len  ) ,
        .out_m_cmd_valid(out_m_cmd_valid) ,
        .out_m_cmd_ready(out_m_cmd_ready) ,

        .out_calculate_end        (out_calculate_end        ),//////////////////
        .out_calculate_end_receive(out_calculate_end_receive)

    );


    


    pipe #(
        .WIDTH(DATA_WIDTH_OUT+1)
    )
    pipe_out(
        .clk(clk),
        .rst(rst),

        .up_valid(m_valid),
        .up_ready(m_ready),
        .data_in ({m_last, m_data}),


        .down_valid(out_m_valid),
        .down_ready(out_m_ready),
        .data_out  ({out_m_last, out_m_data})
    );


endmodule