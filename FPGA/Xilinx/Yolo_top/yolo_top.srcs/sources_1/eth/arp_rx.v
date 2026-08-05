module arp_rx (
    input         clk              ,
    input         rst              ,
    input  [31:0]     loca_ip      ,        //本地ip
    input  [47:0]     loca_mac     ,        //本地mac

    // input  [47:0] s_mac_src_mac    ,
    // input  [47:0] s_mac_dst_mac    ,
    // input  [15:0] s_mac_op_len     ,

    input  [ 7:0] s_mac_axis_data  ,
    input         s_mac_axis_valid ,
    input         s_mac_axis_last  ,
    output        s_mac_axis_ready , 
    input         s_mac_axis_error ,


    //arp的响应
    output reg     arp_resp_valid     ,
    input          arp_resp_ready     ,
    
    output  [31:0] arp_rx_src_ip    ,
    output  [31:0] arp_rx_dst_ip    ,
    output  [47:0] arp_rx_src_mac   ,
    output  [47:0] arp_rx_dst_mac   ,

    //arp应答请求
    output reg     arq_req         ,
    input          arq_req_ready 

);

    // localparam IDLE = 2'b01, RECIVE = 2'b10;
    // reg [1 : 0] state, next_state;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         state <= IDLE;
    //     end
    //     else begin
    //         state <= next_state;
    //     end
    // end

    // always @(*) begin
    //     case(state)
    //         IDLE:begin
    //             if(s_mac_axis_valid) begin
    //                 next_state = RECIVE;
    //             end
    //             else begin
    //                 next_state = IDLE;
    //             end
    //         end
    //         RECIVE:begin
    //             if((s_mac_axis_valid & s_mac_axis_ready & s_mac_axis_last) || s_mac_axis_error) begin
    //                 next_state = IDLE;
    //             end
    //             else begin
    //                 next_state = RECIVE;
    //             end
    //         end
    //         default:begin
    //             next_state = IDLE;
    //         end
    //     endcase
    // end

    assign s_mac_axis_ready = (cnt < 46);



    //计数器
    reg [5 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(s_mac_axis_last | s_mac_axis_error) begin
            cnt <= 0; 
        end
        else if(s_mac_axis_valid & s_mac_axis_ready) begin
            cnt <= cnt + 1'b1;
        end
        
    end


    //接收数据
    //信息
    reg  [31:0] src_ip    ;
    reg  [31:0] dst_ip    ;
    reg  [47:0] src_mac   ;
    reg  [47:0] dst_mac   ;
    reg  [15:0] op        ;
    //op
    always @(posedge clk) begin
        if((cnt > 5) && (cnt <= 7)) begin
            op <= {op[7 : 0], s_mac_axis_data};
        end
        // else if(cnt == 1) begin
        //     op <= 16'd0;
        // end
    end

    //src_mac
    always @(posedge clk) begin
        if((cnt > 7) && (cnt <= 13)) begin
            src_mac <= {src_mac[39 : 0], s_mac_axis_data};
        end
        // else if(cnt == 1) begin
        //     src_mac <= 48'd0;
        // end
    end

    //src_ip
    always @(posedge clk) begin
        if((cnt > 13) && (cnt <= 17)) begin
            src_ip <= {src_ip[23 : 0], s_mac_axis_data};
        end
        // else if(cnt == 1) begin
        //     src_ip <= 32'd0;
        // end
    end

    //dst_mac
    always @(posedge clk) begin
        if((cnt > 17) && (cnt <= 23)) begin
            dst_mac <= {dst_mac[39 : 0], s_mac_axis_data};
        end
        // else if(cnt == 1) begin
        //     dst_mac <= 48'd0;
        // end
    end

    //dst_ip
    always @(posedge clk) begin
        if((cnt > 23) && (cnt <= 27)) begin
            dst_ip <= {dst_ip[23 : 0], s_mac_axis_data};
        end
        // else if(cnt == 1) begin
        //     dst_ip <= 32'd0;
        // end
    end

    assign arp_rx_src_ip = src_ip;
    assign arp_rx_src_mac = src_mac;
    assign arp_rx_dst_ip = dst_ip;
    assign arp_rx_dst_mac = dst_mac;

    //接收到arp响应有效
    always @(posedge clk) begin
        if(rst) begin
            arp_resp_valid <= 1'b0;
        end
        else if(s_mac_axis_error || (cnt == 3)) begin
            arp_resp_valid <= 1'b0;
        end
        else if((cnt == 46) && (dst_ip == loca_ip) && (dst_mac == loca_mac) && (op == 16'h0002) && s_mac_axis_last) begin
            arp_resp_valid <= 1'b1;
        end
        else if(arp_resp_ready) begin
            arp_resp_valid <= 1'b0;
        end
    end


    //需要发送ARP请求
    always @(posedge clk) begin
        if(rst) begin
            arq_req <= 1'b0;
        end
        else if(s_mac_axis_error || (cnt == 3)) begin
            arq_req <= 1'b0;
        end
        else if((cnt == 46) && (dst_ip == loca_ip) && (op == 16'h0001) && s_mac_axis_last) begin
            arq_req <= 1'b1;
        end
        else if(arq_req_ready) begin
            arq_req <= 1'b0;
        end
        
    end



    


endmodule 