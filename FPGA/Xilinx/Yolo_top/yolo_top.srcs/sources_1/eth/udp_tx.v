module udp_tx #(
    parameter DATA_DEPTH = 2048,                         //支持缓存的最大数据深度 
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
    //用户数据输入
    input  [7 : 0]  s_udp_axis_data  ,
    input           s_udp_axis_valid ,
    input           s_udp_axis_last  ,
    output          s_udp_axis_ready , 


    //告诉len
    output [15 : 0]  udp_len      ,  
    //告诉ip层数据要发往哪个ip 和当前ip
    output [31 : 0]  udp_src_ip   ,
    output [31 : 0]  udp_dst_ip   ,
    //请求控制IP层
    input           m_ip_axis_get   ,
    output          m_ip_axis_req   ,
    //控制IP层   
    output  [7 : 0] m_ip_axis_data  ,    
    output          m_ip_axis_valid ,
    input           m_ip_axis_ready ,
    output          m_ip_axis_last  
);





        //ping
        //本地信息
        wire  [31 : 0]  ping_loca_ip      ;
        wire  [15 : 0]  ping_loca_port    ;
        //udp的所有配置信息
        wire  [31 : 0]  ping_udp_tx_dst_ip    ;
        wire  [15 : 0]  ping_udp_tx_dst_port  ;
        //用户数据输入
        wire  [7 : 0]   ping_s_udp_axis_data  ;
        wire            ping_s_udp_axis_valid ;
        wire            ping_s_udp_axis_last  ;
        wire            ping_s_udp_axis_ready ;
        //len
        wire [15 : 0]   ping_udp_len         ;  
        wire [31 : 0]   ping_udp_src_ip      ;
        wire [31 : 0]   ping_udp_dst_ip      ; 
        //请求控制IP层
        wire            ping_m_ip_axis_get   ;
        wire            ping_m_ip_axis_req   ;
        //控制IP层   
        wire [7 : 0]    ping_m_ip_axis_data  ;    
        wire            ping_m_ip_axis_valid ;
        wire            ping_m_ip_axis_last  ;
        wire            ping_m_ip_axis_ready ;


        //pang
        //本地信息
        wire  [31 : 0]  pang_loca_ip      ;
        wire  [15 : 0]  pang_loca_port    ;
        //udp的所有配置信息
        wire  [31 : 0]  pang_udp_tx_dst_ip    ;
        wire  [15 : 0]  pang_udp_tx_dst_port  ;
        //用户数据输入
        wire  [7 : 0]   pang_s_udp_axis_data  ;
        wire            pang_s_udp_axis_valid ;
        wire            pang_s_udp_axis_last  ;
        wire            pang_s_udp_axis_ready ; 
        //len
        wire [15 : 0]   pang_udp_len         ;  
        wire [31 : 0]   pang_udp_src_ip      ;
        wire [31 : 0]   pang_udp_dst_ip      ; 
        //请求控制IP层
        wire            pang_m_ip_axis_get   ;
        wire            pang_m_ip_axis_req   ;
        //控制IP层   
        wire [ 7:0]     pang_m_ip_axis_data  ;    
        wire            pang_m_ip_axis_valid ;
        wire            pang_m_ip_axis_last  ;
        wire            pang_m_ip_axis_ready ;


    udp_tx_ctrl udp_tx_ctrl(
        .clk(clk)              ,
        .rst(rst)              ,

        //本地信息
        .loca_ip(loca_ip)        ,
        .loca_port(loca_port)    ,
        //udp的所有配置信息
        .udp_tx_dst_ip  (udp_tx_dst_ip)   ,
        .udp_tx_dst_port(udp_tx_dst_port)  ,
        //用户数据输入
        .s_udp_axis_data (s_udp_axis_data ) ,
        .s_udp_axis_valid(s_udp_axis_valid) ,
        .s_udp_axis_last (s_udp_axis_last ) ,
        .s_udp_axis_ready(s_udp_axis_ready) , 


        //len
        .udp_len(udp_len),
        .udp_src_ip(udp_src_ip)   ,
        .udp_dst_ip(udp_dst_ip)   ,
        //请求控制IP层
        .m_ip_axis_get(m_ip_axis_get)   ,
        .m_ip_axis_req(m_ip_axis_req)   ,
        //控制IP层   
        .m_ip_axis_data (m_ip_axis_data ) ,    
        .m_ip_axis_valid(m_ip_axis_valid) ,
        .m_ip_axis_last (m_ip_axis_last ) ,
        .m_ip_axis_ready(m_ip_axis_ready) ,



        //ping
        //本地信息
        .ping_loca_ip         (ping_loca_ip)          ,
        .ping_loca_port       (ping_loca_port)        ,
        //udp的所有配置信息
        .ping_udp_tx_dst_ip   (ping_udp_tx_dst_ip)    ,
        .ping_udp_tx_dst_port (ping_udp_tx_dst_port)  ,
        //用户数据输入
        .ping_s_udp_axis_data (ping_s_udp_axis_data ) ,
        .ping_s_udp_axis_valid(ping_s_udp_axis_valid) ,
        .ping_s_udp_axis_last (ping_s_udp_axis_last ) ,
        .ping_s_udp_axis_ready(ping_s_udp_axis_ready) , 
        //len
        .ping_udp_len   (ping_udp_len),  
        .ping_udp_src_ip(ping_udp_src_ip)   ,
        .ping_udp_dst_ip(ping_udp_dst_ip)   ,
        //请求控制IP层
        .ping_m_ip_axis_get   (ping_m_ip_axis_get)   ,
        .ping_m_ip_axis_req   (ping_m_ip_axis_req)   ,
        //控制IP层   
        .ping_m_ip_axis_data  (ping_m_ip_axis_data ) ,    
        .ping_m_ip_axis_valid (ping_m_ip_axis_valid) ,
        .ping_m_ip_axis_last  (ping_m_ip_axis_last ) ,
        .ping_m_ip_axis_ready (ping_m_ip_axis_ready) ,


        //pang
        //本地信息
        .pang_loca_ip         (pang_loca_ip)          ,
        .pang_loca_port       (pang_loca_port)        ,
        //udp的所有配置信息
        .pang_udp_tx_dst_ip   (pang_udp_tx_dst_ip)    ,
        .pang_udp_tx_dst_port (pang_udp_tx_dst_port)  ,
        //用户数据输入
        .pang_s_udp_axis_data (pang_s_udp_axis_data ) ,
        .pang_s_udp_axis_valid(pang_s_udp_axis_valid) ,
        .pang_s_udp_axis_last (pang_s_udp_axis_last ) ,
        .pang_s_udp_axis_ready(pang_s_udp_axis_ready) , 
        //len
        .pang_udp_len   (pang_udp_len), 
        .pang_udp_src_ip(pang_udp_src_ip)   ,
        .pang_udp_dst_ip(pang_udp_dst_ip)   , 
        //请求控制IP层
        .pang_m_ip_axis_get   (pang_m_ip_axis_get)   ,
        .pang_m_ip_axis_req   (pang_m_ip_axis_req)   ,
        //控制IP层   
        .pang_m_ip_axis_data  (pang_m_ip_axis_data ) ,    
        .pang_m_ip_axis_valid (pang_m_ip_axis_valid) ,
        .pang_m_ip_axis_last  (pang_m_ip_axis_last ) ,
        .pang_m_ip_axis_ready (pang_m_ip_axis_ready) 
    );










    udp_tx_buf #(
        .DATA_DEPTH(DATA_DEPTH),                         //支持缓存的最大数据深度 
        .READ_DELAY(READ_DELAY)
    )
    ping_udp_tx_buf(
        .clk(clk)              ,
        .rst(rst)              ,

        //本地信息
        .loca_ip          (ping_loca_ip)          ,
        .loca_port        (ping_loca_port)        ,
        //udp的所有配置信息
        .udp_tx_dst_ip    (ping_udp_tx_dst_ip)    ,
        .udp_tx_dst_port  (ping_udp_tx_dst_port)  ,
        //用户数据输入
        .s_udp_axis_data  (ping_s_udp_axis_data ) ,
        .s_udp_axis_valid (ping_s_udp_axis_valid) ,
        .s_udp_axis_last  (ping_s_udp_axis_last ) ,
        .s_udp_axis_ready (ping_s_udp_axis_ready) , 
        //len
        .udp_len(ping_udp_len),
        //ip
        .udp_src_ip(ping_udp_src_ip)   ,
        .udp_dst_ip(ping_udp_dst_ip)   ,
        //请求控制IP层
        .m_ip_axis_get    (ping_m_ip_axis_get)   ,
        .m_ip_axis_req    (ping_m_ip_axis_req)   ,
        //控制IP层   
        .m_ip_axis_data   (ping_m_ip_axis_data ) ,    
        .m_ip_axis_valid  (ping_m_ip_axis_valid) ,
        .m_ip_axis_last   (ping_m_ip_axis_last ) ,
        .m_ip_axis_ready  (ping_m_ip_axis_ready) 
    );



    udp_tx_buf #(
        .DATA_DEPTH(DATA_DEPTH),                         //支持缓存的最大数据深度 
        .READ_DELAY(READ_DELAY)
    )
    pang_udp_tx_buf(
        .clk(clk)              ,
        .rst(rst)              ,

        //本地信息
        .loca_ip          (pang_loca_ip)          ,
        .loca_port        (pang_loca_port)        ,
        //udp的所有配置信息
        .udp_tx_dst_ip    (pang_udp_tx_dst_ip)    ,
        .udp_tx_dst_port  (pang_udp_tx_dst_port)  ,
        //用户数据输入
        .s_udp_axis_data  (pang_s_udp_axis_data ) ,
        .s_udp_axis_valid (pang_s_udp_axis_valid) ,
        .s_udp_axis_last  (pang_s_udp_axis_last ) ,
        .s_udp_axis_ready (pang_s_udp_axis_ready) , 
        //len
        .udp_len(pang_udp_len),
        //ip
        .udp_src_ip(pang_udp_src_ip)   ,
        .udp_dst_ip(pang_udp_dst_ip)   ,
        //请求控制IP层
        .m_ip_axis_get    (pang_m_ip_axis_get)   ,
        .m_ip_axis_req    (pang_m_ip_axis_req)   ,
        //控制IP层   
        .m_ip_axis_data   (pang_m_ip_axis_data ) ,    
        .m_ip_axis_valid  (pang_m_ip_axis_valid) ,
        .m_ip_axis_last   (pang_m_ip_axis_last ) ,
        .m_ip_axis_ready  (pang_m_ip_axis_ready) 
    );

endmodule