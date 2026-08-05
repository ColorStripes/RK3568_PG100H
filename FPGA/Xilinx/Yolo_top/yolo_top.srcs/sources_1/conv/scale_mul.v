module scale_mul #(
    parameter DATA_WIDTH  = 32,
              SCALE_WIDTH = 16,
              DELAY       = 1
)
(
    input  wire clk,
    input  wire signed [DATA_WIDTH-1 : 0]  A,
    input  wire signed [SCALE_WIDTH-1 : 0] B,
    output wire signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] P
);

    generate
        if (DELAY == 0) begin : gen_delay_0
            // ==========================================
            // 延迟为 0：纯组合逻辑（仅限低频或仿真）
            // ==========================================
            assign P = $signed(A) * $signed(B);
        end
        else if (DELAY == 1) begin : gen_delay_1
            // ==========================================
            // 延迟为 1：仅在乘法器后打一拍 (利用 DSP PREG)
            // ==========================================
            reg signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] p_r;
            always @(posedge clk) begin
                p_r <= $signed(A) * $signed(B);
            end
            assign P = p_r;
        end
        else if (DELAY == 2) begin : gen_delay_2
            // ==========================================
            // 延迟为 2：输入打一拍，输出打一拍 (利用 DSP AREG/BREG + PREG)
            // ==========================================
            reg signed [DATA_WIDTH-1 : 0]             a_r;
            reg signed [SCALE_WIDTH-1 : 0]            b_r;
            reg signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] p_r;
            
            always @(posedge clk) begin
                a_r <= A;
                b_r <= B;
                p_r <= $signed(a_r) * $signed(b_r);
            end
            assign P = p_r;
        end
        else begin : gen_delay_N
            // ==========================================
            // 延迟 >= 3：输入打一拍，乘法打一拍，剩余延迟作为移位寄存器
            // (完美映射 DSP 的多级内部流水线)
            // ==========================================
            reg signed [DATA_WIDTH-1 : 0]             a_r;
            reg signed [SCALE_WIDTH-1 : 0]            b_r;
            reg signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] mult_r;
            
            // 剩下的延迟分配给末端的移位寄存器
            localparam REMAIN_DELAY = DELAY - 2; 
            reg signed [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : REMAIN_DELAY-1];
            
            integer i;
            always @(posedge clk) begin
                // 第一拍：锁存输入
                a_r    <= A;
                b_r    <= B;
                
                // 第二拍：计算乘法并锁存
                mult_r <= $signed(a_r) * $signed(b_r);
                
                // 第三拍及以后：流水线移位传递
                pipe[0] <= mult_r;
                for (i = 1; i < REMAIN_DELAY; i = i + 1) begin
                    pipe[i] <= pipe[i-1];
                end
            end
            
            assign P = pipe[REMAIN_DELAY-1];
        end
    endgenerate

endmodule