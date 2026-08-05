module mac_tx_ctl(
    input clk,
    input rst,


    //本地信息
    input [47 : 0] loca_mac    ,
    //mac的所有配置信息
    input [47 : 0] mac_tx_dst_mac  ,
    input [15 : 0] mac_tx_type_len ,
    //从ip层进入的申请
    output         s_ip_axis_get   ,
    input          s_ip_axis_req   ,
    //IP报文   
    input  [7 : 0] s_ip_axis_data  ,    
    input          s_ip_axis_valid ,
    output         s_ip_axis_ready ,
    input          s_ip_axis_last  ,


    //mac层输出
    output  [7 : 0] m_gmii_axis_data  ,    
    output          m_gmii_axis_valid ,
    input           m_gmii_axis_ready , 
    output          m_gmii_axis_last  ,






    //ping
    //本地信息
    output  [47 : 0] ping_loca_mac    ,
    //mac的所有配置信息
    output  [47 : 0] ping_mac_tx_dst_mac  ,
    output  [15 : 0] ping_mac_tx_type_len ,
    //从ip层进入的申请
    input           ping_s_ip_axis_get   ,
    output          ping_s_ip_axis_req   ,
    //IP报文   
    output  [7 : 0] ping_s_ip_axis_data  ,    
    output          ping_s_ip_axis_valid ,
    input           ping_s_ip_axis_ready ,
    output          ping_s_ip_axis_last  ,


    //mac层输出
    input  [7 : 0]  ping_m_gmii_axis_data  ,    
    input           ping_m_gmii_axis_valid ,
    output          ping_m_gmii_axis_ready , 
    input           ping_m_gmii_axis_last  ,



    //pang
    //本地信息
    output  [47 : 0] pang_loca_mac    ,
    //mac的所有配置信息
    output  [47 : 0] pang_mac_tx_dst_mac  ,
    output  [15 : 0] pang_mac_tx_type_len ,
    //从ip层进入的申请
    input           pang_s_ip_axis_get   ,
    output          pang_s_ip_axis_req   ,
    //IP报文   
    output  [7 : 0] pang_s_ip_axis_data  ,    
    output          pang_s_ip_axis_valid ,
    input           pang_s_ip_axis_ready ,
    output          pang_s_ip_axis_last  ,


    //mac层输出
    input  [7 : 0]  pang_m_gmii_axis_data  ,    
    input           pang_m_gmii_axis_valid ,
    output          pang_m_gmii_axis_ready , 
    input           pang_m_gmii_axis_last  
    
);


    //乒乓控制器  写
    reg w_ctl;
    always @(posedge clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(s_ip_axis_valid & s_ip_axis_ready & s_ip_axis_last) begin
            w_ctl <= !w_ctl; 
        end
    end



    assign ping_loca_mac        = w_ctl ? 47'd0 : loca_mac;
    assign ping_mac_tx_dst_mac  = w_ctl ? 47'd0 : mac_tx_dst_mac;
    assign ping_mac_tx_type_len = w_ctl ? 16'd0 : mac_tx_type_len;
    
    assign ping_s_ip_axis_req   = w_ctl ? 1'b0 : s_ip_axis_req;
    assign s_ip_axis_get        = w_ctl ? pang_s_ip_axis_get : ping_s_ip_axis_get;
    assign ping_s_ip_axis_data  = s_ip_axis_data;
    assign ping_s_ip_axis_valid = w_ctl ? 1'b0 : s_ip_axis_valid;
    assign ping_s_ip_axis_last  = w_ctl ? 1'b0 : s_ip_axis_last;
    assign s_ip_axis_ready      = w_ctl ? pang_s_ip_axis_ready : ping_s_ip_axis_ready;





    assign pang_loca_mac        = w_ctl ? loca_mac : 47'd0;
    assign pang_mac_tx_dst_mac  = w_ctl ? mac_tx_dst_mac : 47'd0;
    assign pang_mac_tx_type_len = w_ctl ? mac_tx_type_len : 16'd0;
    
    assign pang_s_ip_axis_req   = w_ctl ? s_ip_axis_req : 1'b0;

    assign pang_s_ip_axis_data  = s_ip_axis_data;
    assign pang_s_ip_axis_valid = w_ctl ? s_ip_axis_valid : 1'b0;
    assign pang_s_ip_axis_last  = w_ctl ? s_ip_axis_last : 1'b0;






    //乒乓控制器  读
    reg r_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_gmii_axis_valid & m_gmii_axis_ready & m_gmii_axis_last) begin
            r_ctl <= !r_ctl;
        end
    end

    assign m_gmii_axis_data  = r_ctl ? pang_m_gmii_axis_data : ping_m_gmii_axis_data;
    assign m_gmii_axis_valid = r_ctl ? pang_m_gmii_axis_valid : ping_m_gmii_axis_valid;
    assign ping_m_gmii_axis_ready = r_ctl ? 1'd0 : m_gmii_axis_ready;
    assign pang_m_gmii_axis_ready = r_ctl ? m_gmii_axis_ready : 1'd0;
    assign m_gmii_axis_last  = r_ctl ? pang_m_gmii_axis_last : ping_m_gmii_axis_last;



endmodule