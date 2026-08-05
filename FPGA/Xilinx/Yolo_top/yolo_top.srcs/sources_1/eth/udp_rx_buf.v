module udp_rx_buf #(
    parameter DATA_WIDTH = 8,
              DATA_DEPTH = 2048
)(
    input clk,
    input rst,

    input                   s_crc_error, 
    input                   s_crc_no_error,
    input  [DATA_WIDTH-1:0] s_data ,
    input                   s_valid,
    input                   s_last ,
    output                  s_ready,


    output [DATA_WIDTH-1:0] m_data ,
    output                  m_valid,
    output                  m_last ,
    input                   m_ready
);


    localparam WRITE = 3'b001, CRC_NO_ERROR = 3'b010, READ = 3'b100;
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
                    next_state = CRC_NO_ERROR;
                end
                else begin
                    next_state = WRITE;
                end
            end
            CRC_NO_ERROR:begin
                if(s_crc_no_error) begin  
                    next_state = READ;
                end
                else if(s_crc_error) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = CRC_NO_ERROR;
                end
            end
            READ:begin
                if(m_valid & m_ready & m_last) begin
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


    wire full, empty;

    //Ð´²Ù×÷
    wire [DATA_WIDTH : 0] din = {s_last, s_data};
    wire wen = s_valid & s_ready;
    assign s_ready = (state == WRITE) & !full;


    //¶Á²Ù×÷
    wire [DATA_WIDTH : 0] dout;
    wire ren = m_valid & m_ready;
    assign m_valid = !empty & (state == READ);
    assign m_last = dout[DATA_WIDTH] & m_valid;
    assign m_data = dout[DATA_WIDTH-1 : 0];


    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH+1),
        .DATA_DEPTH(DATA_DEPTH)
    )
    sync_fifo_udp_rx(
        .clk(clk),
        .rst(rst | s_crc_error),
        .wr_en(wen),
        .rd_en(ren),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );



    



endmodule
