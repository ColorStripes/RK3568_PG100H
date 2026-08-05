module instruction_buf #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
              DATA_DEPTH = 128,          //缓存的指令数
              DEBUG = 1,
              NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER)
)(
    

    input                               clk,
    input                               rst,

    input                               calculate_end,
    input                               calculate_end_receive,

    //instruction
    input  [AXI_DATA_WIDTH-1 : 0]      s_npu_instruction,
    input                              s_npu_instruction_valid,
    output                             s_npu_instruction_ready,   
    (*mark_debug = "true"*)output                             fpga_start,
    (*mark_debug = "true"*)input                              fpga_end,
    input   [LAYER_WIDTH-1 : 0]                          layer,

    //REG的传输接口 （AXI_lite）
    output                             m_axi_awvalid,
    input                              m_axi_awready, 
    output [AXI_ADDR_WIDTH-1 : 0]      m_axi_awaddr ,


    output                             m_axi_wvalid,
    input                              m_axi_wready, 
    output [AXI_DATA_WIDTH-1 : 0]      m_axi_wdata ,
    output [AXI_DATA_WIDTH/8-1 : 0]    m_axi_wstrb ,
 
    input                              m_axi_bvalid,
    output                             m_axi_bready,
    input   [1 : 0]                    m_axi_bresp ,

    output                             m_axi_arvalid, 
    input                              m_axi_arready, 
    output  [AXI_ADDR_WIDTH-1 : 0]     m_axi_araddr,
 
 
    input                              m_axi_rvalid,
    output                             m_axi_rready, 
    input   [AXI_DATA_WIDTH-1 : 0]     m_axi_rdata ,
    input   [1 : 0]                    m_axi_rresp    
);


    localparam INSTRUCTION = 4'b0001, AXI_AW = 4'b0010, AXI_W = 4'b0100, AXI_B = 4'b1000;
    reg [3 : 0] state, next_state;
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
            // //以第一个数据作为数据走向判断
            // INSTRUCTION:begin
            //     if(m_npu_instruction_valid & m_npu_instruction_ready) begin
            //         next_state = AXI_AW;
            //     end
            //     else begin
            //         next_state = INSTRUCTION;
            //     end
            // end
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
 
    assign m_axi_awaddr = dout;
    assign m_axi_wdata  = dout;
    assign m_axi_wstrb  = {AXI_DATA_WIDTH/8{1'b1}};



    reg instruction_ready;
    always @(posedge clk) begin
        instruction_ready <= !full;
    end
    //buf
    wire full, empty;
    assign s_npu_instruction_ready  = instruction_ready; //
    wire                        wen = s_npu_instruction_valid & s_npu_instruction_ready && (s_npu_instruction != 32'hf0f0_f0f0);
    wire [AXI_DATA_WIDTH-1 : 0] din = s_npu_instruction;



/////////////////////
//记录type[7]值为三算子做准备
    reg type_7;
    always @(posedge clk) begin
        if(rst) begin
            type_7 <= 1'b0;
        end
        else if((dout_d == 32'h0000_0006) && ren && (dout[7] & (dout[2] | dout[3])) && instruction_data) begin
            type_7 <= 1'b0;
        end
        else if((dout_d == 32'h0000_0006) && ren && dout[7] && instruction_data) begin
            type_7 <= 1'b1;
        end
    end

////////
    //是指令不是地址
    (*mark_debug = "true"*)reg instruction_data;
    always @(posedge clk) begin
        if(rst) begin
            instruction_data <= 1'b0;
        end
        else if(ren) begin
            instruction_data <= ~instruction_data;
        end
    end

    //主算子有一个启动 并行算子启动不启动都行
    // wire one_start = (|dout[4:0]) && (dout[AXI_DATA_WIDTH-1 : 6] == 0);
    wire one_start = (|{dout[6], dout[4:0]}) && (dout[AXI_DATA_WIDTH-1 : 7] == 0);


    (*mark_debug = "true"*)reg instruction_valid;
    always @(posedge clk) begin
        if(rst) begin
            instruction_valid <= 1'b0;
        end
        else if((dout_d == 32'h0000_000e) && (dout == 32'd1) && instruction_data) begin
            instruction_valid <= 1'b0;
        end
        else if((s_npu_instruction == 32'hf0f0_f0f0) && s_npu_instruction_valid) begin
            instruction_valid <= 1'b1;
        end
        else if((calculate_end & calculate_end_receive) && (layer != 1)) begin
            instruction_valid <= 1'b1;
        end
        else if((dout_d == 32'h0000_0005) && ren && one_start && !type_7 && instruction_data) begin
            instruction_valid <= 1'b0;
        end
    end

    reg ending;
    always @(posedge clk) begin
        if(rst) begin
            ending <= 1'b0;
        end
        else if(ending) begin
            ending <= 1'b0;
        end
        else if((dout_d == 32'h0000_000e) && (dout == 32'd1) && instruction_data) begin
            ending <= 1'b1;
        end
    end


generate
    if(DEBUG == 1) begin
        (*mark_debug = "true"*)reg end_fpga;
        always @(posedge clk) begin
            if(rst) begin
                end_fpga <= 1'b0;
            end
            else if((dout_d == 32'h0000_000e) && (dout == 32'd1) && instruction_data) begin
                end_fpga <= 1'b0;
            end
            else if(fpga_end) begin
                end_fpga <= 1'b1;
            end
        end
        assign fpga_start = instruction_valid & ~end_fpga;
    end
endgenerate


    
//////////////////

    (*mark_debug = "true"*)reg [AXI_DATA_WIDTH-1 : 0] dout_d;
    always @(posedge clk) begin
        if(ren) begin
           dout_d <= dout; 
        end
    end


    wire fifo_valid = !empty & instruction_valid;

    // wire fifo_valid = !empty;

    wire [AXI_DATA_WIDTH-1 : 0] dout;
    wire fifo_ready;
    wire ren = fifo_valid & fifo_ready;
    assign fifo_ready = (state == AXI_AW) ? m_axi_awready :
                        (state == AXI_W)  ? m_axi_wready : 1'b0;
                        // (state == AXI_B)  ? m_axi_bready :






    sync_fifo_replay #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .DATA_DEPTH(DATA_DEPTH)
    )
    instruction_fifo(
        .clk(clk),
        .rst(rst),
        .wr_en(wen),
        .rd_en(ren),
        .rewind(ending),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

endmodule