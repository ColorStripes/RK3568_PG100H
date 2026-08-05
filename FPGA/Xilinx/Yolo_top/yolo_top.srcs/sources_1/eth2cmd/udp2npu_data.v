//从以太网接收的数据 判断是指令还是数据 通过stream_CMD 或 AXI_lite与NPU交互

module udp2npu_data #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
              DEBUG = 1,
            //   NPU_LAYER = (DEBUG == 1) ? 1 : 52,
            //   NPU_LAYER = (DEBUG == 1) ? 1 : 61,
              NPU_LAYER = 88,
              LAYER_WIDTH = $clog2(NPU_LAYER)
)(
    input clk,
    input rst,

    (*mark_debug = "true"*)input  calculate_end,
    (*mark_debug = "true"*)output calculate_end_receive,

    //eth用户数据
    //rx
    input  [7 : 0]   s_eth_axis_data  ,
    input            s_eth_axis_valid ,
    input            s_eth_axis_last  ,
    output           s_eth_axis_ready , 
    //tx
    output [7 : 0]   m_eth_axis_data  ,
    output           m_eth_axis_valid ,
    output           m_eth_axis_last  ,
    input            m_eth_axis_ready ,


    //FPGA指令
    
    output [AXI_DATA_WIDTH-1 : 0] m_npu_instruction,
    output                        m_npu_instruction_valid,
    // output                        m_npu_instruction_last ,
    input                         m_npu_instruction_ready,          //无反压信号 测试是否接收

    input                        fpga_start,
    output                       fpga_end,
    (*mark_debug = "true"*)output reg [LAYER_WIDTH-1 : 0] layer,

    //FPGA数据
    output [AXI_ADDR_WIDTH-1 : 0] s_npu_axis_addr  ,
    output [AXI_DATA_WIDTH-1 : 0] s_npu_axis_len   ,
    output                        s_npu_axis_req   ,    //开始向DDR要数据
    input  [7 : 0]                s_npu_axis_data  ,
    input                         s_npu_axis_valid ,
    input                         s_npu_axis_last  ,
    output                        s_npu_axis_ready , 

    output [AXI_ADDR_WIDTH-1 : 0] m_npu_axis_addr  ,
    output [AXI_DATA_WIDTH-1 : 0] m_npu_axis_len   ,
    output [7 : 0]                m_npu_axis_data  ,
    output                        m_npu_axis_valid ,
    output                        m_npu_axis_last  ,
    input                         m_npu_axis_ready 


);


    localparam IDLE = 6'b000001, INSTRUCTION = 6'b000010, NPU_DATA = 6'b000100, NPU_END = 6'b001000, DDR_PC = 6'b010000, PC_READY = 6'b100000;
    (*mark_debug = "true"*)reg [5 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            //以第一个数据作为数据走向判断
            IDLE:begin
                if(s_eth_axis_valid & s_eth_axis_ready) begin
                    case(s_eth_axis_data)
                        8'd1: next_state = INSTRUCTION;
                        8'd2: next_state = NPU_DATA;
                        8'd7: next_state = DDR_PC;
                        8'd8: next_state = PC_READY;
                        // 8'd8: next_state = PC_LOOPBACK;
                        default: next_state = IDLE;
                    endcase
                end
                else if(calculate_end) begin
                    next_state = NPU_END;
                end
                else begin
                    next_state = IDLE;
                end
            end
            //指令
            INSTRUCTION:begin
                if(s_eth_axis_valid & s_eth_axis_ready & s_eth_axis_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = INSTRUCTION;
                end
            end
            //数据
            NPU_DATA:begin
                if(s_eth_axis_valid & s_eth_axis_ready & s_eth_axis_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = NPU_DATA;
                end
            end
            // DDR_RECEIVE:begin
            //     if(m_eth_axis_valid & m_eth_axis_ready & m_eth_axis_last) begin
            //         next_state = IDLE;
            //     end
            //     else begin
            //         next_state = NPU_END;
            //     end
            // end
            //向PC发送计算结束信号
            NPU_END:begin
                if(npu_layer != layer-1) begin
                    next_state = IDLE;
                end
                else if(m_eth_axis_valid & m_eth_axis_ready & m_eth_axis_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = NPU_END;
                end
            end
            //从DDR返回给PC 接收从DDR读取的地址
            DDR_PC:begin
                if(s_eth_axis_valid & s_eth_axis_ready & s_eth_axis_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = DDR_PC;
                end
            end
            //接收PC完成接收的信号
            PC_READY:begin
                if(s_eth_axis_valid & s_eth_axis_ready & s_eth_axis_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = PC_READY;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end

    assign s_eth_axis_ready = (state == INSTRUCTION) ? m_npu_instruction_ready :
                              (state == NPU_DATA)    ? m_npu_axis_ready :
                              ((state == IDLE) || (state == DDR_PC) || (state == PC_READY)) ? 1'b1 : 1'b0;

    //指令处理
    localparam INSTRUCTION_CNT_WIDTH = $clog2(AXI_DATA_WIDTH/8);
    reg [INSTRUCTION_CNT_WIDTH-1 : 0] instruction_cnt;
    always @(posedge clk) begin
        if(state == IDLE) begin
            instruction_cnt <= 0;
        end
        else if((state == INSTRUCTION) && s_eth_axis_valid) begin
            instruction_cnt <= instruction_cnt + 1'b1;
        end
    end

    reg [AXI_DATA_WIDTH-1 : 0] instruction;
    always @(posedge clk) begin
        if((state == INSTRUCTION) && s_eth_axis_valid) begin
            instruction <= {instruction[AXI_DATA_WIDTH-1-8 : 0], s_eth_axis_data};
        end
    end

    reg instruction_valid;
    always @(posedge clk) begin
        if(rst) begin
            instruction_valid <= 1'b0;
        end
        else if(instruction_cnt == (AXI_DATA_WIDTH/8 - 1)) begin
            instruction_valid <= s_eth_axis_valid;           
        end
        else begin
            instruction_valid <= 1'b0;
        end
    end

    assign m_npu_instruction = instruction;
    assign m_npu_instruction_valid = instruction_valid;



    //发往DDR数据处理
    localparam ADDR_CNT_WIDTH = $clog2(AXI_ADDR_WIDTH/8 + AXI_DATA_WIDTH/8);
    reg [ADDR_CNT_WIDTH : 0] cmd_cnt;
    always @(posedge clk) begin
        if(state == IDLE) begin
            cmd_cnt <= 0;
        end
        else if( ((state == NPU_DATA) || (state == DDR_PC)) && s_eth_axis_valid && s_eth_axis_ready) begin
            if(cmd_cnt < (AXI_ADDR_WIDTH/8 + AXI_DATA_WIDTH/8)) begin
                cmd_cnt <= cmd_cnt + 1'b1;
            end
        end
    end

    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr;
    always @(posedge clk) begin
        if(((state == NPU_DATA) || (state == DDR_PC)) && s_eth_axis_valid && s_eth_axis_ready && (cmd_cnt < AXI_ADDR_WIDTH/8)) begin
            cmd_addr <= {cmd_addr[AXI_ADDR_WIDTH-1-8 : 0], s_eth_axis_data};
        end
    end

    reg [AXI_DATA_WIDTH-1 : 0] cmd_len;
    always @(posedge clk) begin
        if(((state == NPU_DATA) || (state == DDR_PC)) && s_eth_axis_valid && s_eth_axis_ready && ((cmd_cnt >= (AXI_ADDR_WIDTH/8)) && (cmd_cnt < (AXI_ADDR_WIDTH/8 + AXI_DATA_WIDTH/8)))) begin
            cmd_len <= {cmd_len[AXI_DATA_WIDTH-1-8 : 0], s_eth_axis_data};
        end
    end

    assign m_npu_axis_data  = s_eth_axis_data;
    assign m_npu_axis_valid = s_eth_axis_valid & (state == NPU_DATA) & (cmd_cnt == (AXI_ADDR_WIDTH/8 + AXI_DATA_WIDTH/8));
    assign m_npu_axis_last  = s_eth_axis_last;

    assign m_npu_axis_addr =  cmd_addr;
    assign m_npu_axis_len  =  cmd_len;


    //从DDR取回到PC
    reg [2 : 0] end_cnt;   //发送8次相同数据为结束信号
    always @(posedge clk) begin
        if(rst) begin
            end_cnt <= 3'd0;
        end
        else if(state == NPU_END) begin
            if(m_eth_axis_valid & m_eth_axis_ready)begin
                end_cnt <= end_cnt + 1'b1;
            end
        end
        else begin
            end_cnt <= 3'd0;
        end
    end

////////////////////////////////////////////////////////////////////////////////
    //插入配置层数
    // (*mark_debug = "true"*)reg [LAYER_WIDTH-1 : 0] layer;
    always @(posedge clk) begin
        if(rst) begin
            layer <= 1;
        end
        else if(state == PC_READY) begin
            layer <= s_eth_axis_data;
        end
    end
    
/////////////////////////////////////////////////////////////////////////////////

    (*mark_debug = "true"*)reg [LAYER_WIDTH-1 : 0] npu_layer;
    always @(posedge clk) begin
        if(rst) begin
            npu_layer <= 0;
        end
        else if((npu_layer == layer) && (state == IDLE)) begin
            npu_layer <= 0;
        end
        else if((state == NPU_END) && (next_state == IDLE)) begin
            npu_layer <= npu_layer + 1'b1;
        end
    end

    
    reg [7:0] send_data; // 定义输出数据为8位寄存器                                                                                                   
    assign m_eth_axis_data  = (state == NPU_END) ? send_data : s_npu_axis_data;                                                                                                             
    assign m_eth_axis_valid = (state == NPU_END) ? (npu_layer == layer-1) : s_npu_axis_valid;
    assign m_eth_axis_last  = (state == NPU_END) ? (end_cnt == 3'd7) : s_npu_axis_last;
    assign s_npu_axis_ready = m_eth_axis_ready && (state != NPU_END);

    generate
        if(DEBUG == 1) begin
            (*mark_debug = "true"*)reg [8 : 0] npu_layer_num;
            always @(posedge clk) begin
                if(rst) begin
                    npu_layer_num <= 0;
                end
                else if((npu_layer == NPU_LAYER) && (state == IDLE))begin
                    npu_layer_num <= 0;
                end
                else if((state == NPU_END) && (next_state == IDLE)) begin
                    npu_layer_num <= npu_layer_num + 1'b1;
                end
            end
        end
    endgenerate



    //接收从DDR读取地址
    reg npu_data_req;
    always @(posedge clk) begin
        if(rst) begin
            npu_data_req <=  1'b0;
        end
        else if((state == DDR_PC) && (next_state == IDLE)) begin
            npu_data_req <=  1'b1;
        end
        else if(s_npu_axis_valid & s_npu_axis_ready) begin
            npu_data_req <=  1'b0;
        end 
    end

    assign s_npu_axis_req  = npu_data_req;
    assign s_npu_axis_addr = cmd_addr;
    assign s_npu_axis_len  = cmd_len;


    //end处理
    reg end_received;
    always @(posedge clk) begin
        if(rst) begin
            end_received <= 1'b0;
        end
        else if(end_received) begin
            end_received <= 1'b0;
        end
        else if((state != NPU_END) && (next_state == NPU_END)) begin
            end_received <= 1'b1;
        end
    end
    assign calculate_end_receive = end_received;



/////////////////////////////////////////////////////

generate
    if(DEBUG == 1) begin

        assign fpga_end = (npu_layer == layer-1) && calculate_end;

        //计时控制
        (*mark_debug = "true"*)reg time_en;
        always @(posedge clk) begin
            if(rst) begin
                time_en <= 1'b0;
            end
            else if(fpga_end) begin
                time_en <= 1'b0;
            end
            else if(fpga_start) begin
                time_en <= 1'b1;
            end
        end

        //计数器
        (*mark_debug = "true"*)reg [31 : 0] time_cnt;
        always @(posedge clk) begin
            if(rst) begin
                time_cnt <= 0;
            end
            else if((state == NPU_END) && (next_state == IDLE) && (npu_layer == layer-1)) begin
                time_cnt <= 0;
            end
            else if(time_en) begin
                time_cnt <= time_cnt + 1;
            end
        end



        
        // 组合逻辑，只要 end_cnt 或 time_cnt 变化，这里立即执行
        always @(*) begin
            case (end_cnt)
                // 当 end_cnt 为 0, 1, 2, 3 时，发送 4
                3'd0, 3'd1, 3'd2, 3'd3: begin
                    send_data = 8'd4;
                end

                // 当 end_cnt 为 4 时，发送 time_cnt 的低8位 [7:0]
                3'd4: begin
                    send_data = time_cnt[7:0];
                end

                // 当 end_cnt 为 5 时，发送 time_cnt 的 [15:8]
                3'd5: begin
                    send_data = time_cnt[15:8];
                end

                // 当 end_cnt 为 6 时，发送 time_cnt 的 [23:16]
                3'd6: begin
                    send_data = time_cnt[23:16];
                end

                // 当 end_cnt 为 7 时，发送 time_cnt 的高8位 [31:24]
                3'd7: begin
                    send_data = time_cnt[31:24];
                end

                // 良好的编程习惯：添加默认情况防止生成锁存器(Latch)
                default: begin
                    send_data = 8'd0; 
                end
            endcase
        end

    end
    else begin
        always @(posedge clk) begin
            send_data <= 4; // 定义输出数据为8位寄存器
        end
    end


endgenerate

endmodule