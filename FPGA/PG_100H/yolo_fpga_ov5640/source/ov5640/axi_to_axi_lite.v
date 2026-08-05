`timescale 1ns / 1ps

module axi_to_axi_lite #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,  // AXI-Lite 规定为 32 或 64
    parameter AXI_ID_LEN      = 4,
    parameter AXI_DATA_LEN    = 128
)(

    input wire axi_clk,
    input wire axi_rst,
    // ==========================================
    // 标准 AXI Slave 接口 (128-bit)
    // ==========================================
    input  wire [AXI_ID_LEN-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire [7:0]                 s_axi_awlen,     // 被忽略
    input  wire [2:0]                 s_axi_awsize,    // 被忽略
    input  wire [1:0]                 s_axi_awburst,   // 被忽略
    input  wire [1:0]                 s_axi_awlock,    // 被忽略
    input  wire [3:0]                 s_axi_awcache,   // 被忽略
    input  wire [2:0]                 s_axi_awprot,    // 被忽略
    input  wire [3:0]                 s_axi_awqos,     // 被忽略
    input  wire [3:0]                 s_axi_awregion,  // 被忽略
    input  wire                       s_axi_awvalid,
    output wire                       s_axi_awready,

    input  wire [AXI_DATA_LEN-1:0]    s_axi_wdata,
    input  wire [AXI_DATA_LEN/8-1:0]  s_axi_wstrb,
    input  wire                       s_axi_wlast,     // 被忽略
    input  wire                       s_axi_wvalid,
    output wire                       s_axi_wready,

    output wire [AXI_ID_LEN-1:0]      s_axi_bid,
    output wire [1:0]                 s_axi_bresp,
    output wire                       s_axi_bvalid,
    input  wire                       s_axi_bready,

    input  wire [AXI_ID_LEN-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire [7:0]                 s_axi_arlen,     // 被忽略
    input  wire [2:0]                 s_axi_arsize,    // 被忽略
    input  wire [1:0]                 s_axi_arburst,   // 被忽略
    input  wire [1:0]                 s_axi_arlock,    // 被忽略
    input  wire [3:0]                 s_axi_arcache,   // 被忽略
    input  wire [2:0]                 s_axi_arprot,    // 被忽略
    input  wire [3:0]                 s_axi_arqos,     // 被忽略
    input  wire [3:0]                 s_axi_arregion,  // 被忽略
    input  wire                       s_axi_arvalid,
    output wire                       s_axi_arready,

    output wire [AXI_ID_LEN-1:0]      s_axi_rid,
    output wire [AXI_DATA_LEN-1:0]    s_axi_rdata,
    output wire [1:0]                 s_axi_rresp,
    output wire                       s_axi_rlast,
    output wire                       s_axi_rvalid,
    input  wire                       s_axi_rready,

    // ==========================================
    // AXI-Lite Master 接口 (32-bit)
    // ==========================================
    output wire [ADDR_WIDTH-1:0]      m_axil_awaddr,
    output wire                       m_axil_awvalid,
    input  wire                       m_axil_awready,

    output wire [DATA_WIDTH-1:0]      m_axil_wdata,
    output wire [DATA_WIDTH/8-1:0]    m_axil_wstrb,
    output wire                       m_axil_wvalid,
    input  wire                       m_axil_wready,

    input  wire [1:0]                 m_axil_bresp,
    input  wire                       m_axil_bvalid,
    output wire                       m_axil_bready,

    output wire [ADDR_WIDTH-1:0]      m_axil_araddr,
    output wire                       m_axil_arvalid,
    input  wire                       m_axil_arready,

    input  wire [DATA_WIDTH-1:0]      m_axil_rdata,
    input  wire [1:0]                 m_axil_rresp,
    input  wire                       m_axil_rvalid,
    output wire                       m_axil_rready
);

    // =========================================================
    // 写通道 (Write Channels)
    // =========================================================

    // 写地址通道：直接透传（AW 通道在 AXI-Lite 中为单拍，地址在握手时即被采样）
    assign m_axil_awvalid  = s_axi_awvalid;
    assign s_axi_awready   = m_axil_awready;
    assign m_axil_awaddr   = s_axi_awaddr;

    assign m_axil_wvalid  = s_axi_wvalid;
    assign s_axi_wready   = m_axil_wready;

    // 【暴力截断】永远只取 128-bit 数据的最低 32 位和最低 4 位掩码
    assign m_axil_wdata   = s_axi_wdata[31:0];
    assign m_axil_wstrb   = s_axi_wstrb;

    assign s_axi_bvalid   = m_axil_bvalid;
    assign m_axil_bready  = s_axi_bready;
    assign s_axi_bresp    = m_axil_bresp;

    // 写响应 ID：在 AW 握手成功时寄存.awid，防止响应返回时.awid 已变化
    reg [AXI_ID_LEN-1:0] bid_reg;
    always @(posedge axi_clk) begin
        if (axi_rst)
            bid_reg <= {AXI_ID_LEN{1'b0}};
        else if (s_axi_awvalid && s_axi_awready)
            bid_reg <= s_axi_awid;
    end
    assign s_axi_bid = bid_reg;


    // =========================================================
    // 读通道 (Read Channels)
    // =========================================================

    // 读地址通道：直接透传（AR 通道在 AXI-Lite 中为单拍，地址在握手时即被采样）
    assign m_axil_arvalid  = s_axi_arvalid;
    assign s_axi_arready   = m_axil_arready;
    assign m_axil_araddr   = s_axi_araddr;

    assign s_axi_rvalid   = m_axil_rvalid;
    assign m_axil_rready  = s_axi_rready;
    assign s_axi_rresp    = m_axil_rresp;

    // 读回的数据放在最低 32 位，高 96 位强制补 0
    assign s_axi_rdata    = {96'b0, m_axil_rdata};

    // AXI-Lite 只能单拍传输，所以最后一次传输标志 (RLAST) 永远为 1
    assign s_axi_rlast    = 1'b1;

    // 读响应 ID：在 AR 握手成功时寄存.arid，防止响应返回时.arid 已变化
    reg [AXI_ID_LEN-1:0] rid_reg;
    always @(posedge axi_clk) begin
        if (axi_rst)
            rid_reg <= {AXI_ID_LEN{1'b0}};
        else if (s_axi_arvalid && s_axi_arready)
            rid_reg <= s_axi_arid;
    end
    assign s_axi_rid = rid_reg;

endmodule