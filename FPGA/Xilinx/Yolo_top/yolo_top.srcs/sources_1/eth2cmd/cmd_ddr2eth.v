module cmd_ddr2eth #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
              //向DDR写入的数据宽度
              DATA_WIDTH_OUT    = 128,
              DATA_DEPTH        = 512 * DATA_WIDTH_OUT / 8
)(
    input clk,
    input rst,

    input                          s_eth_axis_req   ,
    input [AXI_ADDR_WIDTH-1 : 0]   s_eth_axis_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]   s_eth_axis_len   ,
    input [DATA_WIDTH_OUT-1 : 0]   s_ddr_axis_data  ,
    input [DATA_WIDTH_OUT/8-1 : 0] s_ddr_axis_keep  ,
    input                          s_ddr_axis_valid ,
    input                          s_ddr_axis_last  ,
    output                         s_ddr_axis_ready ,


    output [AXI_ADDR_WIDTH-1 : 0] m_ddr_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0] m_ddr_cmd_len   ,
    output                        m_ddr_cmd_valid ,
    input                         m_ddr_cmd_ready ,
    output [7 : 0]                m_eth_axis_data  ,
    output                        m_eth_axis_valid , 
    output                        m_eth_axis_last  ,
    input                         m_eth_axis_ready 
);


    localparam CMD = 2'b01, WRITE = 2'b10;
    reg [1 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= CMD;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            //指令
            CMD:begin
                if(m_ddr_cmd_valid & m_ddr_cmd_ready) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = CMD;
                end
            end
            WRITE:begin
                if(s_ddr_axis_valid & s_ddr_axis_ready & s_ddr_axis_last) begin
                    next_state = CMD;
                end
                else begin
                    next_state = WRITE;
                end
            end
            // //数据
            // READ:begin
            //     if(m_ddr_axis_valid & m_ddr_axis_ready & m_ddr_axis_last) begin
            //         next_state = WRITE;
            //     end
            //     else begin
            //         next_state = READ;
            //     end
            // end
            default:begin
                next_state = CMD;
            end
        endcase
    end

    //cmd
    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr;
    always @(posedge clk) begin
        if(state == CMD) begin
          cmd_addr <= s_eth_axis_addr;  
        end
    end

    reg [AXI_DATA_WIDTH-1 : 0] cmd_len;
    always @(posedge clk) begin
        if(state == CMD) begin
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
            cmd_valid <= s_eth_axis_req;
        end
    end

    assign m_ddr_cmd_valid = cmd_valid;
    assign m_ddr_cmd_addr  = cmd_addr;
    assign m_ddr_cmd_len   = cmd_len;


    //data
    localparam DATA_CNT_WIDTH = $clog2(DATA_WIDTH_OUT/8);
    reg [DATA_CNT_WIDTH-1 : 0] data_cnt;
    always @(posedge clk) begin
        if(rst) begin
            data_cnt <= 0;
        end
        else if((state == WRITE) && s_ddr_axis_valid) begin
            data_cnt <= data_cnt + 1'b1;
        end
        else begin
            data_cnt <= 0;
        end
    end

    integer i;
    reg [DATA_WIDTH_OUT-1-8 : 0] data_tmp;
    always @(posedge clk) begin
        if((state == WRITE) && s_ddr_axis_valid) begin
            if(data_cnt == 0) begin
                // data_tmp <= s_ddr_axis_data; 
                data_tmp <= {DATA_WIDTH_OUT{1'b0}};
                for (i = 0; i < DATA_WIDTH_OUT/8-1; i = i + 1) begin
                    if(s_ddr_axis_keep[i]) begin
                        data_tmp[i*8 +: 8] <= s_ddr_axis_data[(i+1)*8 +: 8];
                    end
                    // else begin
                    //     data_tmp[i*8 +: 8] <= 8'd0;
                    // end
                end
            end
            else begin
                data_tmp <= data_tmp >> 8;
            end       
        end
    end



    reg [7 : 0] data;
    always @(posedge clk) begin
        if(data_cnt == 0) begin
            data <= s_ddr_axis_data[7 : 0];
        end
        else begin
            data <= data_tmp[7 : 0];
        end
    end
    

    reg data_valid;
    always @(posedge clk) begin
        if(rst) begin
            data_valid <= 1'b0;
        end
        else if((state == WRITE) && s_ddr_axis_valid) begin
            data_valid <= s_ddr_axis_keep[data_cnt];           
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
        else if(s_ddr_axis_keep[DATA_WIDTH_OUT/8-1]) begin
            if(data_cnt == (DATA_WIDTH_OUT/8-1)) begin
                data_last <= s_ddr_axis_last;
            end
        end
        else if(s_ddr_axis_keep[data_cnt] & ~s_ddr_axis_keep[data_cnt+1]) begin
            data_last <= s_ddr_axis_last;
        end
        else begin
            data_last <= 1'b0;
        end
    end

    assign s_ddr_axis_ready = (data_cnt == (DATA_WIDTH_OUT/8-1)) && (state == WRITE) && data_ready;



    wire full, empty;
    wire data_ready = !full;
    wire wen = data_valid;
    
    // reg eth_axis_valid;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         eth_axis_valid <= 1'b0;
    //     end
    //     else if(m_eth_axis_last) begin
    //         eth_axis_valid <= 1'b0;
    //     end
    //     else begin
    //         eth_axis_valid <= !empty;
    //     end
    // end
    // assign m_eth_axis_valid = eth_axis_valid & !empty;
    assign m_eth_axis_valid = !empty;

    wire [8 : 0] dout;
    assign m_eth_axis_data  = dout[7 : 0];
    assign m_eth_axis_last  = dout[8] & m_eth_axis_valid;
    wire ren = m_eth_axis_valid & m_eth_axis_ready;
    

    sync_fifo #(
        .DATA_WIDTH(9),
        .DATA_DEPTH(DATA_DEPTH)
    )
    to_eth_fifo(
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