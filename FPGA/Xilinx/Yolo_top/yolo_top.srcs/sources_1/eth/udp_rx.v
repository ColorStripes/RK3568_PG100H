module udp_rx #(
    parameter DATA_DEPTH = 2048
)(

    input clk,
    input rst,


    //本地信息
    input  [15 : 0] loca_port    ,
    input  crc_error,
    input  crc_no_error,

    //从udp层进入解析
    input  [7 : 0]  s_ip_axis_data   ,
    input           s_ip_axis_valid  ,
    input           s_ip_axis_last   ,
    output          s_ip_axis_ready  ,   //这里这个ready不能反压上级  只能看是不是full   接受是实时的 没办法反压不接受
    input           s_ip_axis_error  ,


    //用户数据发出
    output  [7 : 0]  m_udp_axis_data  ,
    output           m_udp_axis_valid , 
    output           m_udp_axis_last  ,
    input            m_udp_axis_ready  

);

    //pyh芯片传来的错误帧
    reg error;
    always @(posedge clk) begin
        if(rst) begin
            error <= 1'b0;
        end
        else if(s_ip_axis_error) begin
            error <= 1'b1;
        end
        else if(!m_udp_axis_valid) begin
            error <= 1'b0;
        end
    end


    reg [15 : 0] loca_port_r;
    //锁存本地数据
    always @(posedge clk) begin
        if(s_ip_axis_valid) begin
            loca_port_r <= loca_port;
        end 
    end

    //计数器
    reg [15 : 0] cnt;
    always @(posedge clk) begin
        if(rst | s_ip_axis_error) begin
            cnt <= 0;
        end
        else if(s_ip_axis_valid & s_ip_axis_ready) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= 0;
        end
    end

    //接受数据寄存
    reg [15 : 0] src_port;
    reg [15 : 0] dst_port;
    reg [15 : 0] len;
    always @(posedge clk) begin
        if(s_ip_axis_valid) begin
            if((cnt == 0) || (cnt == 1)) begin
                src_port <= {src_port[7 : 0], s_ip_axis_data};
            end
        end
    end

    always @(posedge clk) begin
        if((cnt == 2) || (cnt == 3)) begin
            dst_port <= {dst_port[7 : 0], s_ip_axis_data};
        end
    end
    
    always @(posedge clk) begin
        if((cnt == 4) || (cnt == 5)) begin
            len <= {len[7 : 0], s_ip_axis_data};
        end
    end


    //接受用户数据
    reg [7 : 0] wdata;
    always @(posedge clk) begin
        if((cnt > 7) && (cnt < len)) begin
            wdata <= s_ip_axis_data;
        end
    end

    reg wen;
    always @(posedge clk) begin
        if(rst) begin
            wen <= 1'b0;
        end
        else if((cnt > 7) && (cnt < len) && (dst_port == loca_port_r)) begin
            wen <= s_ip_axis_valid;
        end
        else if(cnt == len) begin
            wen <= 1'b0;
        end
    end

    reg last;
    always @(posedge clk) begin
        if(rst) begin
            last <= 1'b0;
        end
        else if(cnt == len-1) begin
            last <= 1'b1;
        end
        else begin
            last <= 1'b0;
        end
    end


    //准备接受fcs的时间
    reg fcs_cnt_start;
    always @(posedge clk) begin
        if(rst) begin
            fcs_cnt_start <= 1'd0;
        end
        else if(fcs_cnt == 2'd3) begin
            fcs_cnt_start <= 1'd0;
        end
        else if(s_ip_axis_valid & s_ip_axis_last & s_ip_axis_ready) begin
            fcs_cnt_start <= 1'b1;
        end
    end

    reg [1 : 0] fcs_cnt;
    always @(posedge clk) begin
        if(rst) begin
            fcs_cnt <= 0;
        end
        else if(fcs_cnt == 2'd3) begin                  //这个操作是因为有18位的以太网长度不够补0操作
            if(crc_no_error || crc_error) begin
                fcs_cnt <= fcs_cnt + 1'b1;
            end
        end
        else if(fcs_cnt_start) begin
            fcs_cnt <= fcs_cnt + 1'b1;
        end
    end


    //pingpang  ///FIFO
    reg w_ctl;
    always @(posedge clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(wen & last & s_ip_axis_ready)begin
            w_ctl <= !w_ctl;
        end
    end



    wire crc_error_valid, crc_no_error_valid;
    assign crc_error_valid = crc_error && (fcs_cnt == 2'd3);
    assign crc_no_error_valid = crc_no_error && (fcs_cnt == 2'd3);

    reg crc_ctl;
    always @(posedge clk) begin
        if(rst) begin
            crc_ctl <= 1'b0;
        end
        else if(crc_error_valid || crc_no_error_valid)begin
            crc_ctl <= !crc_ctl;
        end
    end


    wire crc_error_ping, crc_error_pang;
    assign crc_error_ping = crc_ctl ? 1'b0 : crc_error_valid;
    assign crc_error_pang = crc_ctl ? crc_error_valid : 1'b0;


    wire crc_no_error_ping, crc_no_error_pang;
    assign crc_no_error_ping = crc_ctl ? 1'b0 : crc_no_error_valid;
    assign crc_no_error_pang = crc_ctl ? crc_no_error_valid : 1'b0;



    wire wen_ping, wen_pang;
    assign wen_ping = crc_ctl ? 1'b0 : wen;
    assign wen_pang = crc_ctl ? wen : 1'b0;


    wire error_ping, error_pang;
    assign error_ping = crc_ctl ? 1'b0 : error;
    assign error_pang = crc_ctl ? error : 1'b0;

    wire s_ready_ping, s_ready_pang;
    assign s_ip_axis_ready = crc_ctl ? s_ready_pang : s_ready_ping;


    reg r_ctl;
    always @(posedge clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_udp_axis_valid & m_udp_axis_ready & m_udp_axis_last) begin
            r_ctl <= !r_ctl;
        end
    end

    wire ren = m_udp_axis_valid & m_udp_axis_ready;
    wire ren_ping, ren_pang;
    assign ren_ping = r_ctl ? 1'b0 : ren;
    assign ren_pang = r_ctl ? ren : 1'b0;
   

    wire m_valid_ping, m_valid_pang;
    assign m_udp_axis_valid = r_ctl ? m_valid_pang : m_valid_ping;

    wire [7 : 0] m_data_ping, m_data_pang;
    assign m_udp_axis_data = r_ctl ? m_data_pang : m_data_ping;

    wire m_last_ping, m_last_pang;
    assign m_udp_axis_last = r_ctl ? m_last_pang & m_valid_pang : m_last_ping & m_valid_ping;

    wire m_ready_ping, m_ready_pang;
    assign m_ready_ping = r_ctl ? 1'b0 : m_udp_axis_ready;
    assign m_ready_pang = r_ctl ? m_udp_axis_ready : 1'b0;





    udp_rx_buf #(
        .DATA_WIDTH(8),
        .DATA_DEPTH(DATA_DEPTH)
    )
    ping_rx_buf(
        .clk(clk),
        .rst(rst | error_ping),

        .s_crc_error(crc_error_ping),
        .s_crc_no_error(crc_no_error_ping),
        .s_data(wdata) ,
        .s_valid(wen_ping),
        .s_last(last) ,
        .s_ready(s_ready_ping),


        .m_data(m_data_ping)  ,
        .m_valid(m_valid_ping),
        .m_last(m_last_ping)  ,
        .m_ready(m_ready_ping)
    );



    udp_rx_buf #(
        .DATA_WIDTH(8),
        .DATA_DEPTH(DATA_DEPTH)
    )
    pang_rx_buf(
        .clk(clk),
        .rst(rst | error_pang),

        .s_crc_error(crc_error_pang),
        .s_crc_no_error(crc_no_error_pang),
        .s_data(wdata) ,
        .s_valid(wen_pang),
        .s_last(last) ,
        .s_ready(s_ready_pang),


        .m_data(m_data_pang)  ,
        .m_valid(m_valid_pang),
        .m_last(m_last_pang)  ,
        .m_ready(m_ready_pang)
    );




    



endmodule