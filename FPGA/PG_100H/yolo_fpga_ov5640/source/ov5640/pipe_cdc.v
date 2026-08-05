module pipe_cdc #(
    parameter integer DATA_WIDTH     = 8, // 【核心修改】可自由配置的数据位宽
    parameter integer DEST_SYNC_FF   = 4, // 目标时钟域同步触发器级数 (范围: 2-10)
    parameter integer INIT_SYNC_FF   = 0, // 仿真与上电初始值 (0或1)
    parameter integer SRC_INPUT_REG  = 1  // 源时钟域输入是否先打一拍寄存 (0=否, 1=是)
)(
    input  wire                    src_clk,  // 源时钟
    input  wire [DATA_WIDTH-1 : 0] src_in,   // 跨域前的多比特总线
    input  wire                    dest_clk, // 目标时钟
    output wire [DATA_WIDTH-1 : 0] dest_out  // 跨域后的安全多比特总线
);

    // =====================================================================
    // 1. 源时钟域处理逻辑 (Source Clock Domain)
    // =====================================================================
    wire [DATA_WIDTH-1 : 0] sync_in;

    generate
        if (SRC_INPUT_REG == 1) begin : gen_src_reg
            reg [DATA_WIDTH-1 : 0] src_ff = {DATA_WIDTH{INIT_SYNC_FF[0]}};
            always @(posedge src_clk) begin
                src_ff <= src_in;
            end
            assign sync_in = src_ff;
        end 
        else begin : gen_no_src_reg
            assign sync_in = src_in;
        end
    endgenerate


    // =====================================================================
    // 2. 目标时钟域同步逻辑 (Destination Clock Domain)
    // =====================================================================

    (* SHREG_EXTRACT = "NO" *)reg [DEST_SYNC_FF-1 : 0] sync_stages[DATA_WIDTH-1 : 0];

    genvar i;
    generate
        // 为第 i 位信号生成独立的受保护移位寄存器
        
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin : gen_sync_bits
            
            always @(posedge dest_clk) begin
                // 数据从最低位进入，逐级往左推
                sync_stages[i] <= {sync_stages[i][DEST_SYNC_FF-2 : 0], sync_in[i]};
            end

            // 最后一级输出作为第 i 位的安全跨域结果
            assign dest_out[i] = sync_stages[i][DEST_SYNC_FF-1];
            
        end
    endgenerate

endmodule