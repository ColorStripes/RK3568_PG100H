module npu_ctl #(
    parameter AXI_DATA_WIDTH = 128,
              AXI_ADDR_WIDTH = 32,

    parameter INSTRUCTION_NUM = 3100,          //缓存的指令数
              INSTRUCTION_WIDTH = 32,

    parameter NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER + 1)
)(
    // 全局时钟与复位
    input  wire                              axi_clk,
    input  wire                              axi_rst,

    // AXI 写地址通道 (AW)
    input  wire [AXI_ADDR_WIDTH-1 : 0]       s_axi_awaddr,
    input  wire [7 : 0]                      s_axi_awlen,    // 突发长度，支持 AXI4
    input  wire [2 : 0]                      s_axi_awsize,   // 突发大小
    input  wire [1 : 0]                      s_axi_awburst,  // 突发类型
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,

    // AXI 写数据通道 (W)
    input  wire [AXI_DATA_WIDTH-1 : 0]       s_axi_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb,    // 字节掩码
    input  wire                              s_axi_wlast,    // 突发的最后一个数据标志
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,

    // AXI 写响应通道 (B)
    output wire [1 : 0]                      s_axi_bresp,
    output wire                              s_axi_bvalid,
    input  wire                              s_axi_bready,


    ////////////////////////////////////////////////////////////
    //用户逻辑
    input                              npu_clk,
    input                              npu_rst,

    //REG的传输接口 （AXI_lite）
    output                             m_axi_awvalid,
    input                              m_axi_awready, 
    output [31 : 0]                    m_axi_awaddr ,

    output                             m_axi_wvalid,
    input                              m_axi_wready, 
    output [31 : 0]                    m_axi_wdata ,
    output [3 : 0]                     m_axi_wstrb ,
 
    input                              m_axi_bvalid,
    output                             m_axi_bready,
    input   [1 : 0]                    m_axi_bresp ,

    output                             m_axi_arvalid, 
    input                              m_axi_arready, 
    output  [31 : 0]                   m_axi_araddr,
 
 
    input                              m_axi_rvalid,
    output                             m_axi_rready, 
    input   [31 : 0]                   m_axi_rdata ,
    input   [1 : 0]                    m_axi_rresp ,


    input                       calculate_end        ,
    output                      calculate_end_receive,

    output                      npu_req         , 
    input                       npu_req_receive    
);



wire [31 : 0]               m_npu_instruction      ;
wire                        m_npu_start            ;
wire                        m_almost_empty         ;
wire                        m_npu_instruction_ren  ;
wire                        m_npu_instruction_rewind;

wire [LAYER_WIDTH-1 : 0]    m_npu_layer;   

pcie_npu #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),

    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .INSTRUCTION_NUM(INSTRUCTION_NUM),

    .NPU_LAYER(NPU_LAYER)
)
pcie_npu(
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


    .m_npu_start              (m_npu_start              ),
    .m_npu_instruction        (m_npu_instruction        ),
    .m_almost_empty           (m_almost_empty           ),
    .m_npu_instruction_ren    (m_npu_instruction_ren    ),
    .m_npu_instruction_rewind (m_npu_instruction_rewind ),

    .m_npu_layer(m_npu_layer) ,


    .calculate_end        (calculate_end        ),
    .calculate_end_receive(calculate_end_receive),


    .npu_req        (npu_req         ), 
    .npu_req_receive(npu_req_receive )          
);






instruction_buf #(
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH),
    .NPU_LAYER(NPU_LAYER)
)
instruction_buf(
    

    .clk(npu_clk),
    .rst(npu_rst),

    .calculate_end        (calculate_end        ),
    .calculate_end_receive(calculate_end_receive),

    //instruction
    .s_npu_start              (m_npu_start              ),
    .s_npu_instruction        (m_npu_instruction        ),
    .s_almost_empty           (m_almost_empty           ),
    .s_npu_instruction_ren    (m_npu_instruction_ren    ),
    .s_npu_instruction_rewind (m_npu_instruction_rewind ),

    .npu_layer(m_npu_layer),

    //REG的传输接口 （AXI_lite）
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready), 
    .m_axi_awaddr (m_axi_awaddr ),


    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready), 
    .m_axi_wdata (m_axi_wdata ),
    .m_axi_wstrb (m_axi_wstrb ),
 
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_bresp (m_axi_bresp ),

    .m_axi_arvalid(m_axi_arvalid), 
    .m_axi_arready(m_axi_arready), 
    .m_axi_araddr (m_axi_araddr ),
 
 
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready), 
    .m_axi_rdata (m_axi_rdata ),
    .m_axi_rresp (m_axi_rresp )   
);



endmodule