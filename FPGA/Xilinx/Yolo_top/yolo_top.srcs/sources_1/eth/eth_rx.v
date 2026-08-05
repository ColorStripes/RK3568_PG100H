module eth_rx(
    input clk,
    input rst,

    //发送给arp数据
    output         arp_fcs_error,
    output         arp_fcs_no_error,
    output [7 : 0] arp_rx_data,
    output         arp_rx_valid,
    output         arp_rx_last,
    input          arp_rx_ready,
    output         arp_rx_error,


    //发送给ip数据
    output         ip_fcs_error,
    output         ip_fcs_no_error,
    output [7 : 0] ip_rx_data,
    output         ip_rx_valid,
    output         ip_rx_last,
    input          ip_rx_ready,
    output         ip_rx_error,


    //mac层收到的数据
    input [15 : 0] mac_rx_type_len,

    input          mac_fcs_error   ,
    input          mac_fcs_no_error,
    input [7 : 0]  mac_rx_data     ,
    input          mac_rx_valid    ,
    input          mac_rx_last     ,
    output         mac_rx_ready    ,
    input          mac_rx_error




);

    wire ip_message = (mac_rx_type_len == 16'h0800) ? 1'b1 : 1'b0; 

    assign arp_rx_data  = mac_rx_data;
    assign arp_rx_valid = ip_message ? 8'd0 : mac_rx_valid;
    assign arp_rx_last  = ip_message ? 8'd0 : mac_rx_last;
    assign mac_rx_ready = ip_message ? ip_rx_ready : arp_rx_ready;
    assign arp_rx_error = ip_message ? 8'd0 : mac_rx_error;

    assign ip_rx_data  = mac_rx_data;
    assign ip_rx_valid = ip_message ? mac_rx_valid : 8'd0;
    assign ip_rx_last  = ip_message ? mac_rx_last : 8'd0;
    assign ip_rx_error = ip_message ? mac_rx_error : 8'd0;


    assign arp_fcs_error = ip_message ? 1'b0 : mac_fcs_error;
    assign arp_fcs_no_error = ip_message ? 1'b0 : mac_fcs_no_error;

    assign ip_fcs_error    = ip_message ? mac_fcs_error    : 1'b0;
    assign ip_fcs_no_error = ip_message ? mac_fcs_no_error : 1'b0;

endmodule