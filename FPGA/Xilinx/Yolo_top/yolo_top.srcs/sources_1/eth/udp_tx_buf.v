module udp_tx_buf #(
    parameter DATA_DEPTH = 2048,                         //支持缓存的最大数据深度 
              ADDR_WIDTH = $clog2(DATA_DEPTH),           //地址位宽
              READ_DELAY = 1
)(
    input clk,
    input rst,

    //本地信息
    input  [15 : 0] loca_port    ,
    input  [31 : 0] loca_ip      ,
    //udp的所有配置信息
    input  [15 : 0] udp_tx_dst_port  ,
    input  [31 : 0] udp_tx_dst_ip    ,
    //用户数据输入
    input  [7 : 0]    s_udp_axis_data  ,
    input             s_udp_axis_valid ,
    input             s_udp_axis_last  ,
    output            s_udp_axis_ready , 


    //告诉ip层自己有多少字节
    output [15 : 0]      udp_len      ,
    //告诉ip层数据要发往哪个ip 和当前ip
    output [31 : 0]      udp_src_ip   ,
    output [31 : 0]      udp_dst_ip   ,
    //请求控制IP层
    input             m_ip_axis_get   ,
    output            m_ip_axis_req   ,
    //控制IP层   
    output reg [ 7:0] m_ip_axis_data  ,    
    output reg        m_ip_axis_valid ,
    input             m_ip_axis_ready ,
    output            m_ip_axis_last  
);




    localparam WRITE = 4'b0001, REQ = 4'b0010, UDP_HEAD = 4'b0100, UDP_DATA = 4'b1000;
    reg [3 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= WRITE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            //写入用户数据
            WRITE:begin 
                if(s_udp_axis_valid & s_udp_axis_ready & s_udp_axis_last) begin
                    next_state = REQ;
                end
                else begin
                    next_state = WRITE;
                end
            end
            //请求总线的权限
            REQ:begin
                if(m_ip_axis_req & m_ip_axis_get) begin
                    next_state = UDP_HEAD;
                end
                else begin
                    next_state = REQ;
                end
            end
            //发送头部
            UDP_HEAD:begin
                if(cnt == 7) begin
                    next_state = UDP_DATA;
                end
                else begin
                    next_state = UDP_HEAD;
                end
            end            
            //发送ARP数据 (因为数据有一周期延迟 导致一旦发送数据 就不能停止)
            UDP_DATA:begin
                if(m_ip_axis_valid && m_ip_axis_ready && m_ip_axis_last) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = UDP_DATA;
                end
            end
            default:begin
                next_state = WRITE;
            end
        endcase
    end

    reg [15 : 0] udp_tx_len;
    always @(posedge clk) begin
        if(rst) begin
            udp_tx_len <= 16'd1;
        end
        else if(s_udp_axis_valid & s_udp_axis_ready) begin
            udp_tx_len <= udp_tx_len + 1'b1;
        end
        else if(state == UDP_HEAD) begin
            udp_tx_len <= 16'd1;
        end
    end


    //写入数据
    wire wen = s_udp_axis_valid & s_udp_axis_ready;
    reg [ADDR_WIDTH-1 : 0] waddr;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr <= 0;
        end                                                                                                                                          
        else if(state == WRITE) begin
            if(wen) begin
                waddr <= waddr + 1'b1;
            end
        end
        else begin
            waddr <= 0;
        end                                   
    end
    assign s_udp_axis_ready = (state == WRITE);


    //锁存信息
    reg [31 : 0] src_ip    ;
    reg [31 : 0] dst_ip    ;
    reg [15 : 0] src_port  ;
    reg [15 : 0] dst_port  ;
    reg [15 : 0] len       ;
    reg [15 : 0] data_len  ;
    // always @(posedge clk) begin

    // end
    //REQ
    assign m_ip_axis_req = (state == REQ);
    //len
    assign udp_len = len;
    //ip
    assign udp_src_ip  = src_ip;
    assign udp_dst_ip  = dst_ip;

    //计数器
    reg [3 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(state == UDP_HEAD) begin
            cnt <= cnt + 1'b1;
        end
        else if(m_ip_axis_last) begin
            cnt <= 0;
        end
    end

    wire [7 : 0] rdata;
    //发送数据
    always @(posedge clk) begin
        if(state == WRITE) begin
            src_ip    <=  loca_ip;
            dst_ip    <=  udp_tx_dst_ip;
            src_port  <=  loca_port   ;
            dst_port  <=  udp_tx_dst_port ;
            len       <=  udp_tx_len + 16'd8;      //多8字节的头数据
            data_len  <=  udp_tx_len;
        end
        else begin
            case(1'b1)
                (cnt == 0):begin             //src_port
                    m_ip_axis_data <= src_port[15 -: 8];
                end
                (cnt == 1):begin             //src_port
                    m_ip_axis_data <= src_port[7 -: 8];
                end
                ((cnt == 2) || (cnt == 3)):begin             //dst_port
                    m_ip_axis_data <= dst_port[15 -: 8];
                    dst_port <= dst_port << 8;
                end
                ((cnt == 4) || (cnt == 5)):begin             //len
                    m_ip_axis_data <= len[15 -: 8];
                    len <= len << 8;
                end
                (cnt == 6):begin             //checksum
                    m_ip_axis_data <= 8'h00;
                end
                (cnt == 7):begin             //checksum
                    m_ip_axis_data <= 8'h00;
                end
                (cnt == 8):begin
                    m_ip_axis_data <= rdata;
                end
                default:begin
                    m_ip_axis_data <= 8'h01;
                end
            endcase
        end
    end



    //valid
    always @(posedge clk) begin
        if(rst) begin
            m_ip_axis_valid <= 1'b0;
        end
        else if(state == UDP_HEAD) begin
            m_ip_axis_valid <= 1'b1;
        end
        else if(m_ip_axis_last) begin
            m_ip_axis_valid <= 1'b0;
        end
    end



    //读时序                                 
    reg ren;
    always @(posedge clk) begin
        if(rst) begin
            ren <= 1'b0;
        end
        else if(cnt == 7-READ_DELAY) begin
            ren <= 1'b1;
        end
        else if(r_last) begin
            ren <= 1'b0;
        end
    end

    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr <= 0;
        end                                                                                                                                          
        else if(ren) begin
            raddr <= raddr + 1'b1;
        end
        else begin
            raddr <= 0;
        end                                   
    end

    //这个last是与rdata对齐的 不是与raddr
    reg r_last;
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if((raddr == data_len-2 + READ_DELAY) && (next_state == UDP_DATA)) begin
            r_last <= 1'b1;
        end
        else begin
            r_last <= 1'b0;
        end
    end


    //这一周期延迟是因为rdata到m_data的一周期
    reg m_last_d; 
    always @(posedge clk) begin
        if(rst) begin
            m_last_d <= 0;
        end
        else begin
            m_last_d <= r_last;
        end
    end
    assign m_ip_axis_last = m_last_d;           





    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(8),             //数据位宽
            .PIPE(READ_DELAY)  
    ) 
    spram_inst(
        .clk   (clk   ),
        .wdata (s_udp_axis_data ),
        .wen   (wen   ),
        .waddr (waddr ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (rdata )
    );



endmodule