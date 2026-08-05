module mac_tx #(
    parameter DATA_DEPTH = 2048
)(
    input clk,
    input rst,


    //本地信息
    input  [47 : 0] loca_mac    ,
    //mac的所有配置信息
    input  [47 : 0] mac_tx_dst_mac  ,
    input  [15 : 0] mac_tx_type_len ,


    //从ip层进入的申请
    output        s_ip_axis_get   ,
    input         s_ip_axis_req   ,
    //IP报文   
    input [7 : 0] s_ip_axis_data  ,    
    input         s_ip_axis_valid ,
    output        s_ip_axis_ready ,
    input         s_ip_axis_last  ,



    //mac层输出
    output [7 : 0]  m_gmii_axis_data  ,    
    output          m_gmii_axis_valid ,
    input           m_gmii_axis_ready , 
    output          m_gmii_axis_last  
    
);







    //ping
    //本地信息
    wire  [47 : 0] ping_loca_mac    ;
    //mac的所有配置信息
    wire  [47 : 0] ping_mac_tx_dst_mac  ;
    wire  [15 : 0] ping_mac_tx_type_len ;
    //从ip层进入的申请
    wire          ping_s_ip_axis_get   ;
    wire          ping_s_ip_axis_req   ;
    //IP报文   
    wire  [7 : 0] ping_s_ip_axis_data  ;    
    wire          ping_s_ip_axis_valid ;
    wire          ping_s_ip_axis_ready ;
    wire          ping_s_ip_axis_last  ;

    //mac层输出
    wire  [7 : 0] ping_m_gmii_axis_data  ;    
    wire          ping_m_gmii_axis_valid ;
    wire          ping_m_gmii_axis_ready ; 
    wire          ping_m_gmii_axis_last  ;



    //pang
    //本地信息
    wire  [47 : 0] pang_loca_mac    ;
    //mac的所有配置信息
    wire  [47 : 0] pang_mac_tx_dst_mac  ;
    wire  [15 : 0] pang_mac_tx_type_len ;
    //从ip层进入的申请
    wire          pang_s_ip_axis_get   ;
    wire          pang_s_ip_axis_req   ;
    //IP报文   
    wire  [7 : 0] pang_s_ip_axis_data  ;    
    wire          pang_s_ip_axis_valid ;
    wire          pang_s_ip_axis_ready ;
    wire          pang_s_ip_axis_last  ;

    //mac层输出
    wire  [7 : 0] pang_m_gmii_axis_data  ;    
    wire          pang_m_gmii_axis_valid ;
    wire          pang_m_gmii_axis_ready ; 
    wire          pang_m_gmii_axis_last  ;






