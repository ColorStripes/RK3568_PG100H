module arp_tx (
    input         clk              ,
    input         rst              ,

    //本地信息
    input  [31:0] loca_ip    ,
    input  [47:0] loca_mac   ,
    //arp的所有配置信息
    input         arp_tx_valid     ,
    output        arp_tx_ready     ,
    input  [31:0] arp_tx_dst_ip    ,
    input  [47:0] arp_tx_dst_mac   ,
    input  [15:0] arp_tx_op        ,

    // output [47:0] m_mac_src_mac    ,
    // output [47:0] m_mac_dst_mac    ,
    // output [15:0] m_mac_op_len     ,
    //
    output [47 : 0]  arp_dst_mac,

    //请求控制MAC层总线
    input              m_mac_axis_get   ,
    output             m_mac_axis_req   ,
    //控制MAC层总线数据   
    output reg [ 7:0] m_mac_axis_data  ,    //以字节发送arp报文内容
    output reg        m_mac_axis_valid ,
    input             m_mac_axis_ready ,
    output reg        m_mac_axis_last  


);


    localparam IDLE = 4'b0001, REQ = 4'b0010, READY = 4'b0100, SEND = 4'b1000;
    reg [3 : 0] state, next_state;
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
            //得知要TX发送
            IDLE:begin
                if(arp_tx_valid & arp_tx_ready) begin
                    next_state = REQ;
                end
                else begin
                    next_state = IDLE;
                end
            end
            //请求总线的权限
            REQ:begin
                if(m_mac_axis_req & m_mac_axis_get) begin
                    next_state = SEND;
                end
                else begin
                    next_state = REQ;
                end
            end            
            //检测总线是否繁忙
            READY:begin
                if(m_mac_axis_ready) begin
                    next_state = SEND;
                end
                else begin
                    next_state = READY;
                end
            end
            //发送ARP数据 (因为数据有一周期延迟 导致一旦发送数据 就不能停止)
            SEND:begin
                if(m_mac_axis_valid && m_mac_axis_ready && (cnt == 27)) begin
                    next_state = IDLE;
                end
                else if(!m_mac_axis_ready) begin
                    next_state = READY;
                end
                else begin
                    next_state = SEND;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end


    //锁存信息
    reg  [31:0] src_ip    ;
    reg  [31:0] dst_ip    ;
    reg  [47:0] src_mac   ;
    reg  [47:0] dst_mac   ;
    reg  [15:0] op        ;
    // always @(posedge clk) begin

    // end
    assign arp_tx_ready = (state == IDLE);

    //REQ
    assign m_mac_axis_req = (state == REQ);
    assign arp_dst_mac = dst_mac;

    //计数器
    reg [4 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(state == SEND) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= 0;
        end
    end

    //发送数据
    always @(posedge clk) begin
        if(arp_tx_valid & arp_tx_ready) begin
            src_ip  <=  loca_ip  ;
            dst_ip  <=  arp_tx_dst_ip  ;
            src_mac <=  loca_mac ;
            dst_mac <=  arp_tx_dst_mac ;
            op      <=  arp_tx_op      ;
        end
        else begin
            case(1'b1)
                (cnt == 0):begin             
                    m_mac_axis_data <= 8'h00;
                end
                (cnt == 1):begin             //硬件地址类型
                    m_mac_axis_data <= 8'h01;
                end
                (cnt == 2):begin             
                    m_mac_axis_data <= 8'h08;
                end
                (cnt == 3):begin             //协议类型
                    m_mac_axis_data <= 8'h00;
                end
                (cnt == 4):begin             //硬件地址长度  mac长度
                    m_mac_axis_data <= 8'h06;
                end
                (cnt == 5):begin             //协议地址长度  IP长度
                    m_mac_axis_data <= 8'h04;
                end
                ((cnt > 5) && (cnt <= 7)):begin              //op
                    m_mac_axis_data <= op[15 -: 8];
                    op <= op << 8;
                end
                ((cnt > 7) && (cnt <= 13)):begin             //src_mac
                    m_mac_axis_data <= src_mac[47 -: 8];
                    src_mac <= src_mac << 8;
                end
                ((cnt > 13) && (cnt <= 17)):begin            //src_ip
                    m_mac_axis_data <= src_ip[31 -: 8];
                    src_ip <= src_ip << 8;
                end
                ((cnt > 17) && (cnt <= 23)):begin            //dst_mac
                    m_mac_axis_data <= dst_mac[47 -: 8];
                    dst_mac <= dst_mac << 8;
                end
                ((cnt > 23) && (cnt <= 27)):begin            //dst_ip
                    m_mac_axis_data <= dst_ip[31 -: 8];
                    dst_ip <= dst_ip << 8;
                end
                default:begin
                    m_mac_axis_data <= 8'h00;
                end
            endcase
        end
    end

    //valid
    always @(posedge clk) begin
        if(rst) begin
            m_mac_axis_valid <= 1'b0;
        end
        else if((state == SEND) && (next_state != READY)) begin
            m_mac_axis_valid <= 1'b1;
        end
        else begin
            m_mac_axis_valid <= 1'b0;
        end
    end

    //last
    always @(posedge clk) begin
        if(rst) begin
            m_mac_axis_last <= 1'b0;
        end
        else if(cnt == 27) begin
            m_mac_axis_last <= 1'b1;
        end
        else begin
            m_mac_axis_last <= 1'b0;
        end
    end






endmodule 