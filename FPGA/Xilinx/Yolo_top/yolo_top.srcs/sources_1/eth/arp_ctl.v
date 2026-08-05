module arp_ctl #(
    parameter REPEAT_TIME = 16'hFFFF,           //重发ARP广播的间隔时间
              REPEAT_CNT  = 2,                  //重发ARP广播的次数
              INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16
)(
    input clk,
    input rst,

    //来自mac的请求   tx
    input  mac_req_valid,
    output mac_req_ready,

    output reg arp_tx_valid,
    input      arp_tx_ready,
    output reg [47 : 0] arp_tx_dst_mac,
    output reg [31 : 0] arp_tx_dst_ip ,
    output reg [15 : 0] arp_tx_op     ,


    //arp应答请求    tx
    input      arq_req         ,
    output     arq_req_ready   ,

    //查找出的目的地址
    input [31 : 0]      dst_ip,
    output              dst_mac_valid,
    output reg [47 : 0] dst_mac,


    //rx
    input       arp_resp_valid,
    output      arp_resp_ready,
    input [47 : 0] arp_rx_src_mac,
    input [31 : 0] arp_rx_src_ip 
);
    


    localparam IDLE = 5'b00001, CACHE = 5'b00010, ARP_TX = 5'b00100, ARP_RX = 5'b01000, READY = 5'b10000;
    reg [4 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE:begin
                if(mac_req_valid & mac_req_ready) begin
                    next_state = CACHE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            CACHE:begin
                if(hit) begin
                    next_state = READY;
                end
                else if(!hit) begin
                    next_state = ARP_TX;
                end
                else begin
                    next_state = CACHE;
                end
            end
            //tx接收到要发送的数据
            ARP_TX:begin
                if(arp_tx_valid && arp_tx_ready) begin
                    next_state = ARP_RX;
                end
                else begin
                    next_state = ARP_TX;
                end
            end
            //要等代对方的ARP应答
            ARP_RX:begin
                if(arp_resp_valid & arp_resp_ready) begin       //收到对方应答
                    next_state = READY;
                end
                else if(time_cnt == REPEAT_TIME) begin
                    if(repeat_cnt == REPEAT_CNT) begin
                        next_state = IDLE;
                    end
                    else begin
                       next_state = ARP_TX; 
                    end
                end
                else begin
                    next_state = ARP_RX;
                end
            end
            READY:begin
                next_state = IDLE;
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end

    //超时重发计数器
    reg [15 : 0] time_cnt;
    always @(posedge clk) begin
        if(rst) begin
            time_cnt <= 0;
        end
        else if(state == ARP_RX) begin
            if(time_cnt == REPEAT_TIME) begin
                time_cnt <= 0;
            end
            else begin
                time_cnt <= time_cnt + 1'b1;
            end
        end
        else begin
            time_cnt <= 0;
        end
    end
    //重复几次
    reg [$clog2(REPEAT_TIME) : 0] repeat_cnt;
    always @(posedge clk) begin
        if(rst) begin
            repeat_cnt <= 0;
        end
        else if((state == ARP_RX) && (time_cnt == REPEAT_TIME)) begin
            if(repeat_cnt == REPEAT_CNT) begin
                repeat_cnt <= 0;
            end
            else begin
                repeat_cnt <= repeat_cnt + 1'b1;
            end
        end
    end




    //IDLE状态转移
    assign mac_req_ready = (state == IDLE);
    //ARP_RX状态转移信号
    assign arp_resp_ready = (state == ARP_RX) && (time_cnt > 70);      //防止请求没发完就提前收到响应 >70

    //旁路请求响应 (arp响应的发送不受状态机控制)
    reg          arp_req_valid   ;
    reg [48 : 0] arp_req_dst_mac ;
    reg [31 : 0] arp_req_dst_ip  ;
    reg [15 : 0] arp_req_op      ;
    always @(posedge clk) begin
        if(rst) begin
            arp_req_valid   <= 1'b0;
            arp_req_dst_mac <= 48'd0;
            arp_req_dst_ip  <= 32'd0;
            arp_req_op      <= 16'h0000;
        end
        else if(arq_req & arq_req_ready) begin
            arp_req_valid   <= 1'b1;
            arp_req_dst_mac <= arp_rx_src_mac;
            arp_req_dst_ip  <= arp_rx_src_ip; 
            arp_req_op      <= 16'h0002;
        end
        //旁路的tx的信号接收到了 拉低有效
        else if((state != ARP_TX) && arp_tx_valid && arp_tx_ready)begin     
            arp_req_valid <= 1'b0;
        end
    end
    //可以进行旁路ARP应答响应
    assign arq_req_ready = (state != ARP_TX);


    //tx最终连接的信号
    always @(posedge clk) begin
        if(rst) begin
            arp_tx_valid   <= 1'b0;
            arp_tx_dst_mac <= 48'd0;
            arp_tx_dst_ip  <= 32'd0;
            arp_tx_op      <= 16'd0;
        end
        else if(next_state == ARP_TX) begin
            arp_tx_valid    <= 1'b1 ;
            arp_tx_dst_mac  <= 48'h0000_0000_0000;
            arp_tx_dst_ip   <= dst_ip;
            arp_tx_op       <= 16'h0001 ;
        end
        else begin
            arp_tx_valid    <= arp_req_valid    ;
            arp_tx_dst_mac  <= arp_req_dst_mac  ;
            arp_tx_dst_ip   <= arp_req_dst_ip   ;
            arp_tx_op       <= arp_req_op       ;
        end
    end



    //arp查找表
    wire hit;
    wire wen = (arp_resp_valid & arp_resp_ready) || (arq_req & arq_req_ready);

    wire ren;
    assign ren = ((state == IDLE) && (next_state == CACHE));
    // always @(posedge clk) begin
    //     if(rst) begin
    //         ren <= 1'b0;
    //     end
    //     else if((state == IDLE) && (next_state == CACHE)) begin
    //         ren <= 1'b1;
    //     end
    //     else begin
    //         ren <= 1'b0;
    //     end
    // end

    wire [31 : 0] rip;
    assign rip = dst_ip;
    // reg [31 : 0] rip;
    // always @(posedge clk) begin
    //     if((state == IDLE) && (next_state == CACHE)) begin
    //         rip <= dst_ip;
    //     end
    // end

    assign dst_mac_valid = (state == READY);
    wire [47 : 0] rmac;
    always @(posedge clk) begin
        if(hit) begin
            dst_mac <= rmac;
        end
        else if(arp_resp_valid & arp_resp_ready) begin
            dst_mac <= arp_rx_src_mac;
        end
    end



    arp_cache #(
        .INVALID_TIME(INVALID_TIME),
        .CACHE_SIZE(CACHE_SIZE)
    )
    arp_cache(
        .clk(clk),
        .rst(rst),
        .wen(wen),
        .wip(arp_rx_src_ip),
        .wmac(arp_rx_src_mac),

        .ren(ren),                          //启动查找 
        .rip(rip),                 //要查找的IP地址  
        .rmac(rmac),           //mac输出
        .hit(hit)                      //命中标志
    );


endmodule