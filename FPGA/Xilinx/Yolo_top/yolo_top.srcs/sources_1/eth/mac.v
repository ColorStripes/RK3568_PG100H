module mac #(
    parameter TX_DATA_DEPTH = 2048,
              RX_DATA_DEPTH = 2048
)(
    input clk,
    input rst,


    //本地信息
    input  [47 : 0] loca_mac    ,
    //mac的所有配置信息
    input  [47 : 0] mac_tx_dst_mac  ,
    input  [15 : 0] mac_tx_type_len ,

    //输出校验信息
    output fcs_error,
    output fcs_no_error,




    //从ip层进入的申请  tx
    output        s_ip_axis_get   ,
    input         s_ip_axis_req   ,
    //IP报文   
    input [ 7:0]  s_ip_axis_data  ,    
    input         s_ip_axis_valid ,
    output        s_ip_axis_ready ,
    input         s_ip_axis_last  ,



    //根据这个分发给ip还是arp
    output   [15 : 0] mac_rx_type_len,
    //进入ip层解析  rx
    output   [7 : 0]  m_ip_axis_data  ,
    output            m_ip_axis_valid , 
    output            m_ip_axis_last  ,
    input             m_ip_axis_ready ,
    output            m_ip_axis_error ,





    //进入mac层解析 rx
    input  [7 : 0]  s_gmii_axis_data   ,
    input           s_gmii_axis_valid  ,
    input           s_gmii_axis_last   ,
    output          s_gmii_axis_ready  ,   
    input           s_gmii_axis_error  ,

    // //请求控制gmii总线  tx
    // input           m_gmii_axis_get   ,
    // output          m_gmii_axis_req   ,
    //mac层输出
    output  [7 : 0] m_gmii_axis_data  ,    
    output          m_gmii_axis_valid ,
    output          m_gmii_axis_last  ,
    input           m_gmii_axis_ready  
    
);


    mac_tx #(
        .DATA_DEPTH(TX_DATA_DEPTH)
    ) 
    mac_tx(
        .clk(clk),
        .rst(rst),


        //本地信息
        .loca_mac(loca_mac) ,
        //mac的所有配置信息
        .mac_tx_dst_mac (mac_tx_dst_mac ) ,
        .mac_tx_type_len(mac_tx_type_len) ,


        //从ip层进入的申请
        .s_ip_axis_get(s_ip_axis_get)   ,
        .s_ip_axis_req(s_ip_axis_req)   ,
        //IP报文   
        .s_ip_axis_data (s_ip_axis_data ) ,    
        .s_ip_axis_valid(s_ip_axis_valid) ,
        .s_ip_axis_ready(s_ip_axis_ready) ,
        .s_ip_axis_last (s_ip_axis_last ) ,




        // //请求控制gmii总线
        // .m_gmii_axis_get(m_gmii_axis_get)   ,
        // .m_gmii_axis_req(m_gmii_axis_req)   ,
        //mac层输出
        .m_gmii_axis_data (m_gmii_axis_data ) ,    
        .m_gmii_axis_valid(m_gmii_axis_valid) ,
        .m_gmii_axis_last (m_gmii_axis_last ) ,
        .m_gmii_axis_ready(m_gmii_axis_ready)

    );



    mac_rx #(
        .DATA_DEPTH(RX_DATA_DEPTH),
        .READ_DELAY(1)
    )          
    mac_rx(
        .clk(clk),
        .rst(rst),


        //本地信息
        .loca_mac(loca_mac),
        //输出校验信息
        .fcs_error   (fcs_error),
        .fcs_no_error(fcs_no_error),


        //进入mac层解析
        .s_gmii_axis_data (s_gmii_axis_data )  ,
        .s_gmii_axis_valid(s_gmii_axis_valid)  ,
        .s_gmii_axis_last (s_gmii_axis_last )  ,
        .s_gmii_axis_ready(s_gmii_axis_ready)  ,   //这里这个ready不能反压上级    接受是实时的 没办法反压不接受
        .s_gmii_axis_error(s_gmii_axis_error)  ,

        //根据这个分发给ip还是arp
        .mac_type_len(mac_rx_type_len),
        //进入ip层解析
        .m_ip_axis_data (m_ip_axis_data ) ,
        .m_ip_axis_valid(m_ip_axis_valid) , 
        .m_ip_axis_last (m_ip_axis_last ) ,
        .m_ip_axis_ready(m_ip_axis_ready) ,
        .m_ip_axis_error(m_ip_axis_error) 
    );


endmodule