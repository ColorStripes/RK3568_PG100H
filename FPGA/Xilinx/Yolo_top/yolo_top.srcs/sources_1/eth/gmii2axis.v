module gmii2axis # (
    parameter DATA_DEPTH = 2048
)(

    input           rst         ,
    //gmii½Ó¿Ú 
    input           gmii_rx_clk ,
    input           gmii_rx_dv  ,
    input           gmii_rx_er  ,
    input  [7 : 0]  gmii_rx_data,    
    

    output [7 : 0]  m_axis_data  ,
    output          m_axis_valid ,
    output          m_axis_last  ,
    output          m_axis_user  
    
);

    reg [7 : 0] gmii_rx_data_d;
    reg         gmii_rx_dv_d;
    reg         gmii_rx_er_d;
    always @(posedge gmii_rx_clk) begin
        if(rst) begin
            gmii_rx_dv_d   <= 1'b0;
            gmii_rx_er_d   <= 1'b0;
        end
        else begin
           gmii_rx_data_d <= gmii_rx_data;
           gmii_rx_dv_d   <= gmii_rx_dv;
           gmii_rx_er_d   <= gmii_rx_er; 
        end
    end


    assign m_axis_valid = gmii_rx_dv_d;
    assign m_axis_data  = gmii_rx_data_d              ;
    assign m_axis_user  = gmii_rx_er_d & gmii_rx_dv_d ;
    assign m_axis_last  = gmii_rx_dv_d & (!gmii_rx_dv);

endmodule