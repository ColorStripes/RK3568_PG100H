module scale_mul_unsign_s3 #(
    parameter DATA_WIDTH  = 32, // A 端口位宽
              SCALE_WIDTH = 16, // B 端口位宽
              DELAY       = 4   // 延迟拍数
)
(
    input  wire  clk,
    input  wire  [DATA_WIDTH-1 : 0]  A,
    input  wire  [SCALE_WIDTH-1 : 0] B,
    output wire  [DATA_WIDTH+SCALE_WIDTH-1 : 0] P
);

/*
    // ==========================================
    // 【核心修正】无符号数的 DSP 乘法器边界必须是 17
    // 因为底层 18-bit 端口是有符号的，无符号数需要最高位补 0
    // ==========================================
    localparam DSP_WIDTH = 17; 
    
    generate
        if (SCALE_WIDTH <= DSP_WIDTH) begin : gen_single_mul
            // ==========================================
            // 场景 1: B 位宽较小，只需单次乘法
            // ==========================================
            wire [DATA_WIDTH-1 : 0]  A_in;
            wire [SCALE_WIDTH-1 : 0] B_in;
            
            // --- 动态 Stage 1: 输入端打拍 (当 DELAY >= 2 时启用) ---
            if (DELAY >= 2) begin : g_in_reg
                reg [DATA_WIDTH-1 : 0]  A_r;
                reg [SCALE_WIDTH-1 : 0] B_r;
                always @(posedge clk) begin
                    A_r <= A;
                    B_r <= B;
                end
                assign A_in = A_r;
                assign B_in = B_r;
            end 
            else begin : g_in_wire
                assign A_in = A;
                assign B_in = B;
            end
            
            // --- 乘法计算 (允许综合工具自动映射到一个 DSP) ---
            wire [DATA_WIDTH+SCALE_WIDTH-1 : 0] mult_res;
            assign mult_res = $unsigned(A_in) * $unsigned(B_in);
            
            // --- 动态 Stage 2+: 输出与多余延迟补齐 ---
            if (DELAY == 0) begin : g_out_wire
                assign P = mult_res;
            end 
            else begin : g_out_reg
                localparam REMAIN_DELAY = (DELAY >= 2) ? (DELAY - 1) : DELAY;
                reg [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : REMAIN_DELAY-1];
                integer i;
                always @(posedge clk) begin
                    pipe[0] <= mult_res;
                    for (i = 1; i < REMAIN_DELAY; i = i + 1) begin
                        pipe[i] <= pipe[i-1];
                    end
                end
                assign P = pipe[REMAIN_DELAY-1];
            end
            
        end
        else begin : gen_split_mul
            // ==========================================
            // 场景 2: B 位宽较大，拆分乘法并移位相加
            // ==========================================
            
            // --- 动态 Stage 1: 输入端打拍 (当 DELAY >= 3 时启用) ---
            wire [DATA_WIDTH-1 : 0]            A_s1;
            wire [DSP_WIDTH-1 : 0]             B_low_s1;
            wire [SCALE_WIDTH-DSP_WIDTH-1 : 0] B_high_s1;
            
            if (DELAY >= 3) begin : g_stage1_reg
                reg [DATA_WIDTH-1 : 0]            A_r;
                reg [DSP_WIDTH-1 : 0]             B_low_r;
                reg [SCALE_WIDTH-DSP_WIDTH-1 : 0] B_high_r;
                always @(posedge clk) begin
                    A_r      <= A;
                    B_low_r  <= B[DSP_WIDTH-1 : 0];
                    B_high_r <= B[SCALE_WIDTH-1 : DSP_WIDTH];
                end
                assign A_s1      = A_r;
                assign B_low_s1  = B_low_r;
                assign B_high_s1 = B_high_r;
            end else begin : g_stage1_wire
                assign A_s1      = A;
                assign B_low_s1  = B[DSP_WIDTH-1 : 0];
                assign B_high_s1 = B[SCALE_WIDTH-1 : DSP_WIDTH];
            end
            
            // --- 动态 Stage 2: 乘法部分积打拍 (当 DELAY >= 2 时启用) ---
            wire [DATA_WIDTH+DSP_WIDTH-1 : 0]             mul_low_s2;
            wire [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0] mul_high_s2;
            
            wire [DATA_WIDTH+DSP_WIDTH-1 : 0]             mul_low_w  = $unsigned(A_s1) * $unsigned(B_low_s1);
            wire [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0] mul_high_w = $unsigned(A_s1) * $unsigned(B_high_s1);
            
            if (DELAY >= 2) begin : g_stage2_reg
                // 【精准映射】：强制这两组部分积使用 DSP 资源
                (* use_dsp = "yes", syn_multstyle = "dsp" *) reg [DATA_WIDTH+DSP_WIDTH-1 : 0]             mul_low_r;
                (* use_dsp = "yes", syn_multstyle = "dsp" *) reg [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0] mul_high_r;
                always @(posedge clk) begin
                    mul_low_r  <= mul_low_w;
                    mul_high_r <= mul_high_w;
                end
                assign mul_low_s2  = mul_low_r;
                assign mul_high_s2 = mul_high_r;
            end 
            else begin : g_stage2_wire
                assign mul_low_s2  = mul_low_w;
                assign mul_high_s2 = mul_high_w;
            end
            
            // --- 动态 Stage 3+: 加法结果打拍与多余延迟补齐 (当 DELAY >= 1 时启用) ---
            // 【精准映射】：强制拼接加法使用 LUT 逻辑，防止浪费 DSP
            (* use_dsp = "no", syn_multstyle = "logic" *) wire [DATA_WIDTH+SCALE_WIDTH-1 : 0] add_w = mul_low_s2 + (mul_high_s2 << DSP_WIDTH);
            
            if (DELAY == 0) begin : g_stage3_wire
                assign P = add_w;
            end else begin : g_stage3_reg
                // 计算剩余的流水线深度 (前两级最多消耗 2 个 DELAY)
                localparam REMAIN_DELAY = (DELAY >= 3) ? (DELAY - 2) : 1;
                
                reg [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : REMAIN_DELAY-1];
                integer i;
                always @(posedge clk) begin
                    pipe[0] <= add_w;
                    for (i = 1; i < REMAIN_DELAY; i = i + 1) begin
                        pipe[i] <= pipe[i-1];
                    end
                end
                assign P = pipe[REMAIN_DELAY-1];
            end
        end
    endgenerate
*/




    localparam DSP_WIDTH = 17; // 乘法器边界划分
    
    generate
        if (SCALE_WIDTH <= DSP_WIDTH) begin : gen_single_mul
            // ==========================================
            // 场景 1: B 位宽较小，只需单次乘法
            // ==========================================
            wire [DATA_WIDTH-1 : 0]  A_in;
            wire [SCALE_WIDTH-1 : 0] B_in;
            
            // --- 动态 Stage 1: 输入端打拍 (当 DELAY >= 2 时启用) ---
            if (DELAY >= 2) begin : g_in_reg
                reg [DATA_WIDTH-1 : 0]  A_r;
                reg [SCALE_WIDTH-1 : 0] B_r;
                always @(posedge clk) begin
                    A_r <= A;
                    B_r <= B;
                end
                assign A_in = A_r;
                assign B_in = B_r;
            end 
            else begin : g_in_wire
                assign A_in = A;
                assign B_in = B;
            end
            
            // --- 乘法计算 ---
            wire [DATA_WIDTH+SCALE_WIDTH-1 : 0] mult_res;
            assign mult_res = $unsigned(A_in) * $unsigned(B_in);
            
            // --- 动态 Stage 2+: 输出与多余延迟补齐 ---
            if (DELAY == 0) begin : g_out_wire
                assign P = mult_res;
            end 
            else begin : g_out_reg
                // 计算剩余需要打拍的级数
                localparam REMAIN_DELAY = (DELAY >= 2) ? (DELAY - 1) : DELAY;
                reg [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : REMAIN_DELAY-1];
                integer i;
                always @(posedge clk) begin
                    pipe[0] <= mult_res;
                    for (i = 1; i < REMAIN_DELAY; i = i + 1) begin
                        pipe[i] <= pipe[i-1];
                    end
                end
                assign P = pipe[REMAIN_DELAY-1];
            end
            
        end
        else begin : gen_split_mul
            // ==========================================
            // 场景 2: B 位宽较大，拆分乘法并移位相加
            // ==========================================
            
            // --- 动态 Stage 1: 输入端打拍 (当 DELAY >= 3 时启用) ---
            wire [DATA_WIDTH-1 : 0]            A_s1;
            wire [DSP_WIDTH-1 : 0]             B_low_s1;
            wire [SCALE_WIDTH-DSP_WIDTH-1 : 0] B_high_s1;
            
            if (DELAY >= 3) begin : g_stage1_reg
                reg [DATA_WIDTH-1 : 0]            A_r;
                reg [DSP_WIDTH-1 : 0]             B_low_r;
                reg [SCALE_WIDTH-DSP_WIDTH-1 : 0] B_high_r;
                always @(posedge clk) begin
                    A_r      <= A;
                    B_low_r  <= B[DSP_WIDTH-1 : 0];
                    B_high_r <= B[SCALE_WIDTH-1 : DSP_WIDTH];
                end
                assign A_s1      = A_r;
                assign B_low_s1  = B_low_r;
                assign B_high_s1 = B_high_r;
            end else begin : g_stage1_wire
                assign A_s1      = A;
                assign B_low_s1  = B[DSP_WIDTH-1 : 0];
                assign B_high_s1 = B[SCALE_WIDTH-1 : DSP_WIDTH];
            end
            
            // --- 动态 Stage 2: 乘法部分积打拍 (当 DELAY >= 2 时启用) ---
            wire [DATA_WIDTH+DSP_WIDTH-1 : 0]               mul_low_s2;
            wire [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0]   mul_high_s2;
            
            wire [DATA_WIDTH+DSP_WIDTH-1 : 0]             mul_low_w  = $unsigned(A_s1) * $unsigned(B_low_s1);
            wire [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0] mul_high_w = $unsigned(A_s1) * $unsigned(B_high_s1);
            
            if (DELAY >= 2) begin : g_stage2_reg
                reg [DATA_WIDTH+DSP_WIDTH-1 : 0]             mul_low_r;
                reg [DATA_WIDTH+SCALE_WIDTH-DSP_WIDTH-1 : 0] mul_high_r;
                always @(posedge clk) begin
                    mul_low_r  <= mul_low_w;
                    mul_high_r <= mul_high_w;
                end
                assign mul_low_s2  = mul_low_r;
                assign mul_high_s2 = mul_high_r;
            end else begin : g_stage2_wire
                assign mul_low_s2  = mul_low_w;
                assign mul_high_s2 = mul_high_w;
            end
            
            // --- 动态 Stage 3+: 加法结果打拍与多余延迟补齐 (当 DELAY >= 1 时启用) ---
            wire [DATA_WIDTH+SCALE_WIDTH-1 : 0] add_w = mul_low_s2 + (mul_high_s2 << DSP_WIDTH);
            
            if (DELAY == 0) begin : g_stage3_wire
                assign P = add_w;
            end else begin : g_stage3_reg
                // 计算剩余的流水线深度 (前两级最多消耗 2 个 DELAY)
                localparam REMAIN_DELAY = (DELAY >= 3) ? (DELAY - 2) : 1;
                
                reg [DATA_WIDTH+SCALE_WIDTH-1 : 0] pipe [0 : REMAIN_DELAY-1];
                integer i;
                always @(posedge clk) begin
                    pipe[0] <= add_w;
                    for (i = 1; i < REMAIN_DELAY; i = i + 1) begin
                        pipe[i] <= pipe[i-1];
                    end
                end
                assign P = pipe[REMAIN_DELAY-1];
            end
        end
    endgenerate




endmodule