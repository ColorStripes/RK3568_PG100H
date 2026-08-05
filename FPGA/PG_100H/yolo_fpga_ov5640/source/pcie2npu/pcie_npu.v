`timescale 1ns / 1ps

module pcie_npu #(
    parameter AXI_DATA_WIDTH = 128,
              AXI_ADDR_WIDTH = 32,

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
    output     [31 : 0]           m_npu_instruction,
    output reg                    m_npu_instruction_valid,
    input                         m_npu_instruction_ready,

    output reg [LAYER_WIDTH-1 : 0]  m_npu_layer ,


    input                   calculate_end        ,
    output                  calculate_end_receive,


    output                      npu_req         , 
    input                       npu_req_receive           
);

    // ==========================================
    // 状态机定义 (4个状态)
    // ==========================================
    localparam IDLE = 2'b00, INSTRUCTION = 2'b01, NPU_NUM = 2'b10, WRITE_RESP = 2'b11;

    reg [1 : 0] state, next_state;
    
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

    // wready: 在 INSTRUCTION 或 NPU_NUM 状态下准备接收突发数据
    assign s_axi_wready  = (state == INSTRUCTION) || (state == NPU_NUM);

    // bvalid: 在 WRITE_RESP 状态下发出响应信号
    assign s_axi_bvalid  = (state == WRITE_RESP);
    
    // bresp: 2'b00 代表 OKAY (正常完成)
    assign s_axi_bresp   = 2'b00; 


    // -----------------------------------------------------
    // 用户逻辑扩展区：你可以利用以下两个使能信号，将 s_axi_wdata 写入 RAM 或 FIFO
    // -----------------------------------------------------
    wire npu_layer_en   = (state == NPU_NUM) && s_axi_wvalid && s_axi_wready;
    // Layer 寄存器逻辑
    always @(posedge axi_clk) begin
        if (axi_rst) begin
            m_npu_layer <= 32'h0;
        end 
        else if (npu_layer_en) begin
            m_npu_layer <= s_axi_wdata[LAYER_WIDTH-1 : 0];
        end
    end



    reg [2 : 0] remain_num /*synthesis PAP_MARK_DEBUG="1"*/;
    always @(posedge axi_clk) begin
        if (axi_rst) begin
            remain_num <= 0;
        end
        else if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
            // 完美匹配 128位 找无效 32位 的需求
            remain_num <= (!s_axi_wstrb[15:12])  + 
                          (!s_axi_wstrb[11:8] )  + 
                          (!s_axi_wstrb[7:4]  )  + 
                          (!s_axi_wstrb[3:0]  )  ;
        end
    end




    wire instr_en = (state == INSTRUCTION) && s_axi_wvalid && s_axi_wready;

    wire empty;
    wire rd_en = !empty;
    wire [8 : 0] rd_water_level;
    always @(posedge npu_clk) begin
        if(npu_rst) begin
            m_npu_instruction_valid <= 1'b0;
        end
        else begin
            m_npu_instruction_valid <= rd_en && (rd_water_level > remain_num);
        end
    end

    ins_cdc  ins_cdc(
      .wr_clk(axi_clk),               // input
      .wr_rst(axi_rst),               // input
      .wr_en(instr_en),               // input
      .wr_data(s_axi_wdata),          // input [127:0]
      .wr_full(),                     // output
      .almost_full(),                 // output

      .rd_clk(npu_clk),                // input
      .rd_rst(npu_rst),                // input
      .rd_en(rd_en),                  // input
      .rd_data(m_npu_instruction),              // output [31:0]
      .rd_empty(empty),            // output
      .rd_water_level(rd_water_level),    // output [8:0]
      .almost_empty()     // output
    );

    ////////////////////////// NPU_END  //////////////////////////


    localparam NPU_IDLE = 1'b0, NPU_END = 1'b1;
    // ==========================================
    // 第一段：状态机时序逻辑
    // ==========================================
    reg npu_state, npu_next_state;
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