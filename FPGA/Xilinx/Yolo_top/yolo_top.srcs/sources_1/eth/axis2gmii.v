module axis2gmii # (
    parameter DATA_DEPTH = 2048
)(
    input  [7:0]   s_axis_data  ,
    input          s_axis_valid ,
    input          s_axis_last  ,
    output         s_axis_ready ,

    input          rst         ,
    //gmii接口 
    input              gmii_tx_clk ,
    output reg         gmii_tx_en  ,
    output reg         gmii_tx_er  ,
    output reg [7 : 0] gmii_tx_data
);


    //以太网帧间隔状态机
    localparam SEND = 2'b01, GAP = 2'b10;
    reg [1 : 0] state, next_state;
    always @(posedge gmii_tx_clk) begin
        if(rst) begin
            state <= SEND;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            SEND:begin
                if(m_axis_valid & m_axis_ready & m_axis_last) begin  
                    next_state = GAP;
                end
                else begin
                    next_state = SEND;
                end
            end 
            GAP:begin
                if(gap_cnt == 96) begin  
                    next_state = SEND;
                end
                else begin
                    next_state = GAP;
                end
            end     
            default:begin
                next_state = SEND;
            end
        endcase
    end

    reg [6:0] gap_cnt;
    always @(posedge gmii_tx_clk) begin
        if(rst) begin
            gap_cnt <= 7'd0;
        end
        else if(state == GAP) begin
            gap_cnt <= gap_cnt + 7'd1;
        end
        else begin
            gap_cnt <= 7'd0;
        end
    end





/////////////ping pang/////////////////////

    wire [7 : 0] ping_s_data;
    wire         ping_s_valid;
    wire         ping_s_last;
    wire         ping_s_ready;

    wire [7 : 0] pang_s_data;
    wire         pang_s_valid;
    wire         pang_s_last;
    wire         pang_s_ready;

    reg w_ctl;
    always @(posedge gmii_tx_clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(s_axis_valid & s_axis_ready & s_axis_last) begin
            w_ctl <= !w_ctl;
        end
    end

    assign ping_s_data  = s_axis_data;
    assign ping_s_valid = w_ctl ? 1'b0 : s_axis_valid;
    assign ping_s_last  = w_ctl ? 1'b0 : s_axis_last;

    assign pang_s_data  = s_axis_data;
    assign pang_s_valid = w_ctl ? s_axis_valid : 1'b0;
    assign pang_s_last  = w_ctl ? s_axis_last : 1'b0;

    assign s_axis_ready = w_ctl ? pang_s_ready : ping_s_ready;



    //read
    wire [7 : 0] m_axis_data;
    wire         m_axis_valid;
    wire         m_axis_last;
    wire         m_axis_ready;

    wire [7 : 0] ping_m_data;
    wire         ping_m_valid;
    wire         ping_m_last;
    wire         ping_m_ready;

    wire [7 : 0] pang_m_data;
    wire         pang_m_valid;
    wire         pang_m_last;
    wire         pang_m_ready;

    reg r_ctl;
    always @(posedge gmii_tx_clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_axis_valid & m_axis_ready & m_axis_last) begin
            r_ctl <= !r_ctl;
        end
    end

    assign m_axis_ready = (state == SEND);

    assign m_axis_data  = r_ctl ? pang_m_data : ping_m_data;
    assign m_axis_valid = r_ctl ? pang_m_valid : ping_m_valid;
    assign m_axis_last  = r_ctl ? pang_m_last : ping_m_last;
    assign ping_m_ready = r_ctl ? 1'b0 : m_axis_ready;
    assign pang_m_ready = r_ctl ? m_axis_ready : 1'b0;




    gmii_buf #(
        .DATA_DEPTH(DATA_DEPTH),
        .READ_DELAY(1)
    )
    gmii_buf_ping(
        .clk(gmii_tx_clk),
        .rst(rst),

        .s_data (ping_s_data ),
        .s_valid(ping_s_valid),
        .s_last (ping_s_last ),
        .s_ready(ping_s_ready),


        .m_data (ping_m_data ),
        .m_valid(ping_m_valid),
        .m_last (ping_m_last ),
        .m_ready(ping_m_ready)
    );




    gmii_buf #(
        .DATA_DEPTH(DATA_DEPTH),
        .READ_DELAY(1)
    )
    gmii_buf_pang(
        .clk(gmii_tx_clk),
        .rst(rst),

        .s_data (pang_s_data ),
        .s_valid(pang_s_valid),
        .s_last (pang_s_last ),
        .s_ready(pang_s_ready),


        .m_data (pang_m_data ),
        .m_valid(pang_m_valid),
        .m_last (pang_m_last ),
        .m_ready(pang_m_ready)
    );











    ///////////以太网发送///////////
    always @(posedge gmii_tx_clk) begin
        gmii_tx_en   <= m_axis_valid;
        gmii_tx_data <= m_axis_data;
        gmii_tx_er   <= 1'b0;
    end
    // assign gmii_tx_en   = m_axis_valid;
    // assign gmii_tx_data = m_axis_data;
    // assign gmii_tx_er   = 1'b0;


endmodule