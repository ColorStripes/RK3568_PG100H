module eth_tx(
    input clk,
    input rst,

    //ARP的mac层控制权限数据和请求
    input         arp_tx_req,
    output        arp_tx_get,
    input [7 : 0] arp_tx_data,
    input         arp_tx_valid,
    input         arp_tx_last,
    output        arp_tx_ready,


    //IP的mac层控制权限数据和请求
    input         ip_tx_req,
    output        ip_tx_get,
    input [7 : 0] ip_tx_data,
    input         ip_tx_valid,
    input         ip_tx_last,
    output        ip_tx_ready,


    //上层选择发送给MAC层的数据和请求
    output         mac_tx_req,
    input          mac_tx_get,
    output [7 : 0] mac_tx_data,
    output         mac_tx_valid,
    output         mac_tx_last,
    input          mac_tx_ready,
    //mac配置数据
    output  [47 : 0] mac_tx_dst_mac  ,
    output  [15 : 0] mac_tx_type_len ,


    // //mac层启动信号
    // output           m_gmii_axis_get   ,
    // input            m_gmii_axis_req   ,

    //mac查询请求
    output reg mac_req_valid,
    input      mac_req_ready,
    //来自arp给IP的mac
    input             ip_dst_mac_valid,
    input [47 : 0]    ip_dst_mac,
    input [47 : 0]    arp_dst_mac,

    //监控总线的各项数据信号（用于状态机的改变）
    input  [7 : 0]   gmii_axis_data  ,    
    input            gmii_axis_valid ,
    input            gmii_axis_last  

);




    localparam REQ = 4'b0001, ARP = 4'b0010, IP_MAC = 4'b0100, IP = 4'b1000;
    reg [3 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= REQ;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            REQ:begin
                if(arp_tx_req) begin
                    next_state = ARP;
                end
                else if(ip_tx_req) begin
                    next_state = IP_MAC;
                end
                else begin
                    next_state = REQ;
                end
            end 
            ARP:begin
                if(gmii_axis_valid & gmii_axis_last) begin
                    next_state = REQ;
                end
                else begin
                    next_state = ARP;
                end
            end
            IP_MAC:begin
                if(ip_dst_mac_valid) begin
                    next_state = IP;
                end
                else begin
                    next_state = IP_MAC;
                end
            end
            IP:begin
                if(gmii_axis_valid & gmii_axis_last) begin
                    next_state = REQ;
                end
                else begin
                    next_state = IP;
                end
            end        
            default:begin
                next_state = REQ;
            end
        endcase
    end



    reg ip_process;
    always @(posedge clk) begin
        if(rst) begin
            ip_process <= 1'b0;
        end
        else if((state == IP_MAC) && (next_state == IP)) begin
            ip_process <= 1'b1;
        end
        else if(next_state != IP) begin
            ip_process <= 1'b0;
        end
    end




    //上层选择发送给MAC层的数据和请求
    assign mac_tx_req = ip_process ? ip_tx_req : arp_tx_req;
    assign ip_tx_get  = ip_process ? mac_tx_get : 1'b0;
    assign arp_tx_get = ip_process ? 1'b0 : mac_tx_get;

    assign mac_tx_data  = ip_process ? ip_tx_data : arp_tx_data;
    assign mac_tx_valid = ip_process ? ip_tx_valid : arp_tx_valid;
    assign mac_tx_last  = ip_process ? ip_tx_last : arp_tx_last;
    assign ip_tx_ready  = ip_process ? mac_tx_ready : 1'b0;
    assign arp_tx_ready = ip_process ? 1'b0 : mac_tx_ready;

    //mac配置数据
    assign mac_tx_dst_mac  = ip_process ? ip_dst_mac : 
                             (arp_dst_mac == 48'h0000_0000_0000) ? ~arp_dst_mac : arp_dst_mac;
    assign mac_tx_type_len = ip_process ? 16'h0800 : 16'h0806;


    always @(posedge clk) begin
        if(rst) begin
            mac_req_valid <= 1'b0;
        end
        else if(mac_req_valid & mac_req_ready) begin
            mac_req_valid <= 1'b0;
        end
        else if((next_state == IP_MAC) && (state == REQ)) begin
            mac_req_valid <= 1'b1;
        end
    end


endmodule