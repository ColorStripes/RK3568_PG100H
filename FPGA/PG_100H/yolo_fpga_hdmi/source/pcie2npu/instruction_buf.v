module instruction_buf #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter INSTRUCTION_WIDTH = 32,
              NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER + 1)

)(
    

    input                               clk,
    input                               rst,

    input                              calculate_end        /*synthesis PAP_MARK_DEBUG="1"*/,
    input                              calculate_end_receive/*synthesis PAP_MARK_DEBUG="1"*/,




    input                           s_npu_start/*synthesis PAP_MARK_DEBUG="1"*/,
    input [INSTRUCTION_WIDTH-1 : 0] s_npu_instruction/*synthesis PAP_MARK_DEBUG="1"*/,
    input                           s_almost_empty,
    output                          s_npu_instruction_ren/*synthesis PAP_MARK_DEBUG="1"*/,
    output                          s_npu_instruction_rewind,


    

    

    input   [LAYER_WIDTH-1 : 0]        npu_layer,

    //REG的传输接口 （AXI_lite）
    output                             m_axi_awvalid,
    input                              m_axi_awready, 
    output [AXI_ADDR_WIDTH-1 : 0]      m_axi_awaddr ,

    output                             m_axi_wvalid ,
    input                              m_axi_wready , 
    output [AXI_DATA_WIDTH-1 : 0]      m_axi_wdata  ,
    output [AXI_DATA_WIDTH/8-1 : 0]    m_axi_wstrb  ,
 
    input                              m_axi_bvalid ,
    output                             m_axi_bready ,
    input   [1 : 0]                    m_axi_bresp  ,

    output                             m_axi_arvalid, 
    input                              m_axi_arready, 
    output  [AXI_ADDR_WIDTH-1 : 0]     m_axi_araddr ,

    input                              m_axi_rvalid ,
    output                             m_axi_rready , 
    input   [AXI_DATA_WIDTH-1 : 0]     m_axi_rdata  ,
    input   [1 : 0]                    m_axi_rresp    
);


    localparam INSTRUCTION = 4'b0001, AXI_AW = 4'b0010, AXI_W = 4'b0100, AXI_B = 4'b1000;
    reg [3 : 0] state/*synthesis PAP_MARK_DEBUG="1"*/;
    reg [3 : 0] next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= AXI_AW;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            AXI_AW:begin
                if(m_axi_awvalid & m_axi_awready) begin
                    next_state = AXI_W;
                end
                else begin
                    next_state = AXI_AW;
                end
            end
            AXI_W:begin
                if(m_axi_wvalid & m_axi_wready) begin
                    next_state = AXI_B;
                end
                else begin
                    next_state = AXI_W;
                end
            end
            AXI_B:begin
                if(m_axi_bvalid & m_axi_bready && (m_axi_bresp == 2'b00)) begin
                    next_state = AXI_AW;
                end
                else begin
                    next_state = AXI_B;
                end
            end
            default:begin
                next_state = AXI_AW;
            end
        endcase
    end


    assign m_axi_bready = (state == AXI_B);
    assign m_axi_awvalid = fifo_valid && (state == AXI_AW);
    assign m_axi_wvalid  = fifo_valid && (state == AXI_W);
 
    assign m_axi_awaddr = s_npu_instruction;
    assign m_axi_wdata  = s_npu_instruction;
    assign m_axi_wstrb  = {AXI_DATA_WIDTH/8{1'b1}};





////////////////// 指令打拍

    reg [INSTRUCTION_WIDTH-1 : 0] dout_d;
    always @(posedge clk) begin
        if(rst) begin
           dout_d <= {INSTRUCTION_WIDTH{1'b0}};
        end
        else if(s_npu_instruction_ren) begin
           dout_d <= s_npu_instruction; 
        end
    end



/////////////////////
//记录type[7]值为三算子做准备
    reg type_7;
    always @(posedge clk) begin
        if(rst) begin
            type_7 <= 1'b0;
        end
        else if((dout_d == 32'h0000_0006) && s_npu_instruction_ren && (s_npu_instruction[7] & (s_npu_instruction[2] | s_npu_instruction[3])) && instruction_data) begin
            type_7 <= 1'b0;
        end
        else if((dout_d == 32'h0000_0006) && s_npu_instruction_ren && s_npu_instruction[7] && instruction_data) begin
            type_7 <= 1'b1;
        end
    end

//////////是指令不是地址
    
    reg instruction_data;
    always @(posedge clk) begin
        if(rst) begin
            instruction_data <= 1'b0;
        end
        else if(s_npu_instruction_ren) begin
            instruction_data <= ~instruction_data;
        end
    end


//////指令有效

    //主算子有一个启动 并行算子启动不启动都行
    wire one_start = (|{s_npu_instruction[6], s_npu_instruction[4:0]}) && (s_npu_instruction[INSTRUCTION_WIDTH-1 : 7] == 0);


    reg instruction_valid/*synthesis PAP_MARK_DEBUG="1"*/;
    always @(posedge clk) begin
        if(rst) begin
            instruction_valid <= 1'b0;
        end
        else if((dout_d == 32'h0000_000e) && (s_npu_instruction == 32'd1) && instruction_data) begin
            instruction_valid <= 1'b0;
        end
        else if(s_npu_start) begin
            instruction_valid <= 1'b1;
        end
        else if((calculate_end & calculate_end_receive) && (npu_layer != 1)) begin
            instruction_valid <= 1'b1;
        end
        else if((dout_d == 32'h0000_0005) && s_npu_instruction_ren && one_start && !type_7 && instruction_data) begin
            instruction_valid <= 1'b0;
        end
    end



    // wire fifo_valid = !s_almost_empty & instruction_valid;
    wire fifo_valid = instruction_valid;
    wire fifo_ready = (state == AXI_AW) ? m_axi_awready :
                      (state == AXI_W)  ? m_axi_wready : 1'b0;


    assign s_npu_instruction_ren = fifo_valid & fifo_ready ;


    // 记录累计读取的指令数（s_npu_instruction_ren 高电平次数），调试观察用
    reg [31:0] instruction_count/*synthesis PAP_MARK_DEBUG="1"*/;
    always @(posedge clk) begin
        if (rst)
            instruction_count <= 32'd0;
        else if (s_npu_instruction_ren)
            instruction_count <= instruction_count + 1'b1;
    end



/////// 指令截止
    reg ending;
    always @(posedge clk) begin
        if(rst) begin
            ending <= 1'b0;
        end
        else if(ending) begin
            ending <= 1'b0;
        end
        else if((dout_d == 32'h0000_000e) && (s_npu_instruction == 32'd1) && instruction_data) begin
            ending <= 1'b1;
        end
    end
    assign s_npu_instruction_rewind = ending;



    
endmodule