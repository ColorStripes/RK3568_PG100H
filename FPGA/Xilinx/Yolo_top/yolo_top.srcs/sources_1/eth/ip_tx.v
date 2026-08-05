module ip_tx(
    input clk,
    input rst,

    input [31 : 0] loca_ip,
    input [15 : 0] ip_tx_total_len,
    input [15 : 0] ip_tx_id,
    input [15 : 0] ip_tx_offset,
    input [7 : 0]  ip_tx_ttl,
    input [7 : 0]  ip_tx_protocol,
    // input [15 : 0] ip_tx_checksum,
    input [31 : 0] ip_tx_dst_ip,


    //请求控制IP层
    output reg        s_udp_axis_get   ,
    input             s_udp_axis_req   ,
    //UDP报文
    input  [7 : 0]    s_udp_axis_data  ,
    input             s_udp_axis_valid ,
    input             s_udp_axis_last  ,
    output            s_udp_axis_ready , 


    //请求控制MAC层总线
    input              m_mac_axis_get   ,
    output             m_mac_axis_req   ,
    //控制MAC层总线数据   
    output reg [7 : 0] m_mac_axis_data  ,    
    output reg         m_mac_axis_valid ,
    input              m_mac_axis_ready ,
    output reg         m_mac_axis_last  

);



    localparam REQ = 3'b001, IP_HEAD = 3'b010, IP_DATA = 3'b100;
    reg [2 : 0] state, next_state;
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
            //请求总线的权限
            REQ:begin
                if(m_mac_axis_req & m_mac_axis_get) begin
                    next_state = IP_HEAD;
                end
                else begin
                    next_state = REQ;
                end
            end 
            IP_HEAD:begin
                if(cnt == 19) begin
                    next_state = IP_DATA;
                end
                else begin
                    next_state = IP_HEAD;
                end
            end
            IP_DATA:begin
                if(s_udp_axis_valid && s_udp_axis_ready && s_udp_axis_last) begin
                    next_state = REQ;
                end
                else begin
                    next_state = IP_DATA;
                end
            end           
            default:begin
                next_state = REQ;
            end
        endcase
    end

    assign m_mac_axis_req = s_udp_axis_req;
    always @(posedge clk) begin
        if(rst) begin
            s_udp_axis_get <= 1'b0;
        end
        else if(cnt == 17) begin
            s_udp_axis_get <= 1'b1;
        end
        else if(s_udp_axis_req & s_udp_axis_get) begin
            s_udp_axis_get <= 1'b0;
        end
    end


    //锁存信息
    reg [3 : 0]  ver = 4'd4       ;
    reg [3 : 0]  hdr_len  = 4'd5   ;
    reg [15 : 0] total_len  ;
    reg [15 : 0] id         ;
    reg [15 : 0] offset     ;
    reg [7 : 0]  ttl        ;
    reg [7 : 0]  protocol   ;
    reg [31 : 0] src_ip     ;
    reg [31 : 0] dst_ip     ;
    // always @(posedge clk) begin

    // end

    assign s_udp_axis_ready = (state == IP_DATA);


    reg [4 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(state == IP_HEAD) begin
            cnt <= cnt + 1'b1;
        end
        else if(s_udp_axis_last) begin
            cnt <= 0;
        end
    end

    //发送数据
    always @(posedge clk) begin
        if(state == REQ) begin
            total_len <= ip_tx_total_len + 20;   //udp报文长度+20 ip包头
            id        <= ip_tx_id       ;
            offset    <= ip_tx_offset   ;
            ttl       <= ip_tx_ttl      ;
            protocol  <= ip_tx_protocol ;
            src_ip    <= loca_ip        ;
            dst_ip    <= ip_tx_dst_ip   ;
        end
        else begin
            case(1'b1)
                (cnt == 0):begin             //45
                    m_mac_axis_data <= {ver, hdr_len};
                end
                (cnt == 1):begin             //00
                    m_mac_axis_data <= 8'h00;
                end
                ((cnt == 2) || (cnt == 3)):begin             //len
                    m_mac_axis_data <= total_len[15 -: 8];
                    total_len <= total_len << 8;
                end
                ((cnt == 4) || (cnt == 5)):begin             //id
                    m_mac_axis_data <= id[15 -: 8];
                    id <= id << 8;
                end
                ((cnt == 6) || (cnt == 7)):begin             //frag
                    m_mac_axis_data <= offset[15 -: 8];
                    offset <= offset << 8;
                end
                (cnt == 8):begin             //ttl
                    m_mac_axis_data <= ttl;
                end
                (cnt == 9):begin             //protocol
                    m_mac_axis_data <= protocol;
                end
                (cnt == 10):begin
                    m_mac_axis_data <= checksum[15 -: 8];    //checksum
                end
                (cnt == 11):begin
                    m_mac_axis_data <= checksum[7 -: 8];
                end
                ((cnt > 11) && (cnt <= 15)):begin             //src_ip
                    m_mac_axis_data <= src_ip[31 -: 8];
                    src_ip <= src_ip << 8;
                end
                ((cnt > 15) && (cnt <= 19)):begin             //dst_ip
                    m_mac_axis_data <= dst_ip[31 -: 8];
                    dst_ip <= dst_ip << 8;
                end
                (cnt == 20):begin
                    m_mac_axis_data <= s_udp_axis_data;
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
        else if(state == IP_HEAD) begin
            m_mac_axis_valid <= 1'b1;
        end
        else if(m_mac_axis_last) begin
            m_mac_axis_valid <= 1'b0;
        end
    end


    //last
    always @(posedge clk) begin
        if(rst) begin
            m_mac_axis_last <= 1'b0;
        end
        else begin
            m_mac_axis_last <= s_udp_axis_last;
        end
    end


    wire [15 : 0] checksum;
    reg checksum_en;
    always @(posedge clk) begin
        if(rst) begin
            checksum_en <= 1'b0;
        end
        else if(m_mac_axis_req & m_mac_axis_get) begin
            checksum_en <= 1'b1;
        end
        else begin
            checksum_en <= 1'b0;
        end
    end
    //  ip_checksum
    ip_checksum ip_checksum_tx(
      .clk(clk)            ,
      .rst(rst)            ,

      .en (checksum_en)  ,

      .IP_ver        (ver) ,
      .IP_hdr_len    (hdr_len) ,
      .IP_tos        (8'd0) ,
      .IP_total_len  (total_len) ,
      .IP_id         (id) ,
      .IP_rsv        (offset[15]) ,
      .IP_df         (offset[14]) ,
      .IP_mf         (offset[13]) ,
      .IP_frag_offset(offset[12 : 0]) ,
      .IP_ttl        (ttl) ,
      .IP_protocol   (protocol) ,
      .checksum      (checksum) ,
      .src_ip        (src_ip) ,
      .dst_ip        (dst_ip) 

    );


endmodule