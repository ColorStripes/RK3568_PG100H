module mac_rx_buf #(
    parameter DATA_DEPTH = 2048,
              READ_DELAY = 1
)(
    input clk,
    input rst,

    input  [7:0] s_data ,
    input        s_valid,
    input        s_last ,
    output       s_ready,
    input        s_error,


    output [7:0] m_data ,
    output       m_valid,
    output       m_last ,
    input        m_ready,
    output       m_error
);

    localparam  ADDR_WIDTH = $clog2(DATA_DEPTH);

    localparam WRITE = 3'b001, READ = 3'b010, IDLE = 3'b100;
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
                if(s_valid & s_ready & s_last) begin  
                    next_state = READ;
                end
                else begin
                    next_state = WRITE;
                end
            end 
            READ:begin
                if(m_valid & m_ready & m_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = READ;
                end
            end 
            IDLE:begin
                next_state = WRITE;
            end       
            default:begin
                next_state = WRITE;
            end
        endcase
    end


    //写操作
    assign s_ready = (state == WRITE);

    wire [8 : 0] wdata = {s_error, s_data};
    wire wen = s_valid & s_ready;

    reg [ADDR_WIDTH : 0] waddr;
    always @(posedge clk) begin
        if(rst) begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(state == IDLE) begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(wen) begin
            waddr <= waddr + 1'b1;
        end
    end




    //读操作
    wire [8 : 0] rdata;
    wire ren = m_ready && (state == READ) && (raddr < waddr);

    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk) begin
        if(rst) begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(state == IDLE) begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(ren) begin
            raddr <= raddr + 1'b1;
        end
    end

    reg r_last;
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if((raddr == waddr-2 + READ_DELAY) && (state == READ)) begin
            r_last <= 1'b1;
        end
        else begin
            r_last <= 1'b0;
        end
    end


    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(9),             //数据位宽
            .PIPE(READ_DELAY)  
    ) 
    spram_inst(
        .clk   (clk   ),
        .wdata (wdata ),
        .wen   (wen   ),
        .waddr (waddr[ADDR_WIDTH-1 : 0] ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (rdata )
    );


    assign m_data = rdata[7 : 0];
    assign m_error = rdata[8];
    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY : 0] m_valid_d, m_last_d; 
    always @(posedge clk) begin
        if(rst) begin
            m_valid_d <= 0;
            m_last_d  <= 0;
        end
        else begin
            m_valid_d <= {m_valid_d[READ_DELAY-1 : 0], ren};
            m_last_d  <= {m_last_d[READ_DELAY-1 : 0] , r_last};
        end
    end
    assign m_valid = m_valid_d[READ_DELAY-1]; 
    assign m_last  = r_last | m_error;

                 

endmodule