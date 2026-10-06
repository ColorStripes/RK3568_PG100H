module cmd_mm2s #(
    parameter USER_ADDR_WIDTH = 32,
              USER_LEN_WIDTH = 32,
              ADDR_WIDTH = 32,
              BTT_WIDTH = 23,
              TYPE = 1'b1,
              DATA_WIDTH = 128,
              KEEP_WIDTH = DATA_WIDTH / 8
              
)(
    input clk,
    input rst,

    // 用户命令接口
    input                           read_cmd_valid,
    input [USER_ADDR_WIDTH-1 : 0]   read_cmd_addr ,
    input [USER_LEN_WIDTH-1 : 0]    read_cmd_len  ,  // 字节数
    output                          read_cmd_ready,

    // 用户数据流接口
    output  [DATA_WIDTH-1:0]        read_data    ,
    output  [KEEP_WIDTH-1:0]        read_keep    ,
    output                          read_valid   ,
    output                          read_last    ,
    input                           read_ready   ,

    // DataMover 命令接口
    output  [40+ADDR_WIDTH-1 : 0]   s_axis_mm2s_cmd_tdata, 
    output                          s_axis_mm2s_cmd_tvalid,
    input                           s_axis_mm2s_cmd_tready,

    // DataMover stream 数据接口
    input [DATA_WIDTH-1:0]          m_axis_mm2s_tdata,
    input [KEEP_WIDTH-1:0]          m_axis_mm2s_tkeep,
    input                           m_axis_mm2s_tvalid,
    input                           m_axis_mm2s_tlast,
    output                          m_axis_mm2s_tready,

    // DataMover 状态接口
    input  [7:0]                    m_axis_mm2s_sts_tdata,
    input                           m_axis_mm2s_sts_tkeep,
    input                           m_axis_mm2s_sts_tlast,
    input                           m_axis_mm2s_sts_tvalid,
    output                          m_axis_mm2s_sts_tready
);



    

    //FSM状态机
    localparam IDLE = 2'b00, SEND_DATA = 2'b01, WAIT_DONE = 2'b10;
    reg [1 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) state <= IDLE;
        else    state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:
                if(read_cmd_valid && read_cmd_ready)
                    next_state = SEND_DATA;

            SEND_DATA:
                if(m_axis_mm2s_tvalid && m_axis_mm2s_tlast && m_axis_mm2s_tready)
                    next_state = WAIT_DONE;

            WAIT_DONE:          //STS通道判断
                if(m_axis_mm2s_sts_tvalid && m_axis_mm2s_sts_tready && m_axis_mm2s_sts_tdata == 8'b1000_0000)
                    next_state = IDLE;
        endcase
    end


    // Command 发送
    assign s_axis_mm2s_cmd_tvalid = read_cmd_valid && (state == IDLE);
    // 格式：{rsvd, tag, addr, drr, eof, dsa, type, btt}
    wire [22 : 0] btt = read_cmd_len[BTT_WIDTH-1 : 0];
    wire type = TYPE;                           //AXI INCR类型
    wire [5 : 0] dsa = 6'd0;
    wire eof = 1'b1;
    wire drr = 1'b0;
    wire [ADDR_WIDTH-1 : 0] addr = read_cmd_addr;
    wire [3 : 0] tag = 4'd0;
    wire [3 : 0] rsvd = 4'd0;
    assign s_axis_mm2s_cmd_tdata[40+ADDR_WIDTH-1 : 0] = {
                rsvd,
                tag,
                addr,
                drr,
                eof,
                dsa,
                type,
                btt
            };
    assign read_cmd_ready = (state == IDLE) ? s_axis_mm2s_cmd_tready : 1'b0;


    // DataMover stream 数据接口
    assign read_data  = m_axis_mm2s_tdata;
    assign read_keep = m_axis_mm2s_tkeep;
    assign read_valid = (state == SEND_DATA) ? m_axis_mm2s_tvalid : 1'b0;
    assign read_last  = (state == SEND_DATA) ? m_axis_mm2s_tlast  : 1'b0;
    assign m_axis_mm2s_tready = (state == SEND_DATA) ? read_ready : 1'b0;

    // DataMover 状态接口
    assign m_axis_mm2s_sts_tready = (state == WAIT_DONE) ? 1'b1 : 1'b0;


endmodule