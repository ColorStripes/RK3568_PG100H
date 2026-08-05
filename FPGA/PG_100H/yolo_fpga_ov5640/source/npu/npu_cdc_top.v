`include "npu_top/config.v"
module npu_cdc_top #(
    //eth_cmd
    parameter AXI_DATA_WIDTH         = 32,
              AXI_ADDR_WIDTH         = 32,
              DDR_DATA_WIDTH_IN      = 128,          //发送给DDR
              DDR_DATA_WIDTH_OUT     = 128,          //从DDR读出
              INSTRUCTION_DATA_DEPTH = 3101,
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

    input                                    npu_clk,
    input                                    npu_rst,
 
    input  wire                              axi_clk,
    input  wire                              axi_rst,
    ///////////// NPU_CTL ///////////////////////////////////
    // AXI 写地址通道 (AW)
    input  wire [DDR_DATA_WIDTH_IN-1 : 0]       s_axi_awaddr,
    input  wire [7 : 0]                         s_axi_awlen,    // 突发长度，支持 AXI4
    input  wire [2 : 0]                         s_axi_awsize,   // 突发大小
    input  wire [1 : 0]                         s_axi_awburst,  // 突发类型
    input  wire                                 s_axi_awvalid,
    output wire                                 s_axi_awready,
    // AXI 写数据通道 (W)
    input  wire [DDR_DATA_WIDTH_IN-1 : 0]       s_axi_wdata,
    input  wire [(DDR_DATA_WIDTH_IN/8)-1:0]     s_axi_wstrb,    // 字节掩码
    input  wire                                 s_axi_wlast,    // 突发的最后一个数据标志
    input  wire                                 s_axi_wvalid,
    output wire                                 s_axi_wready,
    // AXI 写响应通道 (B)
    output wire [1 : 0]                         s_axi_bresp,
    output wire                                 s_axi_bvalid,
    input  wire                                 s_axi_bready,

    output                                      npu_req         , 
    input                                       npu_req_receive ,   

    ///////////// NPU_TOP ///////////////////////////////////
    //CMD_S2MM CMDMM2S接口
    //in的输入
    input  wire [DATA_WIDTH_IN-1 : 0]   cdc_s_data_0      ,
    input  wire                         cdc_s_valid_0     ,
    input  wire                         cdc_s_last_0      ,
    output wire                         cdc_s_ready_0     , 

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_0  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_s_cmd_len_0   ,
    output wire                         cdc_s_cmd_valid_0 ,
    input  wire                         cdc_s_cmd_ready_0 ,
    //1
    input  wire [DATA_WIDTH_IN-1 : 0]   cdc_s_data_1      ,
    input  wire                         cdc_s_valid_1     ,
    input  wire                         cdc_s_last_1      ,
    output wire                         cdc_s_ready_1     ,

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_1  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_s_cmd_len_1   ,
    output wire                         cdc_s_cmd_valid_1 ,
    input  wire                         cdc_s_cmd_ready_1 ,

    //2
    input  wire [DATA_WIDTH_IN-1 : 0]   cdc_s_data_2      ,
    input  wire                         cdc_s_valid_2     ,
    input  wire                         cdc_s_last_2      ,
    output wire                         cdc_s_ready_2     ,

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_2  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_s_cmd_len_2   ,
    output wire                         cdc_s_cmd_valid_2 ,
    input  wire                         cdc_s_cmd_ready_2 ,

    //3
    input  wire [DATA_WIDTH_IN-1 : 0]   cdc_s_data_3      ,
    input  wire                         cdc_s_valid_3     ,
    input  wire                         cdc_s_last_3      ,
    output wire                         cdc_s_ready_3     , 

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_3  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_s_cmd_len_3   ,
    output wire                         cdc_s_cmd_valid_3 ,
    input  wire                         cdc_s_cmd_ready_3 ,

    //4
    input  wire [DATA_WIDTH_IN-1 : 0]   cdc_s_data_4      ,
    input  wire                         cdc_s_valid_4     ,
    input  wire                         cdc_s_last_4      ,
    output wire                         cdc_s_ready_4     , 

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_s_cmd_addr_4  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_s_cmd_len_4   ,
    output wire                         cdc_s_cmd_valid_4 ,
    input  wire                         cdc_s_cmd_ready_4 ,

    //out的输出
    output wire [DATA_WIDTH_OUT-1 : 0]  cdc_out_m_data      ,
    output wire                         cdc_out_m_last      ,
    output wire                         cdc_out_m_valid     ,
    input  wire                         cdc_out_m_ready     , 

    output wire [AXI_ADDR_WIDTH-1 : 0]  cdc_out_m_cmd_addr  ,
    output wire [AXI_DATA_WIDTH-1 : 0]  cdc_out_m_cmd_len   ,
    output wire                         cdc_out_m_cmd_valid ,
    input  wire                         cdc_out_m_cmd_ready 

);















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
    
    
    



npu_to_core_cdc_bridge #(
    .DATA_WIDTH_IN (DATA_WIDTH_IN ),
    .DATA_WIDTH_OUT(DATA_WIDTH_OUT),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
)
npu_to_core_cdc_bridge (
    // ==========================================
    // 1. 全局时钟与复位信号 (高电平有效)
    // ==========================================
    .npu_clk(npu_clk),
    .npu_rst(npu_rst),   // NPU侧复位 (高电平有效)
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),   // AXI侧复位 (高电平有效)

    // ==========================================
    // 2. NPU 侧接口 (工作在 npu_clk 时钟域)
    // ==========================================
    // -- Data 通道 0-4 (Core 发给 NPU -> Bridge 输出) --
    .s_data_0(s_data_0),       .s_valid_0(s_valid_0),       .s_last_0(s_last_0),       .s_ready_0(s_ready_0),
    .s_data_1(s_data_1),       .s_valid_1(s_valid_1),       .s_last_1(s_last_1),       .s_ready_1(s_ready_1),
    .s_data_2(s_data_2),       .s_valid_2(s_valid_2),       .s_last_2(s_last_2),       .s_ready_2(s_ready_2),
    .s_data_3(s_data_3),       .s_valid_3(s_valid_3),       .s_last_3(s_last_3),       .s_ready_3(s_ready_3),
    .s_data_4(s_data_4),       .s_valid_4(s_valid_4),       .s_last_4(s_last_4),       .s_ready_4(s_ready_4),

    // -- Cmd 通道 0-4 (NPU 发给 Core -> Bridge 输入) --
    .s_cmd_addr_0(s_cmd_addr_0), .s_cmd_len_0(s_cmd_len_0), .s_cmd_valid_0(s_cmd_valid_0), .s_cmd_ready_0(s_cmd_ready_0),
    .s_cmd_addr_1(s_cmd_addr_1), .s_cmd_len_1(s_cmd_len_1), .s_cmd_valid_1(s_cmd_valid_1), .s_cmd_ready_1(s_cmd_ready_1),
    .s_cmd_addr_2(s_cmd_addr_2), .s_cmd_len_2(s_cmd_len_2), .s_cmd_valid_2(s_cmd_valid_2), .s_cmd_ready_2(s_cmd_ready_2),
    .s_cmd_addr_3(s_cmd_addr_3), .s_cmd_len_3(s_cmd_len_3), .s_cmd_valid_3(s_cmd_valid_3), .s_cmd_ready_3(s_cmd_ready_3),
    .s_cmd_addr_4(s_cmd_addr_4), .s_cmd_len_4(s_cmd_len_4), .s_cmd_valid_4(s_cmd_valid_4), .s_cmd_ready_4(s_cmd_ready_4),

    // -- Out 混合通道 (NPU 发给 Core -> Bridge 输入) --
    .out_m_data(out_m_data),         .out_m_last(out_m_last),         .out_m_valid(out_m_valid),         .out_m_ready(out_m_ready),
    .out_m_cmd_addr(out_m_cmd_addr), .out_m_cmd_len(out_m_cmd_len),   .out_m_cmd_valid(out_m_cmd_valid), .out_m_cmd_ready(out_m_cmd_ready),

    // ==========================================
    // 3. AXI Core 侧接口 (工作在 axi_clk 时钟域)
    // ==========================================
    // -- Data 通道 0-4 (Core 发给 NPU -> Bridge 输入) --
    .cdc_s_data_0(cdc_s_data_0), .cdc_s_valid_0(cdc_s_valid_0), .cdc_s_last_0(cdc_s_last_0), .cdc_s_ready_0(cdc_s_ready_0),
    .cdc_s_data_1(cdc_s_data_1), .cdc_s_valid_1(cdc_s_valid_1), .cdc_s_last_1(cdc_s_last_1), .cdc_s_ready_1(cdc_s_ready_1),
    .cdc_s_data_2(cdc_s_data_2), .cdc_s_valid_2(cdc_s_valid_2), .cdc_s_last_2(cdc_s_last_2), .cdc_s_ready_2(cdc_s_ready_2),
    .cdc_s_data_3(cdc_s_data_3), .cdc_s_valid_3(cdc_s_valid_3), .cdc_s_last_3(cdc_s_last_3), .cdc_s_ready_3(cdc_s_ready_3),
    .cdc_s_data_4(cdc_s_data_4), .cdc_s_valid_4(cdc_s_valid_4), .cdc_s_last_4(cdc_s_last_4), .cdc_s_ready_4(cdc_s_ready_4),

    // -- Cmd 通道 0-4 (NPU 发给 Core -> Bridge 输出) --
    .cdc_s_cmd_addr_0(cdc_s_cmd_addr_0), .cdc_s_cmd_len_0(cdc_s_cmd_len_0), .cdc_s_cmd_valid_0(cdc_s_cmd_valid_0), .cdc_s_cmd_ready_0(cdc_s_cmd_ready_0),
    .cdc_s_cmd_addr_1(cdc_s_cmd_addr_1), .cdc_s_cmd_len_1(cdc_s_cmd_len_1), .cdc_s_cmd_valid_1(cdc_s_cmd_valid_1), .cdc_s_cmd_ready_1(cdc_s_cmd_ready_1),
    .cdc_s_cmd_addr_2(cdc_s_cmd_addr_2), .cdc_s_cmd_len_2(cdc_s_cmd_len_2), .cdc_s_cmd_valid_2(cdc_s_cmd_valid_2), .cdc_s_cmd_ready_2(cdc_s_cmd_ready_2),
    .cdc_s_cmd_addr_3(cdc_s_cmd_addr_3), .cdc_s_cmd_len_3(cdc_s_cmd_len_3), .cdc_s_cmd_valid_3(cdc_s_cmd_valid_3), .cdc_s_cmd_ready_3(cdc_s_cmd_ready_3),
    .cdc_s_cmd_addr_4(cdc_s_cmd_addr_4), .cdc_s_cmd_len_4(cdc_s_cmd_len_4), .cdc_s_cmd_valid_4(cdc_s_cmd_valid_4), .cdc_s_cmd_ready_4(cdc_s_cmd_ready_4),

    // -- Out 混合通道 (NPU 发给 Core -> Bridge 输出) --
    .cdc_out_m_data(cdc_out_m_data),         .cdc_out_m_last(cdc_out_m_last),         .cdc_out_m_valid(cdc_out_m_valid),         .cdc_out_m_ready(cdc_out_m_ready),
    .cdc_out_m_cmd_addr(cdc_out_m_cmd_addr), .cdc_out_m_cmd_len(cdc_out_m_cmd_len),   .cdc_out_m_cmd_valid(cdc_out_m_cmd_valid), .cdc_out_m_cmd_ready(cdc_out_m_cmd_ready)
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




    npu_ctl #(
        .AXI_DATA_WIDTH(DDR_DATA_WIDTH_IN),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .INSTRUCTION_DATA_DEPTH(INSTRUCTION_DATA_DEPTH),          //缓存的指令数
        .NPU_LAYER(88)
    )
    npu_ctl(
        // 全局时钟与复位
        .axi_clk(axi_clk),
        .axi_rst(axi_rst),

        // AXI 写地址通道 (AW)
        .s_axi_awaddr (s_axi_awaddr ),
        .s_axi_awlen  (s_axi_awlen  ),    // 突发长度，支持 AXI4
        .s_axi_awsize (s_axi_awsize ),   // 突发大小
        .s_axi_awburst(s_axi_awburst),  // 突发类型
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        // AXI 写数据通道 (W)
        .s_axi_wdata (s_axi_wdata ),
        .s_axi_wstrb (s_axi_wstrb ),    // 字节掩码
        .s_axi_wlast (s_axi_wlast ),    // 突发的最后一个数据标志
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        // AXI 写响应通道 (B)
        .s_axi_bresp (s_axi_bresp ),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),


        ////////////////////////////////////////////////////////////
        //用户逻辑
        .npu_clk(npu_clk),
        .npu_rst(npu_rst),

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


        .calculate_end        (out_calculate_end        ),
        .calculate_end_receive(out_calculate_end_receive),   

        .npu_req        (npu_req        ) , 
        .npu_req_receive(npu_req_receive) 


    );




    wire [DATA_WIDTH_OUT-1 : 0] m_data ;
    wire                        m_last ;
    wire                        m_valid;
    wire                        m_ready;

    // ==========================================
    // NPU 时钟门控：解决 150MHz NPU 导致 OV5640 I2C 初始化失败的问题
    // ==========================================
    // 根因：npu_clk(150MHz) 与 OV5640 共用同一颗 PLL(ov5640_clk)，
    // NPU 大量 DSP/BRAM 在 150MHz 下翻转产生电源噪声，通过 PLL 耦合
    // 到 clk_50m，导致 OV5640 I2C 时序失败。
    // 方案：上电后延迟 ~50ms 再给 npu_top 时钟，让 OV5640 I2C 先完成初始化。
    // ==========================================
    localparam NPU_CLK_DELAY_CYCLES = 24'd7_500_000; // 50ms @ 150MHz

    reg  [23:0] npu_clk_delay_cnt;
    reg         npu_clk_en_req;
    reg         npu_clk_en_latch;
    wire        npu_clk_gated;

    // 延迟计数器：在 npu_rst 释放后计数 NPU_CLK_DELAY_CYCLES 个周期
    always @(posedge npu_clk or posedge npu_rst) begin
        if (npu_rst) begin
            npu_clk_delay_cnt <= 24'd0;
            npu_clk_en_req    <= 1'b0;
        end
        else if (!npu_clk_en_req) begin
            if (npu_clk_delay_cnt < NPU_CLK_DELAY_CYCLES)
                npu_clk_delay_cnt <= npu_clk_delay_cnt + 1'b1;
            else
                npu_clk_en_req <= 1'b1;
        end
    end

    // 下降沿锁存：标准无毛刺时钟门控 (glitch-free clock gating)
    always @(negedge npu_clk or posedge npu_rst) begin
        if (npu_rst)
            npu_clk_en_latch <= 1'b0;
        else
            npu_clk_en_latch <= npu_clk_en_req;
    end

    GTP_CLKBUFGCE #(
        .DEFAULT_VALUE(1'b0),
        .SIM_DEVICE("LOGOS2")
    ) u_bufgce_npu (
        .CLKOUT(npu_clk_gated),
        .CE    (npu_clk_en_latch),
        .CLKIN (npu_clk)
    );

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
    
        .clk(npu_clk_gated),
        .rst(npu_rst),
    
    
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
        .clk(npu_clk),
        .rst(npu_rst),

        .up_valid(m_valid),
        .up_ready(m_ready),
        .data_in ({m_last, m_data}),


        .down_valid(out_m_valid),
        .down_ready(out_m_ready),
        .data_out  ({out_m_last, out_m_data})
    );


endmodule