module mac_rx_ctl #(
   parameter DATA_DEPTH = 2048,
             READ_DELAY = 1
)(
    input          clk     ,
    input          rst     ,


    input  [7:0]   s_data  ,
    input          s_valid ,
    input          s_last  ,
    output         s_ready ,
    input          s_error ,


    output  [7:0]   m_data  ,
    output          m_valid ,
    output          m_last  ,
    input           m_ready ,
    output          m_error 
);

/////////////ping pang/////////////////////

    wire [7 : 0] ping_s_data;
    wire         ping_s_valid;
    wire         ping_s_last;
    wire         ping_s_ready;
    wire         ping_s_error;      


    wire [7 : 0] pang_s_data;
    wire         pang_s_valid;
    wire         pang_s_last;
    wire         pang_s_ready;
    wire         pang_s_error;    

    reg w_ctl;
    always @(posedge clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(s_valid & s_ready & s_last) begin
            w_ctl <= !w_ctl;
        end
    end

    assign ping_s_data  = s_data;
    assign ping_s_valid = w_ctl ? 1'b0 : s_valid;
    assign ping_s_last  = w_ctl ? 1'b0 : s_last;
    assign ping_s_error = s_error;

    assign pang_s_data  = s_data;
    assign pang_s_valid = w_ctl ? s_valid : 1'b0;
    assign pang_s_last  = w_ctl ? s_last : 1'b0;
    assign pang_s_error = s_error;

    assign s_ready = w_ctl ? pang_s_ready : ping_s_ready;



    //read
    wire [7 : 0] ping_m_data;
    wire         ping_m_valid;
    wire         ping_m_last;
    wire         ping_m_ready;
    wire         ping_m_error;      

    wire [7 : 0] pang_m_data;
    wire         pang_m_valid;
    wire         pang_m_last;
    wire         pang_m_ready;
    wire         pang_m_error;   

    reg r_ctl;
    always @(posedge clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_valid & m_ready & m_last) begin
            r_ctl <= !r_ctl;
        end
    end


    assign m_data  = r_ctl ? pang_m_data : ping_m_data;
    assign m_error = r_ctl ? pang_m_error : ping_m_error;
    assign m_valid = r_ctl ? pang_m_valid : ping_m_valid;
    assign m_last  = r_ctl ? pang_m_last : ping_m_last;
    assign ping_m_ready = r_ctl ? 1'b0 : m_ready;
    assign pang_m_ready = r_ctl ? m_ready : 1'b0;





//ping pang buf
    mac_rx_buf #(
        .DATA_DEPTH(DATA_DEPTH),
        .READ_DELAY(READ_DELAY)
    )
    mac_rx_buf_ping(
        .clk(clk),
        .rst(rst),

        .s_data (ping_s_data ),
        .s_valid(ping_s_valid),
        .s_last (ping_s_last ),
        .s_ready(ping_s_ready),
        .s_error(ping_s_error),


        .m_data (ping_m_data ),
        .m_valid(ping_m_valid),
        .m_last (ping_m_last ),
        .m_ready(ping_m_ready),
        .m_error(ping_m_error)
    );


    mac_rx_buf #(
        .DATA_DEPTH(DATA_DEPTH),
        .READ_DELAY(READ_DELAY)
    )
    mac_rx_buf_pang(
        .clk(clk),
        .rst(rst),
    
        .s_data (pang_s_data ),
        .s_valid(pang_s_valid),
        .s_last (pang_s_last ),
        .s_ready(pang_s_ready),
        .s_error(pang_s_error),
    
    
        .m_data (pang_m_data ),
        .m_valid(pang_m_valid),
        .m_last (pang_m_last ),
        .m_ready(pang_m_ready),
        .m_error(pang_m_error)
    );

endmodule