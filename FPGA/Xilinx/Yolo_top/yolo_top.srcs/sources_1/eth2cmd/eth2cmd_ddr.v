module eth2cmd_ddr #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
              //向DDR写入的数据宽度
              DATA_WIDTH_IN     = 128,
              DATA_DEPTH        = 512,
    parameter HIGH_FIRST        = 0
)(
    input clk,
    input rst,

    input [AXI_ADDR_WIDTH-1 : 0] s_eth_axis_addr  ,
    input [AXI_DATA_WIDTH-1 : 0] s_eth_axis_len   ,
    input [7 : 0]                s_eth_axis_data  ,
    input                        s_eth_axis_valid ,
    input                        s_eth_axis_last  ,
    output                       s_eth_axis_ready ,

 
    output [AXI_ADDR_WIDTH-1 : 0]  m_ddr_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  m_ddr_cmd_len   ,
    output                         m_ddr_cmd_valid ,
    input                          m_ddr_cmd_ready ,
    output [DATA_WIDTH_IN-1 : 0]   m_ddr_axis_data  ,
    output [DATA_WIDTH_IN/8-1 : 0] m_ddr_axis_keep  ,
    output                         m_ddr_axis_valid ,
    output                         m_ddr_axis_last  ,
    input                          m_ddr_axis_ready 
);


    localparam WRITE = 3'b001, CMD = 3'b010, READ = 3'b100;
    reg [2 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= WRITE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            WRITE:begin
                if(s_eth_axis_valid & s_eth_axis_ready & s_eth_axis_last) begin
                    next_state = CMD;
                end
                else begin
                    next_state = WRITE;
                end
            end
            //指令
            CMD:begin
                if(m_ddr_cmd_valid & m_ddr_cmd_ready) begin
                    next_state = READ;
                end
                else begin
                    next_state = CMD;
                end
            end
            //数据
            READ:begin
                if(m_ddr_axis_valid & m_ddr_axis_ready & m_ddr_axis_last) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = READ;
                end
            end
            default:begin
                next_state = WRITE;
            end
        endcase
    end

    assign s_eth_axis_ready = (state == WRITE);

    //cmd
    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr;
    always @(posedge clk) begin
        if(state == WRITE) begin
          cmd_addr <= s_eth_axis_addr;  
        end
    end

    reg [AXI_DATA_WIDTH-1 : 0] cmd_len;
    always @(posedge clk) begin
        if(state == WRITE) begin
            cmd_len <= s_eth_axis_len;
        end
    end

    reg cmd_valid;
    always @(posedge clk) begin
        if(rst) begin
            cmd_valid <= 1'b0;
        end
        else if(m_ddr_cmd_valid & m_ddr_cmd_ready) begin
            cmd_valid <= 1'b0;
        end
        else if(state == CMD) begin
            cmd_valid <= 1'b1;
        end
    end

    assign m_ddr_cmd_valid = cmd_valid;
    assign m_ddr_cmd_addr  = cmd_addr;
    assign m_ddr_cmd_len   = cmd_len;


    //data
    localparam DATA_CNT_WIDTH = $clog2(DATA_WIDTH_IN/8);
    reg [DATA_CNT_WIDTH-1 : 0] data_cnt;
    always @(posedge clk) begin
        if(rst) begin
            data_cnt <= 0;
        end
        else if((state == WRITE) && s_eth_axis_valid) begin
            data_cnt <= data_cnt + 1'b1;
        end
        else if(state == READ) begin
            data_cnt <= 0;
        end
    end

    reg [DATA_WIDTH_IN-1 : 0] data;
    generate
        if (HIGH_FIRST == 1) begin : GEN_HIGH_FIRST
            // 先收到的是高位
            always @(posedge clk) begin
                if ((state == WRITE) && s_eth_axis_valid) begin
                    data <= {data[DATA_WIDTH_IN-1-8 : 0], s_eth_axis_data};
                end
            end
        end 
        else begin : GEN_LOW_FIRST
            // 先收到的是低位
            always @(posedge clk) begin
                if ((state == WRITE) && s_eth_axis_valid) begin
                    data <= {s_eth_axis_data, data[DATA_WIDTH_IN-1 : 8]};
                end
            end
        end
    endgenerate

    reg data_valid;
    always @(posedge clk) begin
        if(rst) begin
            data_valid <= 1'b0;
        end
        else if((data_cnt == (DATA_WIDTH_IN/8 - 1)) || (s_eth_axis_last & s_eth_axis_valid)) begin     //应对窄传输
            data_valid <= 1'b1;           
        end
        else begin
            data_valid <= 1'b0;
        end
    end

    reg data_last;
    always @(posedge clk) begin
        if(rst) begin
            data_last <= 1'b0;
        end
        else begin
            data_last <= s_eth_axis_last & s_eth_axis_valid;
        end
    end


    //窄传输计数器
    reg [DATA_CNT_WIDTH-1 : 0] keep_cnt;
    always @(posedge clk) begin
        if(s_eth_axis_valid & s_eth_axis_last) begin
            keep_cnt <= data_cnt + 1;
        end
    end

    wire full, empty;
    wire data_ready = !full;
    wire wen = data_valid & data_ready;



    wire [DATA_WIDTH_IN : 0] dout;
    assign m_ddr_axis_valid = (state == READ);
    assign m_ddr_axis_last  = dout[DATA_WIDTH_IN] & m_ddr_axis_valid;
    generate
        if (HIGH_FIRST == 1) begin : M_GEN_HIGH_FIRST
            assign m_ddr_axis_data  = !m_ddr_axis_last ? dout[DATA_WIDTH_IN-1 : 0] :
                                      (keep_cnt == 0)  ? dout[DATA_WIDTH_IN-1 : 0] : dout[DATA_WIDTH_IN-1 : 0] << (((DATA_WIDTH_IN/8) - keep_cnt) << 3);
            assign m_ddr_axis_keep  = !m_ddr_axis_last ? {DATA_WIDTH_IN/8{1'b1}} :
                                      (keep_cnt == 0)  ? {DATA_WIDTH_IN/8{1'b1}} : (({(DATA_WIDTH_IN/8){1'b1}}) << ((DATA_WIDTH_IN/8) - keep_cnt));
        end
        else begin : M_GEN_LOW_FIRST
            assign m_ddr_axis_data  = !m_ddr_axis_last ? dout[DATA_WIDTH_IN-1 : 0] :
                                      (keep_cnt == 0)  ? dout[DATA_WIDTH_IN-1 : 0] : dout[DATA_WIDTH_IN-1 : 0] >> (((DATA_WIDTH_IN/8) - keep_cnt) << 3);
            assign m_ddr_axis_keep  = !m_ddr_axis_last ? {DATA_WIDTH_IN/8{1'b1}} :
                                      (keep_cnt == 0)  ? {DATA_WIDTH_IN/8{1'b1}} : ((1 << keep_cnt)-1);
        end
    endgenerate                                                           

    
    wire ren = m_ddr_axis_valid & m_ddr_axis_ready;
    

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH_IN+1),
        .DATA_DEPTH(DATA_DEPTH)
    )
    to_ddr_fifo(
        .clk(clk),
        .rst(rst),
        .wr_en(wen),
        .rd_en(ren),
        .din({data_last, data}),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    
endmodule