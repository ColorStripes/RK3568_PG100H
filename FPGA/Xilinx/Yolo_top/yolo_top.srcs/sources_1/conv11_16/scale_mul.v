module scale_mul #(
    parameter DATA_WIDTH = 32,
              SCALE_WIDTH = 16,
              DELAY = 1
)
(
    input   clk,
    input signed [DATA_WIDTH-1 : 0]   A,
    input signed [SCALE_WIDTH-1 : 0]  B,
    output signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] P
 
);


    // 乘积结果寄存器流水线
    reg signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : DELAY-1];

    integer i;

    always @(posedge clk) begin
        // 乘法计算（仅在第一阶段）
        pipe[0] <= $signed(A) * $signed(B);

        // 流水线数据向后传输
        for (i = 1; i < DELAY; i = i + 1) begin
            pipe[i] <= pipe[i-1];
        end
    end

    // 输出为最后一级流水线数据
    assign P = pipe[DELAY-1];


endmodule