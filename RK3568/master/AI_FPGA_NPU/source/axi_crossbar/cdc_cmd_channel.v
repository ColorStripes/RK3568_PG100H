// 处理携带 valid, ready, addr, len 的命令跨时钟域
module cdc_cmd_channel #(
    parameter ADDR_WIDTH = 32,
    parameter LEN_WIDTH  = 32
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [LEN_WIDTH-1:0]  wr_len,
    input  wire                  wr_valid,
    output wire                  wr_ready,

    input  wire                  rd_clk,
    input  wire                  rd_rst,
    output wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [LEN_WIDTH-1:0]  rd_len,
    output wire                  rd_valid,
    input  wire                  rd_ready
);
    // 将 addr 和 len 拼接打包
    wire [ADDR_WIDTH+LEN_WIDTH-1:0] wr_payload = {wr_len, wr_addr};
    wire [ADDR_WIDTH+LEN_WIDTH-1:0] rd_payload;
    assign {rd_len, rd_addr} = rd_payload;

    axis_async_fifo #(
        .DEPTH(16),
        .DATA_WIDTH(ADDR_WIDTH + LEN_WIDTH), 
        .KEEP_ENABLE(0), .LAST_ENABLE(0), .ID_ENABLE(0), .DEST_ENABLE(0), .USER_ENABLE(0)
    ) fifo_inst (
        .s_clk(wr_clk), .s_rst(wr_rst),
        .s_axis_tdata(wr_payload), .s_axis_tvalid(wr_valid), .s_axis_tready(wr_ready),
        .m_clk(rd_clk), .m_rst(rd_rst),
        .m_axis_tdata(rd_payload), .m_axis_tvalid(rd_valid), .m_axis_tready(rd_ready)
    );
endmodule