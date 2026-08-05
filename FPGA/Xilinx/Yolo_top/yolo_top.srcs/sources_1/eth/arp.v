`timescale 1ns/1ps
module arp # (
    parameter REPEAT_TIME = 16'hFFFF,           //重发ARP广播的间隔时间
              REPEAT_CNT  = 2,                  //重发ARP广播的次数
              INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16
)(
    input clk,
    input rst,

    //本机配置
    input [31 : 0] loca_ip,
    input [47 : 0] loca_mac,
    //mac查询请求
    input  mac_req_valid,
    output mac_req_ready,
    //查找出的目的地址
    input  [31 : 0]  dst_ip,
    output           dst_mac_valid,
    output [47 : 0]  ip_dst_mac,
    //arp报文中的dst_mac
    output [47 : 0]  arp_dst_mac,




    //tx总线控制
    //请求控制MAC层总线
    input         m_mac_axis_get   ,
    output        m_mac_axis_req   ,
    //控制MAC层总线数据   
    output [ 7:0] m_mac_axis_data  ,    //以字节发送arp报文内容
    output        m_mac_axis_valid ,
    input         m_mac_axis_ready ,
    output        m_mac_axis_last  ,


    //rx总线控制
    input  [ 7:0] s_mac_axis_data  ,
    input         s_mac_axis_valid ,
    input         s_mac_axis_last  ,
    output        s_mac_axis_ready , 
    input         s_mac_axis_error 

);





    wire        arp_tx_valid     ;
    wire        arp_tx_ready     ;
    wire [31:0] arp_tx_src_ip    ;
    wire [31:0] arp_tx_dst_ip    ;
    wire [47:0] arp_tx_src_mac   ;
    wire [47:0] arp_tx_dst_mac   ;
    wire [15:0] arp_tx_op        ;


    wire     arp_resp_valid     ;
    wire     arp_resp_ready     ;


    wire     arq_req         ;
    wire     arq_req_ready   ;


    wire  [31:0] arp_rx_src_ip    ;
    wire  [31:0] arp_rx_dst_ip    ;
    wire  [47:0] arp_rx_src_mac   ;
    wire  [47:0] arp_rx_dst_mac   ;


arp_ctl #(
    .REPEAT_TIME(REPEAT_TIME),           //重发ARP广播的间隔时间
    .REPEAT_CNT(REPEAT_CNT),                  //重发ARP广播的次数
    .INVALID_TIME(INVALID_TIME),
    .CACHE_SIZE(CACHE_SIZE)
)
arp_ctl(
    .clk(clk),
    .rst(rst),

    .mac_req_valid(mac_req_valid),
    .mac_req_ready(mac_req_ready),

    .arp_tx_valid  (arp_tx_valid  )   ,
    .arp_tx_ready  (arp_tx_ready  )   ,
    .arp_tx_dst_mac(arp_tx_dst_mac)   ,
    .arp_tx_dst_ip (arp_tx_dst_ip )   ,
    .arp_tx_op     (arp_tx_op     )   ,

    .arp_resp_valid(arp_resp_valid),
    .arp_resp_ready(arp_resp_ready),
    .arp_rx_src_mac(arp_rx_src_mac),
    .arp_rx_src_ip (arp_rx_src_ip) ,

    //arp应答请求
    .arq_req      (arq_req      ) ,
    .arq_req_ready(arq_req_ready) ,

    //查找出的目的地址
    .dst_ip(dst_ip),
    .dst_mac_valid(dst_mac_valid),
    .dst_mac(ip_dst_mac)

);







arp_tx arp_tx(
    .clk(clk),
    .rst(rst),
    
    .loca_ip (loca_ip )   ,
    .loca_mac(loca_mac)   ,
    //arp的所有配置信息
    .arp_tx_valid  (arp_tx_valid  )   ,
    .arp_tx_ready  (arp_tx_ready  )   ,
    .arp_tx_dst_ip (arp_tx_dst_ip )   ,
    .arp_tx_dst_mac(arp_tx_dst_mac)   ,
    .arp_tx_op     (arp_tx_op     )   ,

    //发给mac层的mac地址
    .arp_dst_mac   (arp_dst_mac),

    //请求控制MAC层总线
    .m_mac_axis_get  (m_mac_axis_get)   ,
    .m_mac_axis_req  (m_mac_axis_req)   ,
    //控制MAC层总线数据   
    .m_mac_axis_data (m_mac_axis_data ) ,    //以字节发送arp报文内容
    .m_mac_axis_valid(m_mac_axis_valid) ,
    .m_mac_axis_ready(m_mac_axis_ready) ,
    .m_mac_axis_last (m_mac_axis_last ) 

);





arp_rx arp_rx(
    .clk(clk),
    .rst(rst),
    .loca_ip(loca_ip)      ,        //本地ip
    .loca_mac(loca_mac)    ,        //本地mac

    // input  [47:0] s_mac_src_mac    ,
    // input  [47:0] s_mac_dst_mac    ,
    // input  [15:0] s_mac_op_len     ,

    .s_mac_axis_data (s_mac_axis_data ) ,
    .s_mac_axis_valid(s_mac_axis_valid) ,
    .s_mac_axis_last (s_mac_axis_last ) ,
    .s_mac_axis_ready(s_mac_axis_ready) , 
    .s_mac_axis_error(s_mac_axis_error) ,


    //arp的响应
    .arp_resp_valid(arp_resp_valid),
    .arp_resp_ready(arp_resp_ready),
    
    .arp_rx_src_ip (arp_rx_src_ip )   ,
    .arp_rx_dst_ip (arp_rx_dst_ip )   ,
    .arp_rx_src_mac(arp_rx_src_mac)   ,
    .arp_rx_dst_mac(arp_rx_dst_mac)   ,

    //arp应答请求
    .arq_req      (arq_req      )   ,
    .arq_req_ready(arq_req_ready) 

);






endmodule