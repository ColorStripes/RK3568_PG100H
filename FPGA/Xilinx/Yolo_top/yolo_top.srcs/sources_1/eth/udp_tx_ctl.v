module udp_tx_ctrl(
    input         clk              ,
    input         rst              ,

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

    //告诉IP自己的长度
    output [15 : 0]  udp_len      ,
    //告诉ip层数据要发往哪个ip 和当前ip
    output [31 : 0]  udp_src_ip   ,
    output [31 : 0]  udp_dst_ip   ,
    //请求控制IP层
    input          m_ip_axis_get   ,
    output         m_ip_axis_req   ,
    //控制IP层   
    output [7 : 0] m_ip_axis_data  ,   
    output         m_ip_axis_valid ,
    output         m_ip_axis_last  ,
    input          m_ip_axis_ready ,



    //ping
    //本地信息
    output  [31 : 0]  ping_loca_ip      ,
    output  [15 : 0]  ping_loca_port    ,
    //udp的所有配置信息
    output  [31 : 0]  ping_udp_tx_dst_ip    ,
    output  [15 : 0]  ping_udp_tx_dst_port  ,
    //用户数据输入
    output  [7 : 0]   ping_s_udp_axis_data  ,
    output            ping_s_udp_axis_valid ,
    output            ping_s_udp_axis_last  ,
    input             ping_s_udp_axis_ready , 
    //len
    input  [15 : 0]   ping_udp_len,  
    //告诉ip层数据要发往哪个ip 和当前ip
    input [31 : 0]    ping_udp_src_ip   ,
    input [31 : 0]    ping_udp_dst_ip   ,      
    //请求控制IP层
    output            ping_m_ip_axis_get   ,
    input             ping_m_ip_axis_req   ,
    //控制IP层   
    input [ 7:0]      ping_m_ip_axis_data  ,    
    input             ping_m_ip_axis_valid ,
    input             ping_m_ip_axis_last  ,
    output            ping_m_ip_axis_ready ,


    //pang
    //本地信息
    output  [31 : 0]  pang_loca_ip      ,
    output  [15 : 0]  pang_loca_port    ,
    //udp的所有配置信息
    output  [31 : 0]  pang_udp_tx_dst_ip    ,
    output  [15 : 0]  pang_udp_tx_dst_port  ,
    //用户数据输入
    output  [7 : 0]   pang_s_udp_axis_data  ,
    output            pang_s_udp_axis_valid ,
    output            pang_s_udp_axis_last  ,
    input             pang_s_udp_axis_ready , 
    //len
    input  [15 : 0]   pang_udp_len,  
    //告诉ip层数据要发往哪个ip 和当前ip
    input [31 : 0]    pang_udp_src_ip   ,
    input [31 : 0]    pang_udp_dst_ip   , 
    //请求控制IP层
    output            pang_m_ip_axis_get   ,
    input             pang_m_ip_axis_req   ,
    //控制IP层   
    input [7 : 0]     pang_m_ip_axis_data  ,   
    input             pang_m_ip_axis_valid ,
    input             pang_m_ip_axis_last  ,
    output            pang_m_ip_axis_ready 

 
);


    //乒乓控制器  写
    reg w_ctl;
    always @(posedge clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(s_udp_axis_valid & s_udp_axis_ready & s_udp_axis_last) begin
            w_ctl <= !w_ctl; 
        end
    end

    assign ping_loca_ip   = w_ctl ? 16'd0 : loca_ip;
    assign ping_loca_port = w_ctl ? 16'd0 : loca_port;
    assign ping_udp_tx_dst_ip   = w_ctl ? 16'd0 : udp_tx_dst_ip    ;
    assign ping_udp_tx_dst_port = w_ctl ? 16'd0 : udp_tx_dst_port  ;
    assign ping_s_udp_axis_data = w_ctl ? 8'd0  : s_udp_axis_data  ;
    assign ping_s_udp_axis_valid= w_ctl ? 1'b0  : s_udp_axis_valid ;
    assign ping_s_udp_axis_last = w_ctl ? 1'b0  : s_udp_axis_last  ;

    assign pang_loca_ip   = w_ctl ? loca_ip : 16'd0;
    assign pang_loca_port = w_ctl ? loca_port : 16'd0;
    assign pang_udp_tx_dst_ip   = w_ctl ? udp_tx_dst_ip : 16'd0    ;
    assign pang_udp_tx_dst_port = w_ctl ? udp_tx_dst_port : 16'd0;
    assign pang_s_udp_axis_data = w_ctl ? s_udp_axis_data : 8'd0;
    assign pang_s_udp_axis_valid= w_ctl ? s_udp_axis_valid : 1'b0;
    assign pang_s_udp_axis_last = w_ctl ? s_udp_axis_last : 1'b0;
    assign s_udp_axis_ready = w_ctl ? pang_s_udp_axis_ready : ping_s_udp_axis_ready;




    //乒乓控制器  读
    reg r_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_ip_axis_valid & m_ip_axis_ready & m_ip_axis_last) begin
            r_ctl <= !r_ctl;
        end
    end

    assign udp_len    = r_ctl ? pang_udp_len : ping_udp_len;
    assign udp_src_ip = r_ctl ? pang_udp_src_ip : ping_udp_src_ip;
    assign udp_dst_ip = r_ctl ? pang_udp_dst_ip : ping_udp_dst_ip;

    assign ping_m_ip_axis_get = r_ctl ? 1'b0 : m_ip_axis_get;
    assign m_ip_axis_req = r_ctl ?   pang_m_ip_axis_req : ping_m_ip_axis_req;
    assign m_ip_axis_data = r_ctl ?  pang_m_ip_axis_data : ping_m_ip_axis_data;
    assign m_ip_axis_valid = r_ctl ? pang_m_ip_axis_valid : ping_m_ip_axis_valid;
    assign m_ip_axis_last = r_ctl ?  pang_m_ip_axis_last : ping_m_ip_axis_last;
    assign ping_m_ip_axis_ready = r_ctl ? 1'b0 : m_ip_axis_ready;



    assign pang_m_ip_axis_get = r_ctl ? m_ip_axis_get : 1'b0;
    assign pang_m_ip_axis_ready = r_ctl ? m_ip_axis_ready : 1'b0;


endmodule