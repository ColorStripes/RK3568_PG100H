module mac_rx #(
    parameter DATA_DEPTH = 2048,
              READ_DELAY = 1
              
)(
    input clk,
    input rst,


    //本地信息
    input [47 : 0] loca_mac,
    //输出校验信息
    output reg fcs_error,
    output reg fcs_no_error,


    //进入mac层解析//从FIFO进入SPRAM变成连续数据
    input  [7 : 0]  s_gmii_axis_data   ,
    input           s_gmii_axis_valid  ,
    input           s_gmii_axis_last   ,
    output          s_gmii_axis_ready  ,   //这里这个ready能反压上级
    input           s_gmii_axis_error  ,

    //根据这个分发给ip还是arp
    output [15 : 0]      mac_type_len,
    //进入ip层解析
    output  reg [7 : 0]  m_ip_axis_data  ,
    output  reg          m_ip_axis_valid , 
    output  reg          m_ip_axis_last  ,
    input                m_ip_axis_ready ,
    output  reg          m_ip_axis_error 
);


    //变成连续数据出来
    wire [7 : 0] m_buf_axis_data ;
    wire         m_buf_axis_valid;
    wire         m_buf_axis_last ;
    wire         m_buf_axis_ready;
    wire         m_buf_axis_error;


    mac_rx_ctl #(
       .DATA_DEPTH(DATA_DEPTH),
       .READ_DELAY(READ_DELAY)
    )
    mac_rx_ctl_inst(
        .clk(clk)     ,
        .rst(rst)     ,
    
    
        .s_data (s_gmii_axis_data ) ,
        .s_valid(s_gmii_axis_valid) ,
        .s_last (s_gmii_axis_last ) ,
        .s_ready(s_gmii_axis_ready) ,
        .s_error(s_gmii_axis_error) ,
    
    
        .m_data (m_buf_axis_data ) ,
        .m_valid(m_buf_axis_valid) ,
        .m_last (m_buf_axis_last ) ,
        .m_ready(m_buf_axis_ready) ,
        .m_error(m_buf_axis_error) 
    );









    localparam IDLE = 2'b01, RECIVE = 2'b10;
    reg [1 : 0] state;
    reg [1 : 0] next_state;
    always @(posedge clk) begin
        if(rst | m_buf_axis_error) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE:begin
                if((preamble_cnt == 3'd7) && (m_buf_axis_data == 8'hD5)) begin
                    next_state = RECIVE;
                end
                else begin
                    next_state = IDLE;
                end
            end 
            RECIVE:begin
                if(m_buf_axis_valid & m_buf_axis_last & m_buf_axis_ready) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = RECIVE;
                end
            end      
            default:begin
                next_state = IDLE;
            end
        endcase
    end


    reg [2 : 0] preamble_cnt;
    always @(posedge clk) begin
        if(rst) begin
            preamble_cnt <= 3'd0;
        end
        else if((m_buf_axis_data == 8'h55) && m_buf_axis_valid) begin
            if(state == IDLE) begin
                preamble_cnt <= preamble_cnt + 1'b1;
            end
        end
        else begin
            preamble_cnt <= 3'd0;
        end
    end



    reg [3 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(m_ip_axis_last | m_buf_axis_error) begin
            cnt <= 0;
        end
        else if(state == RECIVE) begin
            if(cnt < 14) begin
                cnt <= cnt + 1'b1;
            end
        end
    end


    reg [47 : 0] loca_mac_r;
    //锁存本地数据
    always @(posedge clk) begin
        if(state == IDLE) begin
            loca_mac_r <= loca_mac;
        end 
    end






    reg [47 : 0] src_mac  ;
    reg [47 : 0] dst_mac  ;
    reg [15 : 0] type_len ;
    always @(posedge clk) begin
        if(state == RECIVE) begin
            if((cnt >= 0) && (cnt <= 5)) begin
                dst_mac <= {dst_mac[39 : 0], m_buf_axis_data};
            end
        end
    end

    always @(posedge clk) begin
        if((cnt > 5) && (cnt <= 11)) begin
            src_mac <= {src_mac[39 : 0], m_buf_axis_data};
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            type_len <= 16'd0;
        end
        else if((cnt == 12) || (cnt == 13)) begin
            type_len <= {type_len[7 : 0], m_buf_axis_data};
        end
    end

    assign mac_type_len = type_len;


    //接受用户数据
    always @(posedge clk) begin
        m_ip_axis_data <= m_buf_axis_data;
    end

    always @(posedge clk) begin
        if(rst) begin
            m_ip_axis_valid <= 1'b0;
        end
        else if(m_ip_axis_last | m_buf_axis_error) begin
            m_ip_axis_valid <= 1'b0;
        end
        else if((cnt > 13) && ((dst_mac == loca_mac_r) || (dst_mac == 48'hffff_ffff_ffff))) begin           
            m_ip_axis_valid <= m_buf_axis_valid;
        end
    end
    

    reg [3 : 0] m_ip_axis_ready_d;
    always @(posedge clk) begin
        if(rst | m_buf_axis_error) begin
            m_ip_axis_ready_d <= 0;
        end
        else begin
            m_ip_axis_ready_d <= {m_ip_axis_ready_d[3 : 0], m_ip_axis_ready};
        end
    end
    assign m_buf_axis_ready = m_ip_axis_ready | m_ip_axis_ready_d[2];       //这里加长ready为了接受4字节的FCS


    //控制arp——rx最后的数据
    always @(posedge clk) begin
        if(rst | m_buf_axis_error) begin
            m_ip_axis_last <= 1'b0;
        end
        // else if(~m_ip_axis_ready_d[1] && m_ip_axis_ready_d[2]) begin
        //     m_ip_axis_last <= 1'd1;
        // end
        // else begin
        //     m_ip_axis_last <= 1'b0;
        // end
        // else
        else if(m_buf_axis_valid & m_buf_axis_ready) begin
            m_ip_axis_last <= m_buf_axis_last;
        end
        else begin
            m_ip_axis_last <= 1'b0;
        end
    end


    
    always @(posedge clk) begin
        if(rst) begin
            m_ip_axis_error <= 1'b0;
        end
        else if(m_buf_axis_valid & m_buf_axis_ready) begin
            m_ip_axis_error <= m_buf_axis_error;
        end
        else begin
            m_ip_axis_error <= 1'b0;
        end
    end






    wire crc_en;
    assign crc_en = (cnt >= 1) ? m_ip_axis_ready : 1'b0;


    reg [31 : 0] fcs;
    always @(posedge clk) begin
        if(m_buf_axis_valid && (state == RECIVE)) begin
            fcs <= {fcs[23 : 0], m_buf_axis_data};
        end
    end

    wire [31 : 0] crc;
    CRC CRC32_rx(
        .rst(rst),
        .clk(clk),
        .data_in(m_ip_axis_data),
        .crc_en(crc_en),
        .crc_initialize(m_ip_axis_last),
    
        .crc(crc),
        .crc_next(),
        .crc_eth()
    );

    wire [31 : 0] crc_fcs = ~{
        crc[24],      crc[25],      crc[26],      crc[27],      crc[28],      crc[29],      crc[30],      crc[31],
        crc[16],      crc[17],      crc[18],      crc[19],      crc[20],      crc[21],      crc[22],      crc[23],
        crc[8],       crc[9],       crc[10],      crc[11],      crc[12],      crc[13],      crc[14],      crc[15],
        crc[0],       crc[1],       crc[2],       crc[3],       crc[4],       crc[5],       crc[6],       crc[7]
    };
    always @(posedge clk) begin
        if(rst) begin
            fcs_error <= 1'b0;
            fcs_no_error <= 1'b0;
        end
        else if(m_ip_axis_valid & m_ip_axis_last) begin
            if(fcs == crc_fcs) begin
                fcs_error <= 1'b0;
                fcs_no_error <= 1'b1;
            end
            else begin
                fcs_error <= 1'b1;
                fcs_no_error <= 1'b0;
            end     
        end
        else begin
            fcs_error <= 1'b0;
            fcs_no_error <= 1'b0;
        end
    end


endmodule