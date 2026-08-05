module spram #(
    parameter DP = 1024,            //存储单元深度
    parameter DW = 8   ,            //数据位宽
    parameter PIPE = 2  
) (
    input                             clk  ,
    input        [DW - 1 : 0]         wdata,
    input                             wen  ,
    input        [$clog2(DP) - 1 : 0] waddr,
    input                             ren  ,
    input        [$clog2(DP) - 1 : 0] raddr,
    output reg   [DW - 1 : 0]         rdata
);



reg [DW - 1:0] mem [DP - 1 : 0];
always @(posedge clk ) begin
    if(wen) begin
        mem[waddr] <= wdata;
    end
end


//由PIPE动态生成代码块
generate
    if(PIPE == 2) begin

        reg [DW - 1 : 0] rdata_temp;
        always @(posedge clk) begin
            if(ren) begin
                rdata_temp <= mem[raddr];
            end
        end
        
        always @(posedge clk) begin
            rdata <= rdata_temp;
        end

    end
    else begin

        always @(posedge clk) begin
            if(ren) begin
                rdata <= mem[raddr];
            end
        end
        
    end
endgenerate

    
endmodule