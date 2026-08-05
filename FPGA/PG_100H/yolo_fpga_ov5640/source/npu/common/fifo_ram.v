module fifo_ram #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(DATA_DEPTH)
)(
    input wire clk,
    input wire wen,
    input wire [DATA_WIDTH-1:0] din,
    input wire [ADDR_WIDTH-1:0] waddr,
    input wire ren,
    input wire [ADDR_WIDTH-1:0] raddr,
    output wire [DATA_WIDTH-1:0] dout
);

    reg [DATA_WIDTH-1:0] mem [0:DATA_DEPTH-1];

    always @(posedge clk) begin
        if(wen) begin
            mem[waddr] <= din;
        end
    end
    

    // 读操作：必须是在时钟沿触发的同步读
    reg [DATA_WIDTH-1:0] dout_r;
    always @(posedge clk) begin
        if(ren) begin
           dout_r <= mem[raddr]; 
        end
    end
    assign dout = dout_r;




endmodule