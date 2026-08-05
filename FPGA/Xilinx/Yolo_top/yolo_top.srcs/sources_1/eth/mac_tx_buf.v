module mac_tx_buf #(
    parameter DATA_DEPTH = 2048
)(
    input clk,
    input rst,


    //本地信息
    input  [47 : 0] loca_mac    ,
    //mac的所有配置信息
    input  [47 : 0] mac_tx_dst_mac  ,
    input  [15 : 0] mac_tx_type_len ,


    //从ip层进入的申请
    output reg    s_ip_axis_get   ,
    input         s_ip_axis_req   ,
    //IP报文   
    input [7 : 0] s_ip_axis_data  ,    
    input         s_ip_axis_valid ,
    output reg    s_ip_axis_ready ,
    input         s_ip_axis_last  ,



    //mac层输出
    output [7 : 0]  m_gmii_axis_data  ,    
    output          m_gmii_axis_valid ,
    input           m_gmii_axis_ready , 
    output          m_gmii_axis_last  
    
);



    
    localparam REQ = 5'b00001, MAC_HEAD = 5'b00010, MAC_DATA = 5'b00100, FCS = 5'b01000, FINISN = 5'b10000;
    reg [4 : 0] state, next_state;
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
                if(s_ip_axis_req) begin  
                    next_state = MAC_HEAD;
                end
                else begin
                    next_state = REQ;
                end
            end 
            MAC_HEAD:begin
                if(cnt == 21) begin
                    next_state = MAC_DATA;
                end
                else begin
                    next_state = MAC_HEAD;
                end
            end
            MAC_DATA:begin
                if((s_ip_axis_valid && s_ip_axis_last && (data_cnt == 6'd45)) || (less_46 && (data_cnt == 6'd45))) begin
                    next_state = FCS;
                end
                else begin
                    next_state = MAC_DATA;
                end
            end
            FCS:begin
                if(cnt == 26) begin
                    next_state = FINISN;
                end
                else begin
                    next_state = FCS;
                end
            end
            //FIFO输出
            FINISN:begin
                if(m_gmii_axis_valid & m_gmii_axis_ready & m_gmii_axis_last) begin  
                    next_state = REQ;
                end
                else begin
                    next_state = FINISN;
                end
            end           
            default:begin
                next_state = REQ;
            end
        endcase
    end


    always @(posedge clk) begin
        if(rst) begin
            s_ip_axis_ready <= 1'b0;
        end
        else if(cnt == 19) begin
            s_ip_axis_ready <= 1'b1;
        end
        else if(s_ip_axis_last) begin
            s_ip_axis_ready <= 1'b0;
        end
    end


    always @(posedge clk) begin
        if(rst) begin
            s_ip_axis_get <= 1'b0;
        end
        else if(cnt == 19) begin
            s_ip_axis_get <= 1'b1;
        end
        else if(s_ip_axis_req & s_ip_axis_get) begin
            s_ip_axis_get <= 1'b0;
        end
    end


    //data_cnt  应对数据长度大于46
    reg [5 : 0] data_cnt;
    always @(posedge clk) begin
        if(rst) begin
            data_cnt <= 6'd0;
        end
        else if(state != MAC_DATA) begin
            data_cnt <= 6'd0;
        end
        else if(data_cnt == 6'd45) begin
            data_cnt <= data_cnt;
        end
        else if(state == MAC_DATA) begin
            data_cnt <= data_cnt + 1'b1;
        end
    end

    reg less_46;
    always @(posedge clk) begin
        if(rst) begin
            less_46 <= 1'b0;
        end
        else if((data_cnt != 45) && s_ip_axis_last && s_ip_axis_valid) begin
            less_46 <= 1'b1;
        end
        else if(state != MAC_DATA) begin
            less_46 <= 1'b0;
        end
    end





    //锁存信息
    reg [47 : 0] src_mac  ;
    reg [47 : 0] dst_mac  ;
    reg [15 : 0] type_len ;
    // always @(posedge clk) begin

    // end
    

    reg [4 : 0] cnt;
    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
        end
        else if(m_last) begin
            cnt <= 0;
        end
        else if(state == MAC_HEAD) begin
            cnt <= cnt + 1'b1;
        end
        else if(next_state == FCS) begin
            cnt <= cnt + 1'b1;
        end
        
    end

    //发送数据
    wire [31 : 0] fcs;
    reg [7 : 0] m_data;
    always @(posedge clk) begin
        if(state == REQ) begin
            src_mac  <= loca_mac ;
            dst_mac  <= mac_tx_dst_mac ;
            type_len <= mac_tx_type_len;
        end
        else begin
            case(1'b1)
                ((cnt >= 0) && (cnt <= 6)):begin          //前导码
                    m_data <= 8'h55;
                end
                (cnt == 7):begin                          //D5
                    m_data <= 8'hD5;
                end
                ((cnt > 7) && (cnt <= 13)):begin             //dst_mac
                    m_data <= dst_mac[47 -: 8];
                    dst_mac <= dst_mac << 8;
                end
                ((cnt > 13) && (cnt <= 19)):begin             //src_mac
                    m_data <= src_mac[47 -: 8];
                    src_mac <= src_mac << 8;
                end
                ((cnt == 20) || (cnt == 21)):begin             //type_len
                    m_data <= type_len[15 -: 8];
                    type_len <= type_len << 8;
                end
                (cnt == 22):begin                          //ip data
                    m_data <= s_ip_axis_data;
                end
                (cnt == 23):begin                           //fcs
                    m_data <= fcs[31 -: 8];
                end
                (cnt == 24):begin
                    m_data <= fcs[23 -: 8];
                end
                (cnt == 25):begin
                    m_data <= fcs[15 -: 8];
                end
                (cnt == 26):begin
                    m_data <= fcs[7 -: 8];
                end
                default:begin
                    m_data <= 8'h00;
                end
            endcase
        end
    end


    //valid(fifo_wen)
    reg wen;
    always @(posedge clk) begin
        if(rst) begin
            wen <= 1'b0;
        end
        else if(state == MAC_HEAD) begin
            wen <= 1'b1;
        end
        else if(m_last) begin
            wen <= 1'b0;
        end
    end


    //last
    reg m_last;
    always @(posedge clk) begin
        if(rst) begin
            m_last <= 1'b0;
        end
        else if(m_last) begin
            m_last <= 1'b0;
        end
        else if(cnt == 26) begin
            m_last <= 1'b1;
        end
    end


    //crc_en
    reg crc_en;
    always @(posedge clk) begin
        if(rst) begin
            crc_en <= 1'b0;
        end
        else if(cnt == 8) begin
            crc_en <= 1'b1;
        end
        else if(cnt == 23) begin
            crc_en <= 1'b0;
        end
    end


    CRC CRC32_tx(
        .rst(rst),
        .clk(clk),
        .data_in(m_data),
        .crc_en(crc_en),
        .crc_initialize(m_last),

        .crc(),
        .crc_next(),
        .crc_eth(fcs)

    );




  //fifo
  //m_data 全部写入fifo  由fifo控制输出

    wire [8 : 0] din = {m_last, m_data};
    wire [8 : 0] dout;
    wire full, empty;
    wire ren = m_gmii_axis_valid & m_gmii_axis_ready;

    sync_fifo #(
        .DATA_WIDTH(8+1),
        .DATA_DEPTH(DATA_DEPTH)
    )
    sync_fifo_mac_tx(
        .clk(clk),
        .rst(rst),
        .wr_en(wen),
        .rd_en(ren),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );



    // reg gmii_axis_valid;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         gmii_axis_valid <= 1'b0;
    //     end
    //     else if(m_gmii_axis_last) begin
    //         gmii_axis_valid <= 1'b0;
    //     end
    //     else begin
    //         gmii_axis_valid <= !empty;
    //     end
    // end
    // assign m_gmii_axis_valid = gmii_axis_valid & !empty;

    assign m_gmii_axis_valid = !empty;
    assign m_gmii_axis_last = dout[8] & m_gmii_axis_valid;
    assign m_gmii_axis_data = dout[7 : 0];

endmodule