mac_tx_ctl mac_tx_ctl(
    .clk(clk),
    .rst(rst),


    //本地信息
    .loca_mac(loca_mac)    ,
    //mac的所有配置信息
    .mac_tx_dst_mac (mac_tx_dst_mac  ) ,
    .mac_tx_type_len(mac_tx_type_len ) ,
    //从ip层进入的申请
    .s_ip_axis_get(s_ip_axis_get)   ,
    .s_ip_axis_req(s_ip_axis_req)   ,
    //IP报文   
    .s_ip_axis_data (s_ip_axis_data ) ,    
    .s_ip_axis_valid(s_ip_axis_valid) ,
    .s_ip_axis_ready(s_ip_axis_ready) ,
    .s_ip_axis_last (s_ip_axis_last ) ,


    //mac层输出
    .m_gmii_axis_data  (m_gmii_axis_data ),    
    .m_gmii_axis_valid (m_gmii_axis_valid),
    .m_gmii_axis_ready (m_gmii_axis_ready), 
    .m_gmii_axis_last  (m_gmii_axis_last ),






    //ping
    //本地信息
    .ping_loca_mac(ping_loca_mac)    ,
    //mac的所有配置信息
    .ping_mac_tx_dst_mac (ping_mac_tx_dst_mac  ),
    .ping_mac_tx_type_len(ping_mac_tx_type_len ),
    //从ip层进入的申请
    .ping_s_ip_axis_get  (ping_s_ip_axis_get   )  ,
    .ping_s_ip_axis_req  (ping_s_ip_axis_req   )  ,
    //IP报文   
    .ping_s_ip_axis_data (ping_s_ip_axis_data ) ,    
    .ping_s_ip_axis_valid(ping_s_ip_axis_valid) ,
    .ping_s_ip_axis_ready(ping_s_ip_axis_ready) ,
    .ping_s_ip_axis_last (ping_s_ip_axis_last ) ,


    //mac层输出
    .ping_m_gmii_axis_data (ping_m_gmii_axis_data ) ,    
    .ping_m_gmii_axis_valid(ping_m_gmii_axis_valid) ,
    .ping_m_gmii_axis_ready(ping_m_gmii_axis_ready) , 
    .ping_m_gmii_axis_last (ping_m_gmii_axis_last ) ,



    //pang
    //本地信息
    .pang_loca_mac(pang_loca_mac)    ,
    //mac的所有配置信息
    .pang_mac_tx_dst_mac (pang_mac_tx_dst_mac  ),
    .pang_mac_tx_type_len(pang_mac_tx_type_len ),
    //从ip层进入的申请
    .pang_s_ip_axis_get  (pang_s_ip_axis_get   )  ,
    .pang_s_ip_axis_req  (pang_s_ip_axis_req   )  ,
    //IP报文   
    .pang_s_ip_axis_data (pang_s_ip_axis_data ) ,    
    .pang_s_ip_axis_valid(pang_s_ip_axis_valid) ,
    .pang_s_ip_axis_ready(pang_s_ip_axis_ready) ,
    .pang_s_ip_axis_last (pang_s_ip_axis_last ) ,


    //mac层输出
    .pang_m_gmii_axis_data (pang_m_gmii_axis_data ) ,    
    .pang_m_gmii_axis_valid(pang_m_gmii_axis_valid) ,
    .pang_m_gmii_axis_ready(pang_m_gmii_axis_ready) , 
    .pang_m_gmii_axis_last (pang_m_gmii_axis_last ) 
    
);







mac_tx_buf #(
    .DATA_DEPTH(DATA_DEPTH)
)
ping_mac_tx_buf(
    .clk(clk),
    .rst(rst),

    //本地信息
    .loca_mac(ping_loca_mac)    ,
    //mac的所有配置信息
    .mac_tx_dst_mac  (ping_mac_tx_dst_mac  ),
    .mac_tx_type_len (ping_mac_tx_type_len ),


    //从ip层进入的申请
    .s_ip_axis_get   (ping_s_ip_axis_get)   ,
    .s_ip_axis_req   (ping_s_ip_axis_req)   ,
    //IP报文   
    .s_ip_axis_data  (ping_s_ip_axis_data  ),    
    .s_ip_axis_valid (ping_s_ip_axis_valid ),
    .s_ip_axis_ready (ping_s_ip_axis_ready ),
    .s_ip_axis_last  (ping_s_ip_axis_last  ),



    //mac层输出
    .m_gmii_axis_data (ping_m_gmii_axis_data ) ,    
    .m_gmii_axis_valid(ping_m_gmii_axis_valid) ,
    .m_gmii_axis_ready(ping_m_gmii_axis_ready) , 
    .m_gmii_axis_last (ping_m_gmii_axis_last ) 
    
);








mac_tx_buf #(
    .DATA_DEPTH(DATA_DEPTH)
)
pang_mac_tx_buf(
    .clk(clk),
    .rst(rst),

    //本地信息
    .loca_mac(pang_loca_mac)    ,
    //mac的所有配置信息
    .mac_tx_dst_mac  (pang_mac_tx_dst_mac  ),
    .mac_tx_type_len (pang_mac_tx_type_len ),


    //从ip层进入的申请
    .s_ip_axis_get   (pang_s_ip_axis_get)   ,
    .s_ip_axis_req   (pang_s_ip_axis_req)   ,
    //IP报文   
    .s_ip_axis_data  (pang_s_ip_axis_data  ),    
    .s_ip_axis_valid (pang_s_ip_axis_valid ),
    .s_ip_axis_ready (pang_s_ip_axis_ready ),
    .s_ip_axis_last  (pang_s_ip_axis_last  ),



    //mac层输出
    .m_gmii_axis_data (pang_m_gmii_axis_data ) ,    
    .m_gmii_axis_valid(pang_m_gmii_axis_valid) ,
    .m_gmii_axis_ready(pang_m_gmii_axis_ready) , 
    .m_gmii_axis_last (pang_m_gmii_axis_last ) 
    
);



endmodule