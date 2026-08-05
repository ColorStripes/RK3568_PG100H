`timescale 1ns / 1ps

module axi_lite_to_axi #(
    parameter ADDR_WIDTH = 32,
    // AXI-Lite 协议规定数据位宽只能是 32 或 64
    parameter DATA_WIDTH = 32, 
    // 标准 AXI 需要的 ID 位宽
    parameter AXI_ID_LEN      = 4 ,
              AXI_DATA_LEN    = 128,
              AXI_DATA_SIZE   = $clog2(AXI_DATA_LEN/8)	   
)(


    // ==========================================
    // 接口 1: AXI-Lite Slave Interface (输入端)
    // ==========================================
    // 写地址通道 (AW)
    input  wire [ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire                     s_axil_awvalid,
    output wire                     s_axil_awready,
    // 写数据通道 (W)
    input  wire [DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axil_wstrb,
    input  wire                     s_axil_wvalid,
    output wire                     s_axil_wready,
    // 写响应通道 (B)
    output wire [1:0]               s_axil_bresp,
    output wire                     s_axil_bvalid,
    input  wire                     s_axil_bready,
    // 读地址通道 (AR)
    input  wire [ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire                     s_axil_arvalid,
    output wire                     s_axil_arready,
    // 读数据通道 (R)
    output wire [DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]               s_axil_rresp,
    output wire                     s_axil_rvalid,
    input  wire                     s_axil_rready,

    // ==========================================
    // 接口 2: Standard AXI4 Master Interface (输出端)
    // ==========================================
    // 写地址通道 (AW)
    output wire [AXI_ID_LEN-1:0]     m_axi_awid,
    output wire [ADDR_WIDTH-1:0]     m_axi_awaddr,
    output wire [3:0]                m_axi_awlen,
    output wire [2:0]                m_axi_awsize,
    output wire [1:0]                m_axi_awburst,
    output wire                      m_axi_awlock,
    output wire [3:0]                m_axi_awcache,
    output wire [2:0]                m_axi_awprot,
    output wire [3:0]                m_axi_awqos,
    output wire [3:0]                m_axi_awregion,
    output wire                      m_axi_awvalid,
    input  wire                      m_axi_awready,
    // 写数据通道 (W)
    output wire [AXI_DATA_LEN-1:0]   m_axi_wdata,
    output wire [AXI_DATA_LEN/8-1:0] m_axi_wstrb,
    output wire                      m_axi_wlast,
    output wire                      m_axi_wvalid,
    input  wire                      m_axi_wready,
    // 写响应通道 (B)
    input  wire [AXI_ID_LEN-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,
    // 读地址通道 (AR)
    output wire [AXI_ID_LEN-1:0]      m_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [3:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arlock,
    output wire [3:0]               m_axi_arcache,
    output wire [2:0]               m_axi_arprot,
    output wire [3:0]               m_axi_arqos,
    output wire [3:0]               m_axi_arregion,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    // 读数据通道 (R)
    input  wire [AXI_ID_LEN-1:0]      m_axi_rid,
    input  wire [AXI_DATA_LEN-1:0]  m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);


    // ==========================================
    // 1. 握手和数据信号直接透传 (Pass-through)
    // ==========================================
    // AW 通道
    assign m_axi_awaddr   = s_axil_awaddr;
    assign m_axi_awprot   = 3'b000;
    assign m_axi_awvalid  = s_axil_awvalid;
    assign s_axil_awready = m_axi_awready;

    // W 通道
    assign m_axi_wdata    = s_axil_wdata;
    assign m_axi_wstrb    = s_axil_wstrb;
    assign m_axi_wvalid   = s_axil_wvalid;
    assign s_axil_wready  = m_axi_wready;

    // B 通道
    assign s_axil_bresp   = m_axi_bresp;
    assign s_axil_bvalid  = m_axi_bvalid;
    assign m_axi_bready   = s_axil_bready;

    // AR 通道
    assign m_axi_araddr   = s_axil_araddr;
    assign m_axi_arprot   = 3'b000;
    assign m_axi_arvalid  = s_axil_arvalid;
    assign s_axil_arready = m_axi_arready;

    // R 通道
    assign s_axil_rdata   = m_axi_rdata;
    assign s_axil_rresp   = m_axi_rresp;
    assign s_axil_rvalid  = m_axi_rvalid;
    assign m_axi_rready   = s_axil_rready;

    // ==========================================
    // 2. AXI4 专有控制信号硬连线 (Tie-off)
    // ==========================================
    // AXI-Lite 不支持多 ID，全部赋 0
    assign m_axi_awid     = {AXI_ID_LEN{1'b0}};
    assign m_axi_arid     = {AXI_ID_LEN{1'b0}};

    // 突发长度为 1 拍 (AWLEN/ARLEN 在 AXI4 中 0 代表 1 拍传输)
    assign m_axi_awlen    = 4'd0;
    assign m_axi_arlen    = 4'd0;

    // 突发大小 (根据总线宽度自适应)
    assign m_axi_awsize   = AXI_DATA_SIZE;
    assign m_axi_arsize   = AXI_DATA_SIZE;

    // 突发类型设为 INCR (2'b01, 最常见的递增突发)
    assign m_axi_awburst  = 2'b01;
    assign m_axi_arburst  = 2'b01;

    // 由于永远只有 1 拍数据，WLAST 永远拉高
    assign m_axi_wlast    = 1'b1;

    // 禁用锁定访问、区域、QoS
    assign m_axi_awlock   = 1'b0;
    assign m_axi_arlock   = 1'b0;
    assign m_axi_awregion = 4'd0;
    assign m_axi_arregion = 4'd0;
    assign m_axi_awqos    = 4'd0;
    assign m_axi_arqos    = 4'd0;

    // 缓存属性：常规的 Non-cacheable, Non-bufferable (根据系统需要也可以改为 4'b0011)
    assign m_axi_awcache  = 4'b0000;
    assign m_axi_arcache  = 4'b0000;

    // 接收到的 B 和 R 通道的附加信号直接丢弃 (悬空不接)
    // m_axi_bid
    // m_axi_rid
    // m_axi_rlast

endmodule