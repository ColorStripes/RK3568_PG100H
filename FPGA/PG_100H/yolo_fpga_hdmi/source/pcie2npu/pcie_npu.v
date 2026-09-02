`timescale 1ns / 1ps

module pcie_npu #(
    parameter AXI_DATA_WIDTH = 128,
              AXI_ADDR_WIDTH = 32,

    parameter INSTRUCTION_WIDTH = 32,
              INSTRUCTION_NUM = 3100,

    parameter NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER + 1)
)(
    // 全局时钟与复位
    input  wire                              axi_clk,
    input  wire                              axi_rst,

    // AXI 写地址通道 (AW)
    input  wire [AXI_ADDR_WIDTH-1 : 0]       s_axi_awaddr ,
    input  wire [7 : 0]                      s_axi_awlen  ,    // 突发长度，支持 AXI4
    input  wire [2 : 0]                      s_axi_awsize ,   // 突发大小
    input  wire [1 : 0]                      s_axi_awburst,  // 突发类型
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,

    // AXI 写数据通道 (W)
    input  wire [AXI_DATA_WIDTH-1 : 0]       s_axi_wdata ,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb ,    // 字节掩码
    input  wire                              s_axi_wlast ,    // 突发的最后一个数据标志
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,

    // AXI 写响应通道 (B)
    output wire [1 : 0]                      s_axi_bresp ,
    output wire                              s_axi_bvalid,
    input  wire                              s_axi_bready,
    

    ////////////////////////////////////////////////////////////
    //用户逻辑
    input                         npu_clk,
    input                         npu_rst,



    output                                   m_npu_start,
    output  [INSTRUCTION_WIDTH-1 : 0]        m_npu_instruction,
    output                                   m_almost_empty,
    input                                    m_npu_instruction_ren,
    input                                    m_npu_instruction_rewind,

    





    output reg [LAYER_WIDTH-1 : 0]  m_npu_layer ,


    input                   calculate_end        ,
    output                  calculate_end_receive,


    output                      npu_req         , 
    input                       npu_req_receive           
);

    wire s_almost_full;
    
    // ==========================================
    // 状态机定义 (4个状态)
    // ==========================================
    localparam IDLE = 3'b000, INSTRUCTION = 3'b001, NPU_NUM = 3'b010, NPU_START = 3'b011, WRITE_RESP = 3'b100;

    reg [2 : 0] state, next_state;
    
    // ==========================================
    // 第一段：状态机时序逻辑
    // ==========================================
    always @(posedge axi_clk) begin
        if (axi_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ==========================================
    // 第二段：状态机组合逻辑 (状态跳转)
    // ==========================================
    always @(*) begin
        next_state = state; // 默认保持当前状态

        case (state)
            IDLE: begin
                // 当写地址有效时，解析地址并跳转
                if(s_axi_awvalid) begin
                    if (s_axi_awaddr >= 32'h4000_0000 && s_axi_awaddr < 32'h5000_0000) begin
                        next_state = INSTRUCTION;
                    end 
                    else if (s_axi_awaddr == 32'h5000_0000) begin
                        next_state = NPU_NUM;
                    end
                    else if (s_axi_awaddr == 32'h5100_0000) begin
                        next_state = NPU_START;
                    end
                    else begin
                        // 如果传入其他地址，默认切入INSTRUCTION消耗掉数据，防止总线死锁
                        next_state = INSTRUCTION; 
                    end
                end
            end

            INSTRUCTION: begin
                // 突发传输：等待主机发出 wlast 且完成握手，表示数据传完
                if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
                    next_state = WRITE_RESP;
                end
            end

            NPU_NUM: begin
                // 突发传输：同上
                if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
                    next_state = WRITE_RESP;
                end
            end

            NPU_START: begin
                // 突发传输：同上
                if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
                    next_state = WRITE_RESP;
                end
            end

            WRITE_RESP: begin
                // 响应完成：主机接受了我们的 B 响应后，返回 IDLE
                if (s_axi_bvalid && s_axi_bready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // ==========================================
    // 第三段：AXI 握手信号输出逻辑
    // ==========================================
    
    // awready: 只有在 IDLE 状态时才接收地址
    assign s_axi_awready = (state == IDLE);

    // wready: 在 INSTRUCTION 或 NPU_NUM 或 NPU_START 状态下准备接收突发数据
    assign s_axi_wready  = ((state == INSTRUCTION) && !s_almost_full) || (state == NPU_NUM) || (state == NPU_START);

    // bvalid: 在 WRITE_RESP 状态下发出响应信号
    assign s_axi_bvalid  = (state == WRITE_RESP);
    
    // bresp: 2'b00 代表 OKAY (正常完成)
    assign s_axi_bresp   = 2'b00; 


    // -----------------------------------------------------
    // 层数计数器（axi 域接收一次后稳定；同步到 npu 域再使用）
    // -----------------------------------------------------
    wire npu_layer_en   = (state == NPU_NUM) && s_axi_wvalid && s_axi_wready;

    reg  [LAYER_WIDTH-1 : 0] layer_axi;
    reg                      layer_valid_axi;
    always @(posedge axi_clk) begin
        if (axi_rst) begin
            layer_axi       <= {LAYER_WIDTH{1'b0}};
            layer_valid_axi <= 1'b0;
        end 
        else if (npu_layer_en) begin
            layer_axi       <= s_axi_wdata[LAYER_WIDTH-1 : 0];
            layer_valid_axi <= 1'b1;   // 写完后拉高，此后层数不再改变
        end
    end

    // 层数 valid 2 级同步到 npu 域，稳定后再采样 layer_axi（多比特准静态 CDC）
    reg layer_valid_s1, layer_valid_s2;
    always @(posedge npu_clk) begin
        if (npu_rst) begin
            layer_valid_s1 <= 1'b0;
            layer_valid_s2 <= 1'b0;
        end else begin
            layer_valid_s1 <= layer_valid_axi;
            layer_valid_s2 <= layer_valid_s1;
        end
    end

    always @(posedge npu_clk) begin
        if (npu_rst)
            m_npu_layer <= {LAYER_WIDTH{1'b0}};
        else if (layer_valid_s2)
            m_npu_layer <= layer_axi;
    end





    // // -----------------------------------------------------
    // // 指令缓存
    // // -----------------------------------------------------
    wire instr_en = (state == INSTRUCTION) && s_axi_wvalid && s_axi_wready;

    // 每拍 128bit 含 4 条 32bit 指令；末拍不足时，有效指令排在低位、高位为占位
    localparam WORDS_PER_BEAT = AXI_DATA_WIDTH / INSTRUCTION_WIDTH;                                   // 128/32 = 4
    localparam PAD_WORDS      = (WORDS_PER_BEAT - (INSTRUCTION_NUM % WORDS_PER_BEAT)) % WORDS_PER_BEAT; // 末拍占位字数(0~3)

    ins_cdc_replay #(
        .WR_DATA_WIDTH(AXI_DATA_WIDTH),
        .RD_DATA_WIDTH(INSTRUCTION_WIDTH),
        .WR_DEPTH(1024),
        .RD_DEPTH(4096),
        .ALMOST_FULL_NUM(1020),
        .ALMOST_EMPTY_NUM(PAD_WORDS)
    )
    ins_cdc_replay(
        // ---- 写侧（axi_clk 域） ----
        .wr_clk(axi_clk),
        .wr_rst(axi_rst),
        .wr_en(instr_en),
        .wr_data(s_axi_wdata),
        .wr_full(),
        .almost_full(s_almost_full),

        // ---- 读侧（npu_clk 域） ----
        .rd_clk(npu_clk),
        .rd_rst(npu_rst),
        .rd_en(m_npu_instruction_ren),      // 消费当前 FWFT 字（高有效）
        .rd_data(m_npu_instruction),    // FWFT 输出
        .rd_empty(),   // = !fwft_valid
        .almost_empty(m_almost_empty),
        .rewind(m_npu_instruction_rewind)      // 读指针复位到 0（重放）
    );
















    // -----------------------------------------------------
    // 启动指令（跨时钟域：axi_clk 检测 -> npu_clk 同步输出脉冲）
    // -----------------------------------------------------
    // axi 域：命中启动魔数时翻转 toggle（每个启动命令翻一次）
    wire start_cmd = (state == NPU_START) && s_axi_wvalid && s_axi_wready && (s_axi_wdata == 32'hf0f0_f0f0);

    reg start_toggle_axi;
    always @(posedge axi_clk) begin
        if (axi_rst)
            start_toggle_axi <= 1'b0;
        else if (start_cmd)
            start_toggle_axi <= ~start_toggle_axi;
    end

    // 2 级同步 + 1 级边沿检测，切到 npu_clk 域
    reg start_toggle_s1, start_toggle_s2, start_toggle_s3;
    always @(posedge npu_clk) begin
        if (npu_rst) begin
            start_toggle_s1 <= 1'b0;
            start_toggle_s2 <= 1'b0;
            start_toggle_s3 <= 1'b0;
        end else begin
            start_toggle_s1 <= start_toggle_axi;
            start_toggle_s2 <= start_toggle_s1;
            start_toggle_s3 <= start_toggle_s2;
        end
    end

    // toggle 每翻转一次，在 npu_clk 域产生单周期脉冲
    assign m_npu_start = start_toggle_s2 ^ start_toggle_s3;










    ////////////////////////// NPU_END  //////////////////////////
    localparam NPU_IDLE = 1'b0, NPU_END = 1'b1;
    // ==========================================
    // 第一段：状态机时序逻辑
    // ==========================================
    reg npu_state, npu_next_state/*synthesis PAP_MARK_DEBUG="1"*/;
    always @(posedge npu_clk) begin
        if (npu_rst) begin
            npu_state <= NPU_IDLE;
        end else begin
            npu_state <= npu_next_state;
        end
    end

    // ==========================================
    // 第二段：状态机组合逻辑 (状态跳转)
    // ==========================================
    always @(*) begin
        npu_next_state = npu_state; // 默认保持当前状态

        case(npu_state)
            NPU_IDLE: begin
                if(calculate_end) begin
                    npu_next_state = NPU_END;
                end
            end
            NPU_END:begin
                if(npu_layer != m_npu_layer-1) begin
                    npu_next_state = NPU_IDLE;
                end
                else if(npu_req & npu_req_receive) begin
                    npu_next_state = NPU_IDLE;
                end
                else begin
                    npu_next_state = NPU_END;
                end
            end
            default: npu_next_state = NPU_IDLE;
        endcase
    end




    reg [LAYER_WIDTH-1 : 0] npu_layer;
    always @(posedge npu_clk) begin
        if(npu_rst) begin
            npu_layer <= 0;
        end
        else if((npu_layer == m_npu_layer) && (npu_state == NPU_IDLE)) begin
            npu_layer <= 0;
        end
        else if((npu_state == NPU_END) && (npu_next_state == NPU_IDLE)) begin
            npu_layer <= npu_layer + 1'b1;
        end
    end

    
    //end处理
    reg end_received;
    always @(posedge npu_clk) begin
        if(npu_rst) begin
            end_received <= 1'b0;
        end
        else if(end_received) begin
            end_received <= 1'b0;
        end
        else if((npu_state != NPU_END) && (npu_next_state == NPU_END)) begin
            end_received <= 1'b1;
        end
    end
    assign calculate_end_receive = end_received;



    ///////////  NPU 整体结束 //////////////
    reg npu_req_r;
    always @(posedge npu_clk) begin
        if(npu_rst) begin
            npu_req_r <= 1'b0;
        end
        else if(npu_req & npu_req_receive) begin
            npu_req_r <= 1'b0;
        end
        else if((npu_layer == m_npu_layer-1) && calculate_end) begin
            npu_req_r <= 1'b1;
        end
    end
    assign npu_req = npu_req_r;
endmodule