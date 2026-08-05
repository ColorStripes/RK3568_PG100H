module scale_mul_unsign #(
    parameter DATA_WIDTH = 25,
              SCALE_WIDTH = 32,
              DELAY = 1
)
(
    input   clk,
    input [DATA_WIDTH-1 : 0]   A,
    input [SCALE_WIDTH-1 : 0]  B,
    output [DATA_WIDTH+SCALE_WIDTH-1 : 0] P
 
);

    localparam DSP_WIDTH = 17;                        //(for B)    



    //计算
    wire [DATA_WIDTH + SCALE_WIDTH-1 : 0] result;
    generate
        
       if(SCALE_WIDTH <= DSP_WIDTH) begin
            (* use_dsp = "yes" *)wire [DATA_WIDTH + SCALE_WIDTH-1 : 0] result_1;
            assign result_1 = A * B; 
            assign result = result_1;
       end
       else begin
           wire [DSP_WIDTH-1 : 0]               B_low  = B[DSP_WIDTH-1 : 0];
           wire [SCALE_WIDTH - DSP_WIDTH-1 : 0] B_high = B[SCALE_WIDTH-1 : DSP_WIDTH];
           (* use_dsp = "yes" *)wire [DATA_WIDTH + DSP_WIDTH-1 : 0]                mul_low;
           (* use_dsp = "yes" *)wire [DATA_WIDTH + SCALE_WIDTH - DSP_WIDTH-1 : 0]  mul_high;
           assign mul_low  = $unsigned(A) * $unsigned(B_low);
           assign mul_high = $unsigned(A) * $unsigned(B_high);
           (* use_dsp = "no" *)wire [DATA_WIDTH + SCALE_WIDTH-1 : 0] result_2;
           assign result_2 = mul_low + (mul_high << DSP_WIDTH);
           assign result = result_2;
       end
        
    endgenerate   

    // 乘积结果寄存器流水线
    reg [DATA_WIDTH + SCALE_WIDTH-1 : 0] pipe [0 : DELAY-1];

    integer i;
    always @(posedge clk) begin
        // 乘法计算（仅在第一阶段）
        pipe[0] <= result;

        // 流水线数据向后传输
        for (i = 1; i < DELAY; i = i + 1) begin
            pipe[i] <= pipe[i-1];
        end
    end

    // 输出为最后一级流水线数据
    assign P = pipe[DELAY-1];


endmodule