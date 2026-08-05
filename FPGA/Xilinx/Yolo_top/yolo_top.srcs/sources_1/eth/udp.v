module udp #(
    parameter TX_DATA_DEPTH = 2048,                         //支持缓存的最大数据深度 
              RX_DATA_DEPTH = 2048,
              READ_DELAY = 1
)(
    input clk,
    input rst,

    //本地信息
    input  [31 : 0] loca_ip      ,
    input  [15 : 0] loca_port    ,
    //udp的所有配置信息
    input  [31 : 0] udp_tx_dst_ip    ,
    input  [15 : 0] udp_tx_dst_port  ,
    //udp报文长度
    output [15 : 0] udp_len       ,
    //告诉ip层数据要发往哪个ip 和当前ip
    output [31 : 0]  udp_src_ip   ,
    output [31 : 0]  udp_dst_ip   ,
    //tx用户数据输
    input  [7 : 0]  s_udp_axis_data  ,
    input           s_udp_axis_valid ,
    input           s_udp_axis_last  ,
    output          s_udp_axis_ready , 

    //rx
    //用户数据发出
    output  [7 : 0]  m_udp_axis_data  ,
    output           m_udp_axis_valid , 
    output           m_udp_axis_last  ,
    input            m_udp_axis_ready ,



    //rx
    input           crc_error,
    input           crc_no_error,
    //从ip层进入解析
    input  [7 : 0]  s_ip_axis_data   ,
    input           s_ip_axis_valid  ,
    input           s_ip_axis_last   ,
    output          s_ip_axis_ready  ,   //这里这个ready不能反压上级  只能看是不是full   接受是实时的 没办法反压不接受
    input           s_ip_axis_error  ,

    //tx
    //请求控制IP层
    input           m_ip_axis_get   ,
    output          m_ip_axis_req   ,
    //控制IP层   
    output  [7 : 0] m_ip_axis_data  ,    
    output          m_ip_axis_valid ,
    input           m_ip_axis_ready ,
    output          m_ip_axis_last  
);



    udp_tx #(
        .DATA_DEPTH(TX_DATA_DEPTH),                         //支持缓存的最大数据深度 
        .READ_DELAY(READ_DELAY)
    )
    udp_tx_inst(
        .clk(clk),
        .rst(rst),

        //本地信息
        .loca_ip  (loca_ip)      ,
        .loca_port(loca_port)    ,
        //udp的所有配置信息
        .udp_tx_dst_ip  (udp_tx_dst_ip)    ,
        .udp_tx_dst_port(udp_tx_dst_port)  ,
        //用户数据输入
        .s_udp_axis_data (s_udp_axis_data ) ,
        .s_udp_axis_valid(s_udp_axis_valid) ,
        .s_udp_axis_last (s_udp_axis_last ) ,
        .s_udp_axis_ready(s_udp_axis_ready) , 


        .udp_len(udp_len)  ,
        .udp_src_ip(udp_src_ip)   ,
        .udp_dst_ip(udp_dst_ip)   ,
        //请求控制IP层
        .m_ip_axis_get  (m_ip_axis_get) ,
        .m_ip_axis_req  (m_ip_axis_req) ,
        //控制IP层   
        .m_ip_axis_data (m_ip_axis_data ) ,    
        .m_ip_axis_valid(m_ip_axis_valid) ,
        .m_ip_axis_ready(m_ip_axis_ready) ,
        .m_ip_axis_last (m_ip_axis_last ) 
    );




    udp_rx #(
        .DATA_DEPTH(RX_DATA_DEPTH)
    )
    udp_rx_inst(

        .clk(clk),
        .rst(rst),


        //本地信息
        .loca_port(loca_port)  ,
        .crc_error(crc_error),
        .crc_no_error(crc_no_error),

        //从ip层进入解析
        .s_ip_axis_data (s_ip_axis_data )  ,
        .s_ip_axis_valid(s_ip_axis_valid)  ,
        .s_ip_axis_last (s_ip_axis_last )  ,
        .s_ip_axis_ready(s_ip_axis_ready)  ,   //这里这个ready不能反压上级  只能看是不是full   接受是实时的 没办法反压不接受
        .s_ip_axis_error(s_ip_axis_error)  ,


        //用户数据发出
        .m_udp_axis_data  (m_udp_axis_data  ),
        .m_udp_axis_valid (m_udp_axis_valid ), 
        .m_udp_axis_last  (m_udp_axis_last  ),
        .m_udp_axis_ready (m_udp_axis_ready ) 
        // output              m_udp_axis_error  
    );


endmodule