/*
    无气泡传输插入寄存器(只切断valid)
*/
module pipe #(
    parameter WIDTH = 1
)(
    input                   clk,
    input                   rst,

    input                   up_valid,
    output                  up_ready,
    input  [WIDTH-1 : 0]    data_in ,


    output                  down_valid,
    input                   down_ready,
    output [WIDTH-1 : 0]    data_out  
);


    reg down_valid_reg;
    always@(posedge clk) begin
        if(rst) begin
            down_valid_reg <= 1'b0;
        end
        else if(up_ready) begin
            down_valid_reg <= up_valid;
        end
    end
    assign down_valid = down_valid_reg;


    reg [WIDTH-1 : 0] data_reg;
    always @(posedge clk) begin
        if(rst) begin
            data_reg <= {WIDTH{1'b0}};
        end
        else if(up_ready & up_valid) begin
            data_reg <= data_in;
        end
    end
    assign data_out = data_reg;


    assign up_ready = down_ready | (!down_valid);

endmodule