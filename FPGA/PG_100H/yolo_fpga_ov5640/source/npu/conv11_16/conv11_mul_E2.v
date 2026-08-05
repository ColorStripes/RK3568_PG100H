`timescale 1ns / 1ps

module conv11_mul_E2 #(
    parameter INT       = 8,
    parameter MUL_DELAY = 4  // 总延迟拍数（至少3拍：3拍DSP内部流水 + (MUL_DELAY-3)拍逻辑流水）
)
(
    input  wire                 clk,
    input  wire [INT-1 : 0]     a,    // 有符号输入
    input  wire [INT-1 : 0]     b,    // 有符号输入
    input  wire [INT-1 : 0]     c,    // 无符号输入，非对称量化图片数据
    output wire [INT*2-1 : 0]   a_c,  // 16-bit 输出 (a * c 结果)
    output wire [INT*2-1 : 0]   b_c   // 16-bit 输出 (b * c 结果)
);

    // =========================================================================
    // 1. 组合逻辑：位宽扩展与 SIMD 拼位 (不占用时钟拍数)
    // 信号通过 assign 直接连到 APM 输入端口，消除了外部 Slice 寄存器对布线的压力
    // =========================================================================
    wire signed [11:0] a_ext = {{4{a[INT-1]}}, a}; // 拓宽至 12-bit 有符号
    wire signed [11:0] b_ext = {{4{b[INT-1]}}, b}; // 拓宽至 12-bit 有符号
    wire signed [8:0]  c_ext = {1'b0, c};          // 拓宽至 9-bit 无符号（高位补 0）

    // X 端口接 a 和 b，Y 端口接 c (广播模式)
    wire [29:0] x_in = {6'b000_000, a_ext, b_ext};
    wire [17:0] y_in = {c_ext, c_ext};

    // =========================================================================
    // 2. GTP_APM_E2 原语实例化 (DSP 内部配置为 3 拍流水线)
    // 延迟核算：(X/Y_REG=1) + (MULT_REG=1) + (P_REG=1) = 3 拍
    // =========================================================================
    wire [47:0] result;

    GTP_APM_E2 #(
        .GRS_EN         ("TRUE"),
        .ASYNC_RST      (0),      // 选择同步复位
        
        // --- DSP 内部流水线寄存器配置（共消耗 3 拍） ---
        .X_REG          (1),      // 输入寄存器 XREG1 有效 (1 拍)
        .XB_REG         (0),
        .Y_REG          (1),      // 输入寄存器 YREG1 有效 (1 拍)
        .Z_REG          (0),
        .MULT_REG       (1),      // 乘法器流水线寄存器有效 (1 拍)
        .P_REG          (1),      // 输出寄存器 PREG 有效 (1 拍)
        
        .USE_SIMD       (1),      // 开启 SIMD 模式实现双路乘法
        .USE_MULT       (1),      // 开启乘法器单元
        .USE_POSTADD    (0),      // 关闭后级累加器以降低功耗
        .X_SEL          (0),      // 选择 X 端口输入而非级联输入
        .XB_SEL         (0)
    ) u_apm_3cycle (
        .P              (result),
        .CLK            (clk),

        // 数据输入：由外部 assign 逻辑直接送入
        .X              (x_in), 
        .Y              (y_in), 
        
        // 时钟使能信号
        .CEX1           (1'b1),
        .CEX2           (1'b1),   
        .CEY1           (1'b1),
        .CEY2           (1'b1),   
        .CEM            (1'b1),   // 开启 MULT_REG 使能
        .CEP            (1'b1),   // 开启 P_REG 使能

        // 模式控制
        .MODEIN         (5'b00110), 
        .MODEY          (3'b000), 
        .MODEZ          (4'b0000),

        // 其余端口保持静默
        .XB(25'd0), .Z(48'd0), .CPI(48'd0), .CIN(1'b0),
        .RSTX(1'b0), .RSTY(1'b0), .RSTM(1'b0), .RSTP(1'b0)
    );

    // =========================================================================
    // 3. 输出数据提取与外部逻辑流水线 (补齐剩余的 MUL_DELAY - 3 拍)
    // SIMD 12x9 模式下：
    // 高通道 (a * c) 结果位于 result[47:24]，对于 16 位有效输出截取 [39:24]
    // 低通道 (b * c) 结果位于 result[23:0]， 对于 16 位有效输出截取 [15:0]
    // =========================================================================
    wire [INT*2-1 : 0] result_a_c = result[24 +: INT*2]; // 精准提取高通道 16-bit 结果 (result[39:24])
    wire [INT*2-1 : 0] result_b_c = result[0  +: INT*2]; // 精准提取低通道 16-bit 结果 (result[15:0])
    
    // 将提取出的两路 16 位有效数据打包成 32 位，用于送入流水线
    wire [INT*4-1 : 0] result_packed = {result_a_c, result_b_c};

    localparam DELAY = MUL_DELAY - 3;

    generate
        if (DELAY > 0) begin : gen_pipeline
            integer i;
            // 声明精确 32 位宽的流水线寄存器数组，防止高位截断，同时节省资源
            reg [INT*4-1 : 0] pipe [0 : DELAY-1];
            
            always @(posedge clk) begin
                // 第一级逻辑流水线打拍
                pipe[0] <= result_packed;

                // 剩余级数向后传输
                for (i = 1; i < DELAY; i = i + 1) begin
                    pipe[i] <= pipe[i-1];
                end
            end

            // 从最后一级流水线中拆解出最终的 a_c 和 b_c 输出
            assign a_c = pipe[DELAY-1][INT*4-1 : INT*2]; // 对应 result_a_c
            assign b_c = pipe[DELAY-1][INT*2-1 : 0];     // 对应 result_b_c
            
        end 
        else begin : gen_bypass
            // 当 MUL_DELAY = 3 时 (DELAY = 0)，直接输出 DSP 的实时截取结果，不生成寄存器
            assign a_c = result_a_c;
            assign b_c = result_b_c;
        end
    endgenerate

endmodule