// 处理携带 valid, ready, data, last 的流数据跨时钟域
module cdc_data_channel #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  wr_last,
    input  wire                  wr_valid,
    output wire                  wr_ready,

    input  wire                  rd_clk,
    input  wire                  rd_rst,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_last,
    output wire                  rd_valid,
    input  wire                  rd_ready
);
    // 将 last 和 data 拼接打包
    wire [DATA_WIDTH:0] wr_payload = {wr_last, wr_data};
    wire [DATA_WIDTH:0] rd_payload;
    assign {rd_last, rd_data} = rd_payload;

    axis_async_fifo #(
        .DEPTH(16),
        .DATA_WIDTH(DATA_WIDTH + 1), // data + 1bit last
        .KEEP_ENABLE(0), .LAST_ENABLE(0), .ID_ENABLE(0), .DEST_ENABLE(0), .USER_ENABLE(0)
    ) fifo_inst (
        .s_clk(wr_clk), .s_rst(wr_rst),
        .s_axis_tdata(wr_payload), .s_axis_tvalid(wr_valid), .s_axis_tready(wr_ready),
        .m_clk(rd_clk), .m_rst(rd_rst),
        .m_axis_tdata(rd_payload), .m_axis_tvalid(rd_valid), .m_axis_tready(rd_ready)
    );
endmodule