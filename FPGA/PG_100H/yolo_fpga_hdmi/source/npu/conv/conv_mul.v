// 1.2的无ip版本 (高度优化版)
module conv_mul #(
    parameter INT = 8,
              MUL_DELAY = 4  // 总延迟拍数，最小可为3
)
(
    input                  clk,
    input      [INT-1 : 0] a  ,      // 有符号  
    input      [INT-1 : 0] b  ,      // 有符号
    input      [INT-1 : 0] c  ,      // 图片数据无符号 非对称量化
    output     [INT*2-1 : 0] a_c,
    output     [INT*2-1 : 0] b_c     
);

    wire signed [INT*3-1 : 0] A;
    wire signed [INT*2-1 : 0] B;
    wire signed [INT : 0]     C;
    wire signed [INT*2+1 : 0] D;

    // 判断 c 是否不为 0 (规约或运算)
    wire c_not_zero = (|c);

    assign A = $signed({a, 16'd0});
    assign B = $signed(b);
    assign C = $signed({1'b0, c});
    assign D = {1'b0, (b[INT-1] & c_not_zero), 16'd0};  // 符号位补偿

    // ==========================================
    // 第一拍：预加器与寄存
    // ==========================================
    // 综合工具会自动将 A+B 优化为仅高位操作，因为 A 的低 16 位为 0
    reg signed [INT*3 : 0]     A_plus_B;
    reg signed [INT : 0]       C_d;
    reg signed [INT*2 + 1 : 0] D_d;
    
    always @(posedge clk) begin
        // if(valid_in) begin // 功耗优化点
            A_plus_B <= A + B;
            C_d      <= C;
            D_d      <= D;
        // end
    end

    // ==========================================
    // 第二拍：乘法器计算
    // ==========================================
    (* use_dsp = "yes" *) reg signed [INT*4 + 1 : 0] mult; // 提示综合器使用 DSP
    reg signed [INT*2 + 1 : 0] D_dd;
    
    always @(posedge clk) begin
        // if(valid_in) begin
            mult <= A_plus_B * C_d;
            D_dd <= D_d;
        // end
    end

    // ==========================================
    // 第三拍：后加法器 (截断无用高位)
    // ==========================================
    // 原始需要 35 bits，但最终只用到 [31:0]，直接把高位截断，节省后续流水线资源
    reg signed [INT*4 - 1 : 0] result; 
    wire signed [INT*4 + 2 : 0] full_result = mult + D_dd;
    
    always @(posedge clk) begin
        // if(valid_in) begin
            result <= full_result[INT*4 - 1 : 0]; // 仅保留 32 位
        // end
    end

    // ==========================================
    // 第四拍及以后：可变长度流水线 (安全 Generate 模式)
    // ==========================================
    localparam DELAY = MUL_DELAY - 3;
    
    generate
        if (DELAY > 0) begin : gen_pipeline
            integer i;
            // 位宽缩减到了 32 位，节约大量 FF 资源
            reg [INT*4 - 1 : 0] pipe [0 : DELAY-1]; 
            
            always @(posedge clk) begin
                pipe[0] <= result;
                for (i = 1; i < DELAY; i = i + 1) begin
                    pipe[i] <= pipe[i-1];
                end
            end
            
            assign a_c = pipe[DELAY-1][INT*4-1 : INT*2];
            assign b_c = pipe[DELAY-1][INT*2-1 : 0];
        end 
        else begin : gen_no_pipeline
            // 如果 MUL_DELAY == 3，直接输出，防止数组 [-1] 报错
            assign a_c = result[INT*4-1 : INT*2];
            assign b_c = result[INT*2-1 : 0];
        end
    endgenerate

endmodule