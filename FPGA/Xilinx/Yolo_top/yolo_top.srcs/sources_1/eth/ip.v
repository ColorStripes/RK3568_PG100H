module ip(
    input clk,
    input rst,

    //本地信息
    input [31 : 0] loca_ip,
    //tx发送所需信息
    input [15 : 0] ip_tx_total_len,
    input [15 : 0] ip_tx_id,
    input [15 : 0] ip_tx_offset,
    input [7 : 0]  ip_tx_ttl,
    input [7 : 0]  ip_tx_protocol,
    // input [15 : 0] ip_tx_checksum,
    input [31 : 0] ip_tx_dst_ip,


    //UDP向IP层发送的数据 tx
    output            s_udp_axis_get   ,
    input             s_udp_axis_req   ,
    //UDP报文
    input  [7 : 0]    s_udp_axis_data  ,
    input             s_udp_axis_valid ,
    input             s_udp_axis_last  ,
    output            s_udp_axis_ready , 


    //从ip进入udp解析 rx
    output  [7 : 0]  m_udp_axis_data  ,
    output           m_udp_axis_valid , 
    output           m_udp_axis_last  ,
    input            m_udp_axis_ready ,
    output           m_udp_axis_error ,





    //从mac进入ip层解析 rx
    input  [7 : 0]  s_mac_axis_data   ,
    input           s_mac_axis_valid  ,
    input           s_mac_axis_last   ,
    output          s_mac_axis_ready  ,   //这里这个ready不能反压上级    接受是实时的 没办法反压不接受
    input           s_mac_axis_error  ,


    //请求控制MAC层总线 tx
    input          m_mac_axis_get   ,
    output         m_mac_axis_req   ,
    //控制MAC层总线数据   
    output [ 7:0]  m_mac_axis_data  ,    
    output         m_mac_axis_valid ,
    input          m_mac_axis_ready ,
    output         m_mac_axis_last  

);






    ip_tx ip_tx(
        .clk(clk),
        .rst(rst),

        .loca_ip        (loca_ip        ),
        .ip_tx_total_len(ip_tx_total_len),
        .ip_tx_id       (ip_tx_id       ),
        .ip_tx_offset   (ip_tx_offset   ),
        .ip_tx_ttl      (ip_tx_ttl      ),
        .ip_tx_protocol (ip_tx_protocol ),
        // .ip_tx_checksum (ip_tx_checksum ),
        .ip_tx_dst_ip   (ip_tx_dst_ip   ),


        //请求控制IP层
        .s_udp_axis_get(s_udp_axis_get)   ,
        .s_udp_axis_req(s_udp_axis_req)   ,
        //UDP报文
        .s_udp_axis_data (s_udp_axis_data ) ,
        .s_udp_axis_valid(s_udp_axis_valid) ,
        .s_udp_axis_last (s_udp_axis_last ) ,
        .s_udp_axis_ready(s_udp_axis_ready) , 


        //请求控制MAC层总线
        .m_mac_axis_get(m_mac_axis_get)   ,
        .m_mac_axis_req(m_mac_axis_req)   ,
        //控制MAC层总线数据   
        .m_mac_axis_data (m_mac_axis_data ) ,    
        .m_mac_axis_valid(m_mac_axis_valid) ,
        .m_mac_axis_ready(m_mac_axis_ready) ,
        .m_mac_axis_last (m_mac_axis_last ) 

    );



    ip_rx ip_rx(

        .clk(clk),
        .rst(rst),


        //本地信息
        .loca_ip(loca_ip),

        //进入ip层解析
        .s_mac_axis_data (s_mac_axis_data )  ,
        .s_mac_axis_valid(s_mac_axis_valid)  ,
        .s_mac_axis_last (s_mac_axis_last )  ,
        .s_mac_axis_ready(s_mac_axis_ready)  ,   //这里这个ready不能反压上级    接受是实时的 没办法反压不接受
        .s_mac_axis_error(s_mac_axis_error)  ,



        //进入udp解析
        .m_udp_axis_data (m_udp_axis_data ) ,
        .m_udp_axis_valid(m_udp_axis_valid) , 
        .m_udp_axis_last (m_udp_axis_last ) ,
        .m_udp_axis_ready(m_udp_axis_ready) ,
        .m_udp_axis_error(m_udp_axis_error)

    );


endmodule