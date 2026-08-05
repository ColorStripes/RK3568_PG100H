module eth_axi # (
    parameter REPEAT_TIME = 16'hFFFF,           //重发ARP广播的间隔时间
              REPEAT_CNT  = 2,                  //重发ARP广播的次数
              INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16,
              TX_DATA_DEPTH = 2048,                         //支持缓存的最大数据深度 
              RX_DATA_DEPTH = 2048,
              READ_DELAY = 1
)(
    input clk,
    input rst,

    //本地信息
    input  [47 : 0] loca_mac    ,
    input  [31 : 0] loca_ip     ,
    input  [15 : 0] loca_port   ,
    //目的信息
    input  [31 : 0] dst_ip      ,
    input  [15 : 0] dst_port    ,



    //用户数据
    //tx用户数据输
    input  [7 : 0]   s_axis_data  ,
    input            s_axis_valid ,
    input            s_axis_last  ,
    output           s_axis_ready , 
    //rx
    //用户数据发出
    output  [7 : 0]  m_axis_data  ,
    output           m_axis_valid ,
    output           m_axis_last  ,
    input            m_axis_ready ,


    //gmii
    //进入mac层解析 rx
    input  [7 : 0]  s_gmii_axis_data  ,
    input           s_gmii_axis_valid ,
    input           s_gmii_axis_last  ,
    output          s_gmii_axis_ready ,   
    input           s_gmii_axis_error ,         //phy的er信号    
    //mac层输出  tx
    output  [7 : 0] m_gmii_axis_data  ,    
    output          m_gmii_axis_valid ,
    output          m_gmii_axis_last  ,
    input           m_gmii_axis_ready 

);

    wire [47 : 0] mac_tx_dst_mac;
    wire [15 : 0] mac_tx_type_len;

    wire mac_tx_req  ; 
    wire mac_tx_get  ;
    wire [7 : 0] mac_tx_data ;
    wire         mac_tx_valid;
    wire         mac_tx_ready;
    wire         mac_tx_last ;

    wire [15 : 0] mac_rx_type_len;
    wire [7 : 0]  mac_rx_data ;
    wire          mac_rx_valid;
    wire          mac_rx_last ;
    wire          mac_rx_ready;
    wire          mac_rx_error;

    //udp error
    wire fcs_error   ;
    wire fcs_no_error;


    mac #(
        .TX_DATA_DEPTH(TX_DATA_DEPTH + 50),
        .RX_DATA_DEPTH(RX_DATA_DEPTH + 50)
    )
    mac(
        .clk(clk),
        .rst(rst),


        //本地信息
        .loca_mac(loca_mac)    ,
        //mac的所有配置信息
        .mac_tx_dst_mac (mac_tx_dst_mac ) ,
        .mac_tx_type_len(mac_tx_type_len) ,

        //输出校验信息
        .fcs_error   (fcs_error   ),
        .fcs_no_error(fcs_no_error),



        //从eth_tx层进入的申请  tx
        .s_ip_axis_get  (mac_tx_get)   ,
        .s_ip_axis_req  (mac_tx_req)   ,
        //上层报文   
        .s_ip_axis_data (mac_tx_data ) ,    
        .s_ip_axis_valid(mac_tx_valid) ,
        .s_ip_axis_ready(mac_tx_ready) ,
        .s_ip_axis_last (mac_tx_last ) ,


        //根据这个分发给ip还是arp    rx
        .mac_rx_type_len(mac_rx_type_len),
        //进入ip层解析  rx
        .m_ip_axis_data (mac_rx_data ) ,
        .m_ip_axis_valid(mac_rx_valid) , 
        .m_ip_axis_last (mac_rx_last ) ,
        .m_ip_axis_ready(mac_rx_ready) ,
        .m_ip_axis_error(mac_rx_error),




        //AXI
        //进入mac层解析 rx
        .s_gmii_axis_data (s_gmii_axis_data )  ,
        .s_gmii_axis_valid(s_gmii_axis_valid)  ,
        .s_gmii_axis_last (s_gmii_axis_last )  ,
        .s_gmii_axis_ready(s_gmii_axis_ready)  ,
        .s_gmii_axis_error(s_gmii_axis_error)  ,

        //mac层输出
        .m_gmii_axis_data (m_gmii_axis_data ) ,    
        .m_gmii_axis_valid(m_gmii_axis_valid) ,
        .m_gmii_axis_last (m_gmii_axis_last ) ,
        .m_gmii_axis_ready(m_gmii_axis_ready)

    );



    wire mac_req_valid;
    wire mac_req_ready;
    wire          ip_dst_mac_valid;
    wire [47 : 0] ip_dst_mac  ;    
    wire [47 : 0] arp_dst_mac ;    


    //arp
    wire         arp_tx_req  ;
    wire         arp_tx_get  ;
    wire [7 : 0] arp_tx_data ;
    wire         arp_tx_valid;
    wire         arp_tx_last ;
    wire         arp_tx_ready;
    //ip
    wire         ip_tx_req  ;
    wire         ip_tx_get  ;
    wire [7 : 0] ip_tx_data ;
    wire         ip_tx_valid;
    wire         ip_tx_last ;
    wire         ip_tx_ready;

    eth_tx eth_tx(
        .clk(clk),
        .rst(rst),

        //ARP的mac层控制权限数据和请求
        .arp_tx_req  (arp_tx_req  ),
        .arp_tx_get  (arp_tx_get  ),
        .arp_tx_data (arp_tx_data ),
        .arp_tx_valid(arp_tx_valid),
        .arp_tx_last (arp_tx_last ),
        .arp_tx_ready(arp_tx_ready),


        //IP的mac层控制权限数据和请求
        .ip_tx_req  (ip_tx_req  ),
        .ip_tx_get  (ip_tx_get  ),
        .ip_tx_data (ip_tx_data ),
        .ip_tx_valid(ip_tx_valid),
        .ip_tx_last (ip_tx_last ),
        .ip_tx_ready(ip_tx_ready),


        //上层选择发送给MAC层的数据和请求
        .mac_tx_req  (mac_tx_req  )  ,
        .mac_tx_get  (mac_tx_get  )  ,
        .mac_tx_data (mac_tx_data )  ,
        .mac_tx_valid(mac_tx_valid)  ,
        .mac_tx_last (mac_tx_last )  ,
        .mac_tx_ready(mac_tx_ready)  ,
        //mac配置数据
        .mac_tx_dst_mac (mac_tx_dst_mac ) ,
        .mac_tx_type_len(mac_tx_type_len) ,




        //mac查询请求
        .mac_req_valid(mac_req_valid),
        .mac_req_ready(mac_req_ready),
        //来自arp查询IP的mac
        .ip_dst_mac_valid(ip_dst_mac_valid),
        .ip_dst_mac      (ip_dst_mac      ),
        .arp_dst_mac     (arp_dst_mac     ),

        //监控总线的各项数据信号（用于状态机的改变）
        .gmii_axis_data (m_gmii_axis_data ) ,    
        .gmii_axis_valid(m_gmii_axis_valid) ,
        .gmii_axis_last (m_gmii_axis_last ) 

    );


    wire [7 : 0] arp_rx_data ;
    wire         arp_rx_valid;
    wire         arp_rx_last ;
    wire         arp_rx_ready;
    wire         arp_rx_error;      

    //ip
    wire [7 : 0] ip_rx_data ;
    wire         ip_rx_valid;
    wire         ip_rx_last ;
    wire         ip_rx_ready;
    wire         ip_rx_error;  

    wire arp_fcs_error;
    wire arp_fcs_no_error;

    wire ip_fcs_error;
    wire ip_fcs_no_error;

    eth_rx eth_rx(
        .clk(clk),
        .rst(rst),

        //发送给arp数据
        .arp_fcs_error   (arp_fcs_error   ),
        .arp_fcs_no_error(arp_fcs_no_error),
        .arp_rx_data (arp_rx_data ),
        .arp_rx_valid(arp_rx_valid),
        .arp_rx_last (arp_rx_last ),
        .arp_rx_ready(arp_rx_ready),
        .arp_rx_error(arp_rx_error),


        //发送给ip数据
        .ip_fcs_error   (ip_fcs_error   ),
        .ip_fcs_no_error(ip_fcs_no_error),
        .ip_rx_data (ip_rx_data ), 
        .ip_rx_valid(ip_rx_valid),
        .ip_rx_last (ip_rx_last ),
        .ip_rx_ready(ip_rx_ready),
        .ip_rx_error(ip_rx_error),


        //mac层收到的数据
        .mac_rx_type_len(mac_rx_type_len),

        .mac_fcs_error   (fcs_error   ),
        .mac_fcs_no_error(fcs_no_error),
        .mac_rx_data (mac_rx_data ) ,
        .mac_rx_valid(mac_rx_valid) ,
        .mac_rx_last (mac_rx_last ) ,
        .mac_rx_ready(mac_rx_ready) ,
        .mac_rx_error(mac_rx_error) 

    );



    arp # (
       .REPEAT_TIME  (REPEAT_TIME ),      //重发ARP广播的间隔时间
       .REPEAT_CNT   (REPEAT_CNT  ),      //重发ARP广播的次数
       .INVALID_TIME (INVALID_TIME),
       .CACHE_SIZE   (CACHE_SIZE  )
    )
    arp(
        .clk(clk),
        .rst(rst),

        //本机配置
        .loca_ip (loca_ip ),
        .loca_mac(loca_mac),
        //mac查询请求
        .mac_req_valid(mac_req_valid),
        .mac_req_ready(mac_req_ready),
        //查找出的目的地址
        .dst_ip       (udp_dst_ip),
        .dst_mac_valid(ip_dst_mac_valid),
        .ip_dst_mac   (ip_dst_mac      ),
        //arp报文中的dst_mac
        .arp_dst_mac  (arp_dst_mac     ), 




        //tx总线控制
        //请求控制MAC层总线
        .m_mac_axis_get  (arp_tx_get  )   ,
        .m_mac_axis_req  (arp_tx_req  )   ,
        //控制MAC层总线数据   
        .m_mac_axis_data (arp_tx_data ) ,    //以字节发送arp报文内容
        .m_mac_axis_valid(arp_tx_valid) ,
        .m_mac_axis_ready(arp_tx_ready) ,
        .m_mac_axis_last (arp_tx_last ) ,


        //rx总线控制
        .s_mac_axis_data (arp_rx_data ) ,
        .s_mac_axis_valid(arp_rx_valid) ,
        .s_mac_axis_last (arp_rx_last ) ,
        .s_mac_axis_ready(arp_rx_ready) , 
        .s_mac_axis_error(arp_fcs_error | arp_rx_error)      //crc校验错误清空状态 或者 pyh芯片错误帧

    );
   

    //udp->ip
    wire [15 : 0]  udp_len;
    //告诉ip层数据要发往哪个ip 和当前ip
    wire [31 : 0]  udp_src_ip   ;
    wire [31 : 0]  udp_dst_ip   ;

    //udp->ip
    wire           udp_tx_get; 
    wire           udp_tx_req;
    wire  [7 : 0]  udp_tx_data ;
    wire           udp_tx_valid;
    wire           udp_tx_last ;
    wire           udp_tx_ready;

    //ip->udp
    wire  [7 : 0]  udp_rx_data ;
    wire           udp_rx_valid;
    wire           udp_rx_last ;
    wire           udp_rx_ready;
    wire           udp_rx_error;

    ip ip(
        .clk(clk),
        .rst(rst),

        //本地信息
        .loca_ip(loca_ip),
        //tx发送所需信息
        .ip_tx_total_len(udp_len),          //内部加上ip头字节
        .ip_tx_id      (16'd0)   ,
        .ip_tx_offset  (16'h4000)   ,   //df=1
        .ip_tx_ttl     (8'd64)   ,
        .ip_tx_protocol(8'd17)   ,
        .ip_tx_dst_ip  (udp_dst_ip)  ,


        //UDP向IP层发送的数据 tx
        .s_udp_axis_get(udp_tx_get)   ,
        .s_udp_axis_req(udp_tx_req)   ,
        //UDP报文
        .s_udp_axis_data (udp_tx_data ) ,
        .s_udp_axis_valid(udp_tx_valid) ,
        .s_udp_axis_last (udp_tx_last ) ,
        .s_udp_axis_ready(udp_tx_ready) , 

        //从ip进入udp解析 rx
        .m_udp_axis_data (udp_rx_data ) ,
        .m_udp_axis_valid(udp_rx_valid) , 
        .m_udp_axis_last (udp_rx_last ) ,
        .m_udp_axis_ready(udp_rx_ready) ,
        .m_udp_axis_error(udp_rx_error) ,





        //从mac进入ip层解析 rx
        .s_mac_axis_data (ip_rx_data )  ,
        .s_mac_axis_valid(ip_rx_valid)  ,
        .s_mac_axis_last (ip_rx_last )  ,
        .s_mac_axis_ready(ip_rx_ready)  ,   //这里这个ready不能反压上级    接受是实时的 没办法反压不接受
        .s_mac_axis_error(ip_rx_error)  ,



        //请求控制MAC层总线 tx
        .m_mac_axis_get(ip_tx_get)   ,
        .m_mac_axis_req(ip_tx_req)   ,
        //控制MAC层总线数据   
        .m_mac_axis_data (ip_tx_data ) ,    
        .m_mac_axis_valid(ip_tx_valid) ,
        .m_mac_axis_ready(ip_tx_ready) ,
        .m_mac_axis_last (ip_tx_last ) 

    );




    udp #(
        .TX_DATA_DEPTH (TX_DATA_DEPTH),                         //支持缓存的最大数据深度 
        .RX_DATA_DEPTH (RX_DATA_DEPTH),
        .READ_DELAY    (READ_DELAY   )
    )
    udp(
        .clk(clk),
        .rst(rst),

        //本地信息
        .loca_ip  (loca_ip)      ,
        .loca_port(loca_port)    ,
        //udp的所有配置信息
        .udp_tx_dst_ip  (dst_ip)    ,
        .udp_tx_dst_port(dst_port)  ,
        //tx用户数据输
        .s_udp_axis_data (s_axis_data ) ,
        .s_udp_axis_valid(s_axis_valid) ,
        .s_udp_axis_last (s_axis_last ) ,
        .s_udp_axis_ready(s_axis_ready) , 

        //rx
        //用户数据发出
        .m_udp_axis_data (m_axis_data ) ,
        .m_udp_axis_valid(m_axis_valid) , 
        .m_udp_axis_last (m_axis_last ) ,
        .m_udp_axis_ready(m_axis_ready) ,



        //rx
        .crc_error   (ip_fcs_error   ),
        .crc_no_error(ip_fcs_no_error),
        //从ip层进入解析
        .s_ip_axis_data (udp_rx_data )  ,
        .s_ip_axis_valid(udp_rx_valid)  ,
        .s_ip_axis_last (udp_rx_last )  ,
        .s_ip_axis_ready(udp_rx_ready)  ,   //这里这个ready不能反压上级  只能看是不是full   接受是实时的 没办法反压不接受
        .s_ip_axis_error(udp_rx_error)  ,

        //tx
        //udp报文长度
        .udp_len(udp_len)       ,
        //告诉ip层数据要发往哪个ip 和当前ip
        .udp_src_ip(udp_src_ip)   ,                         //这边预留出来本地ip可以变化的接口 但未使用
        .udp_dst_ip(udp_dst_ip)   ,
        //请求控制IP层
        .m_ip_axis_get(udp_tx_get)   ,
        .m_ip_axis_req(udp_tx_req)   ,
        //控制IP层   
        .m_ip_axis_data (udp_tx_data ) ,    
        .m_ip_axis_valid(udp_tx_valid) ,
        .m_ip_axis_ready(udp_tx_ready) ,
        .m_ip_axis_last (udp_tx_last ) 
    );

endmodule