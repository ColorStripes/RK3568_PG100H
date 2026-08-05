module npu_to_core_cdc_bridge #(
    parameter DATA_WIDTH_IN  = 128,
    parameter DATA_WIDTH_OUT = 128,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
)(
    // ==========================================
    // 1. 全局时钟与复位信号 (高电平有效)
    // ==========================================
    input  wire                              npu_clk,
    input  wire                              npu_rst,   // NPU侧复位 (高电平有效)
    input  wire                              axi_clk,
    input  wire                              axi_rst,   // AXI侧复位 (高电平有效)

    // ==========================================
    // 2. NPU 侧接口 (工作在 npu_clk 时钟域)
    // ==========================================
    // -- Data 通道 0-4 (Core 发给 NPU -> Bridge 输出) --
    output wire [DATA_WIDTH_IN-1:0]          s_data_0,       output wire s_valid_0,       output wire s_last_0,       input  wire s_ready_0,
    output wire [DATA_WIDTH_IN-1:0]          s_data_1,       output wire s_valid_1,       output wire s_last_1,       input  wire s_ready_1,
    output wire [DATA_WIDTH_IN-1:0]          s_data_2,       output wire s_valid_2,       output wire s_last_2,       input  wire s_ready_2,
    output wire [DATA_WIDTH_IN-1:0]          s_data_3,       output wire s_valid_3,       output wire s_last_3,       input  wire s_ready_3,
    output wire [DATA_WIDTH_IN-1:0]          s_data_4,       output wire s_valid_4,       output wire s_last_4,       input  wire s_ready_4,

    // -- Cmd 通道 0-4 (NPU 发给 Core -> Bridge 输入) --
    input  wire [AXI_ADDR_WIDTH-1:0]         s_cmd_addr_0,   input  wire [AXI_DATA_WIDTH-1:0] s_cmd_len_0,   input  wire s_cmd_valid_0,   output wire s_cmd_ready_0,
    input  wire [AXI_ADDR_WIDTH-1:0]         s_cmd_addr_1,   input  wire [AXI_DATA_WIDTH-1:0] s_cmd_len_1,   input  wire s_cmd_valid_1,   output wire s_cmd_ready_1,
    input  wire [AXI_ADDR_WIDTH-1:0]         s_cmd_addr_2,   input  wire [AXI_DATA_WIDTH-1:0] s_cmd_len_2,   input  wire s_cmd_valid_2,   output wire s_cmd_ready_2,
    input  wire [AXI_ADDR_WIDTH-1:0]         s_cmd_addr_3,   input  wire [AXI_DATA_WIDTH-1:0] s_cmd_len_3,   input  wire s_cmd_valid_3,   output wire s_cmd_ready_3,
    input  wire [AXI_ADDR_WIDTH-1:0]         s_cmd_addr_4,   input  wire [AXI_DATA_WIDTH-1:0] s_cmd_len_4,   input  wire s_cmd_valid_4,   output wire s_cmd_ready_4,

    // -- Out 混合通道 (NPU 发给 Core -> Bridge 输入) --
    input  wire [DATA_WIDTH_OUT-1:0]         out_m_data,     input  wire out_m_last,          input  wire out_m_valid,     output wire out_m_ready,
    input  wire [AXI_ADDR_WIDTH-1:0]         out_m_cmd_addr, input  wire [AXI_DATA_WIDTH-1:0] out_m_cmd_len, input  wire out_m_cmd_valid, output wire out_m_cmd_ready,

    // ==========================================
    // 3. AXI Core 侧接口 (工作在 axi_clk 时钟域)
    // ==========================================
    // -- Data 通道 0-4 (Core 发给 NPU -> Bridge 输入) --
    input  wire [DATA_WIDTH_IN-1:0]          cdc_s_data_0,   input  wire cdc_s_valid_0,   input  wire cdc_s_last_0,   output wire cdc_s_ready_0,
    input  wire [DATA_WIDTH_IN-1:0]          cdc_s_data_1,   input  wire cdc_s_valid_1,   input  wire cdc_s_last_1,   output wire cdc_s_ready_1,
    input  wire [DATA_WIDTH_IN-1:0]          cdc_s_data_2,   input  wire cdc_s_valid_2,   input  wire cdc_s_last_2,   output wire cdc_s_ready_2,
    input  wire [DATA_WIDTH_IN-1:0]          cdc_s_data_3,   input  wire cdc_s_valid_3,   input  wire cdc_s_last_3,   output wire cdc_s_ready_3,
    input  wire [DATA_WIDTH_IN-1:0]          cdc_s_data_4,   input  wire cdc_s_valid_4,   input  wire cdc_s_last_4,   output wire cdc_s_ready_4,

    // -- Cmd 通道 0-4 (NPU 发给 Core -> Bridge 输出) --
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_s_cmd_addr_0, output wire [AXI_DATA_WIDTH-1:0] cdc_s_cmd_len_0, output wire cdc_s_cmd_valid_0, input  wire cdc_s_cmd_ready_0,
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_s_cmd_addr_1, output wire [AXI_DATA_WIDTH-1:0] cdc_s_cmd_len_1, output wire cdc_s_cmd_valid_1, input  wire cdc_s_cmd_ready_1,
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_s_cmd_addr_2, output wire [AXI_DATA_WIDTH-1:0] cdc_s_cmd_len_2, output wire cdc_s_cmd_valid_2, input  wire cdc_s_cmd_ready_2,
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_s_cmd_addr_3, output wire [AXI_DATA_WIDTH-1:0] cdc_s_cmd_len_3, output wire cdc_s_cmd_valid_3, input  wire cdc_s_cmd_ready_3,
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_s_cmd_addr_4, output wire [AXI_DATA_WIDTH-1:0] cdc_s_cmd_len_4, output wire cdc_s_cmd_valid_4, input  wire cdc_s_cmd_ready_4,

    // -- Out 混合通道 (NPU 发给 Core -> Bridge 输出) --
    output wire [DATA_WIDTH_OUT-1:0]         cdc_out_m_data,     output wire cdc_out_m_last,          output wire cdc_out_m_valid,     input  wire cdc_out_m_ready,
    output wire [AXI_ADDR_WIDTH-1:0]         cdc_out_m_cmd_addr, output wire [AXI_DATA_WIDTH-1:0] cdc_out_m_cmd_len, output wire cdc_out_m_cmd_valid, input  wire cdc_out_m_cmd_ready
);

    // =========================================================================
    // 实例化区域 1: Data 通道 0-4 
    // 流向: Core(写入) -> NPU(读出)
    // 时钟: wr_clk = axi_clk, rd_clk = npu_clk
    // 复位: wr_rst = axi_rst, rd_rst = npu_rst
    // =========================================================================

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_IN)) inst_data_0 (
        .wr_clk(axi_clk),  .wr_rst(axi_rst),  .wr_data(cdc_s_data_0), .wr_last(cdc_s_last_0), .wr_valid(cdc_s_valid_0), .wr_ready(cdc_s_ready_0),
        .rd_clk(npu_clk),  .rd_rst(npu_rst),  .rd_data(s_data_0),     .rd_last(s_last_0),     .rd_valid(s_valid_0),     .rd_ready(s_ready_0)
    );

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_IN)) inst_data_1 (
        .wr_clk(axi_clk),  .wr_rst(axi_rst),  .wr_data(cdc_s_data_1), .wr_last(cdc_s_last_1), .wr_valid(cdc_s_valid_1), .wr_ready(cdc_s_ready_1),
        .rd_clk(npu_clk),  .rd_rst(npu_rst),  .rd_data(s_data_1),     .rd_last(s_last_1),     .rd_valid(s_valid_1),     .rd_ready(s_ready_1)
    );

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_IN)) inst_data_2 (
        .wr_clk(axi_clk),  .wr_rst(axi_rst),  .wr_data(cdc_s_data_2), .wr_last(cdc_s_last_2), .wr_valid(cdc_s_valid_2), .wr_ready(cdc_s_ready_2),
        .rd_clk(npu_clk),  .rd_rst(npu_rst),  .rd_data(s_data_2),     .rd_last(s_last_2),     .rd_valid(s_valid_2),     .rd_ready(s_ready_2)
    );

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_IN)) inst_data_3 (
        .wr_clk(axi_clk),  .wr_rst(axi_rst),  .wr_data(cdc_s_data_3), .wr_last(cdc_s_last_3), .wr_valid(cdc_s_valid_3), .wr_ready(cdc_s_ready_3),
        .rd_clk(npu_clk),  .rd_rst(npu_rst),  .rd_data(s_data_3),     .rd_last(s_last_3),     .rd_valid(s_valid_3),     .rd_ready(s_ready_3)
    );

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_IN)) inst_data_4 (
        .wr_clk(axi_clk),  .wr_rst(axi_rst),  .wr_data(cdc_s_data_4), .wr_last(cdc_s_last_4), .wr_valid(cdc_s_valid_4), .wr_ready(cdc_s_ready_4),
        .rd_clk(npu_clk),  .rd_rst(npu_rst),  .rd_data(s_data_4),     .rd_last(s_last_4),     .rd_valid(s_valid_4),     .rd_ready(s_ready_4)
    );

    // =========================================================================
    // 实例化区域 2: Cmd 通道 0-4
    // 流向: NPU(写入) -> Core(读出)
    // 时钟: wr_clk = npu_clk, rd_clk = axi_clk
    // 复位: wr_rst = npu_rst, rd_rst = axi_rst
    // =========================================================================

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_cmd_0 (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(s_cmd_addr_0),     .wr_len(s_cmd_len_0),     .wr_valid(s_cmd_valid_0),     .wr_ready(s_cmd_ready_0),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_s_cmd_addr_0), .rd_len(cdc_s_cmd_len_0), .rd_valid(cdc_s_cmd_valid_0), .rd_ready(cdc_s_cmd_ready_0)
    );

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_cmd_1 (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(s_cmd_addr_1),     .wr_len(s_cmd_len_1),     .wr_valid(s_cmd_valid_1),     .wr_ready(s_cmd_ready_1),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_s_cmd_addr_1), .rd_len(cdc_s_cmd_len_1), .rd_valid(cdc_s_cmd_valid_1), .rd_ready(cdc_s_cmd_ready_1)
    );

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_cmd_2 (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(s_cmd_addr_2),     .wr_len(s_cmd_len_2),     .wr_valid(s_cmd_valid_2),     .wr_ready(s_cmd_ready_2),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_s_cmd_addr_2), .rd_len(cdc_s_cmd_len_2), .rd_valid(cdc_s_cmd_valid_2), .rd_ready(cdc_s_cmd_ready_2)
    );

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_cmd_3 (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(s_cmd_addr_3),     .wr_len(s_cmd_len_3),     .wr_valid(s_cmd_valid_3),     .wr_ready(s_cmd_ready_3),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_s_cmd_addr_3), .rd_len(cdc_s_cmd_len_3), .rd_valid(cdc_s_cmd_valid_3), .rd_ready(cdc_s_cmd_ready_3)
    );

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_cmd_4 (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(s_cmd_addr_4),     .wr_len(s_cmd_len_4),     .wr_valid(s_cmd_valid_4),     .wr_ready(s_cmd_ready_4),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_s_cmd_addr_4), .rd_len(cdc_s_cmd_len_4), .rd_valid(cdc_s_cmd_valid_4), .rd_ready(cdc_s_cmd_ready_4)
    );

    // =========================================================================
    // 实例化区域 3: Out 通道 (Data & Cmd)
    // 流向: NPU(写入) -> Core(读出)
    // 时钟: wr_clk = npu_clk, rd_clk = axi_clk
    // 复位: wr_rst = npu_rst, rd_rst = axi_rst
    // =========================================================================

    cdc_data_channel #(.DATA_WIDTH(DATA_WIDTH_OUT)) inst_out_data (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_data(out_m_data),     .wr_last(out_m_last),     .wr_valid(out_m_valid),     .wr_ready(out_m_ready),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_data(cdc_out_m_data), .rd_last(cdc_out_m_last), .rd_valid(cdc_out_m_valid), .rd_ready(cdc_out_m_ready)
    );

    cdc_cmd_channel #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .LEN_WIDTH(AXI_DATA_WIDTH)) inst_out_cmd (
        .wr_clk(npu_clk),  .wr_rst(npu_rst),  .wr_addr(out_m_cmd_addr),     .wr_len(out_m_cmd_len),     .wr_valid(out_m_cmd_valid),     .wr_ready(out_m_cmd_ready),
        .rd_clk(axi_clk),  .rd_rst(axi_rst),  .rd_addr(cdc_out_m_cmd_addr), .rd_len(cdc_out_m_cmd_len), .rd_valid(cdc_out_m_cmd_valid), .rd_ready(cdc_out_m_cmd_ready)
    );

endmodule