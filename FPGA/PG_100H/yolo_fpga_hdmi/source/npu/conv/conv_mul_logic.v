//1.2的无ip版本
(* syn_multstyle = "logic" *)
module conv_mul_logic #(
    parameter INT = 8,
              MUL_DELAY = 4  //至少4拍
)
(
    input         clk,
    input  [INT-1 : 0]  a  ,                //有符号  
    input  [INT-1 : 0]  b  ,                //有符号
    input  [INT-1 : 0]  c  ,                //图片数据无符号 非对称量化
    output [INT*2-1 : 0] a_c,
    output [INT*2-1 : 0] b_c     
);


    wire signed [INT*3-1 : 0] A_w;
    wire signed [INT*2-1 : 0] B_w;
    wire signed [INT : 0]     C_w;
    wire signed [INT*2+1 : 0] D_w;

    // 新增：判断 c 是否不为 0 (规约或运算，只要 c 中有一位是 1，结果就是 1)
    wire c_not_zero = (|c);

    assign A_w = $signed({a, 16'd0});
    assign B_w = $signed(b);
    assign C_w = $signed({1'b0, c});
    assign D_w = {1'b0, (b[INT-1] & c_not_zero), 16'd0};   //这个符号位补偿 看文档5.20


    //A * C + B * C ==> (A+B) * C  ==> A*C + B*C
    //(A+B)*C+D

    //一拍组合逻辑
    // wire signed [INT*3 : 0] A_plus_B = A + B;
    // wire signed [INT*4 + 1 : 0] mult = A_plus_B * C;
    // wire signed [INT*4 + 2 : 0] result = mult + D;



    reg signed [INT*3-1 : 0] A;
    reg signed [INT*2-1 : 0] B;
    reg signed [INT : 0]     C;
    reg signed [INT*2+1 : 0] D;
    always @(posedge clk) begin
        A <= A_w;
        B <= B_w;
        C <= C_w;
        D <= D_w;
    end


    //三拍时序逻辑  
    reg signed [INT*3 : 0] A_plus_B;    
    reg signed [INT : 0]     C_d;
    reg signed [INT*2 + 1 : 0] D_d;
    always @(posedge clk) begin
        A_plus_B <= A + B;
        C_d <= C;
        D_d <= D;
    end

    reg signed [INT*4 + 1 : 0] mult;
    reg signed [INT*2 + 1 : 0] D_dd;
    always @(posedge clk) begin
        mult <= A_plus_B * C_d;
        D_dd <= D_d;
    end

    reg signed [INT*4 + 2 : 0] result ;
    always @(posedge clk) begin
        result <= mult + D_dd;
    end


// /////////////////////////流水//////////////////////
    // 乘积结果寄存器流水线
    localparam DELAY = MUL_DELAY-4;

    generate
        if (DELAY > 0) begin : gen_pipeline
            integer i;
            reg signed [4*INT+2 : 0] pipe [0 : DELAY-1];
            
            always @(posedge clk) begin
                // 乘法计算（仅在第一阶段）
                pipe[0] <= result;

                // 流水线数据向后传输
                for (i = 1; i < DELAY; i = i + 1) begin
                    pipe[i] <= pipe[i-1];
                end
            end

            // 输出为最后一级流水线数据
            assign a_c = pipe[DELAY-1][INT*4-1 : INT*2];
            assign b_c = pipe[DELAY-1][INT*2-1 : 0];
            
        end 
        else begin : gen_bypass
            // 当 DELAY = 0 时，直接输出 result，不生成 pipe 寄存器
            assign a_c = result[INT*4-1 : INT*2];
            assign b_c = result[INT*2-1 : 0];
        end
    endgenerate

endmodule