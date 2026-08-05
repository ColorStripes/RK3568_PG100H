module ip_rx(

    input clk,
    input rst,


    //本地信息
    input [31 : 0] loca_ip,

    //进入ip层解析
    input  [7 : 0]  s_mac_axis_data   ,
    input           s_mac_axis_valid  ,
    input           s_mac_axis_last   ,     //这里是包含fcs的
    output          s_mac_axis_ready  ,     //这里这个ready反压上级  rx存到async_fifo中
    input           s_mac_axis_error  ,


    //进入udp解析
    output  reg [7 : 0]  m_udp_axis_data  ,
    output  reg          m_udp_axis_valid , 
    output  reg          m_udp_axis_last  ,      //这里是不包含fcs的
    input                m_udp_axis_ready ,
    output  reg          m_udp_axis_error 
);



    reg [31 : 0] loca_ip_r;
    //锁存本地数据
    always @(posedge clk) begin
        if(s_mac_axis_valid) begin
            loca_ip_r <= loca_ip;
        end 
    end

    reg [15 : 0] cnt;
    always @(posedge clk) begin
        if(rst | s_mac_axis_error) begin
            cnt <= 0;
        end
        else if(s_mac_axis_valid & s_mac_axis_ready) begin
            cnt <= cnt + 1'b1;
        end
        else if(~s_mac_axis_valid) begin
            cnt <= 0;
        end
    end

    reg [3 : 0]  ver        ;
    reg [3 : 0]  hdr_len    ;

    reg [15 : 0] total_len  ;
    reg [15 : 0] id         ;
    reg [15 : 0] offset     ;
    reg [7 : 0]  ttl        ;
    reg [7 : 0]  protocol   ;
    reg [15 : 0] checksum   ;
    reg [31 : 0] src_ip     ;
    reg [31 : 0] dst_ip     ;
    always @(posedge clk) begin
        if(s_mac_axis_valid & s_mac_axis_ready) begin
            if(cnt == 0) begin
                ver <= s_mac_axis_data[7 : 4];
                hdr_len <= s_mac_axis_data[3 : 0];
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            total_len <= 16'd0;
        end
        else if((cnt == 2) || (cnt == 3)) begin
            total_len <= {total_len[7 : 0], s_mac_axis_data};
        end
    end

    always @(posedge clk) begin
        if((cnt == 4) || (cnt == 5)) begin
            id <= {id[7 : 0], s_mac_axis_data};
        end
    end

    always @(posedge clk) begin
        if((cnt == 6) || (cnt == 7)) begin
            offset <= {offset[7 : 0], s_mac_axis_data};
        end
    end

    always @(posedge clk) begin
        if(cnt == 8) begin
            ttl <= s_mac_axis_data;
        end
    end

    always @(posedge clk) begin
        if(cnt == 9) begin
            protocol <= s_mac_axis_data;
        end
    end

    always @(posedge clk) begin
        if((cnt == 10) || (cnt == 11)) begin
            checksum <= {checksum[7 : 0], s_mac_axis_data};
        end
    end

    always @(posedge clk) begin
        if((cnt > 11) && (cnt <= 15)) begin
            src_ip <= {src_ip[23 : 0], s_mac_axis_data};
        end
    end

    always @(posedge clk) begin
        if((cnt > 15) && (cnt <= 19)) begin
            dst_ip <= {dst_ip[23 : 0], s_mac_axis_data};
        end
    end

    //接受用户数据
    always @(posedge clk) begin
        if((cnt > 19) && (cnt < total_len)) begin
            m_udp_axis_data <= s_mac_axis_data;
        end
    end

    wire [15 : 0] ip_checksum;
    always @(posedge clk) begin
        if(rst | s_mac_axis_error) begin
            m_udp_axis_valid <= 1'b0;
        end
        else if((cnt == hdr_len*4) && (dst_ip == loca_ip_r)) begin            //cnt == 20
            m_udp_axis_valid <= s_mac_axis_valid;
        end
        else if((cnt == hdr_len*4+1) && (checksum != ip_checksum)) begin
            m_udp_axis_valid <= 1'b0;
        end
        else if(m_udp_axis_last) begin
            m_udp_axis_valid <= 1'b0;
        end
    end


    always @(posedge clk) begin
        if(rst | s_mac_axis_error) begin
            m_udp_axis_last <= 1'b0;
        end
        else if(cnt == total_len-1) begin
            m_udp_axis_last <= 1'b1;
        end
        else begin
            m_udp_axis_last <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            m_udp_axis_error <= 1'b0;
        end
        else begin
            m_udp_axis_error <= s_mac_axis_error;
        end
    end



    reg checksum_en;
    always @(posedge clk) begin
        if(rst | s_mac_axis_error) begin
            checksum_en <= 1'b0;
        end
        else if(cnt == 19) begin
            checksum_en <= 1'b1;
        end
        else if(cnt == 0) begin
            checksum_en <= 1'b0;
        end
    end

    

    ip_checksum ip_checksum_rx(
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
      .checksum      (ip_checksum) ,
      .src_ip        (src_ip) ,
      .dst_ip        (dst_ip) 

    );


    wire ready;
    assign ready = m_udp_axis_ready ?   ( (total_len < 46) ? (cnt < 46) : (cnt < total_len) )
                                        : ((cnt == 0) ? 1'b0 : (cnt < 46));

    assign s_mac_axis_ready = ready && ~s_mac_axis_error;


endmodule