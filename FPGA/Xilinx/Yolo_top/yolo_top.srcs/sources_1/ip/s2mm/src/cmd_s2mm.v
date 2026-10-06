module cmd_s2mm #(
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
    input                         write_cmd_valid,
    input [USER_ADDR_WIDTH-1 : 0] write_cmd_addr ,
    input [USER_LEN_WIDTH-1 : 0]  write_cmd_len  ,  // 字节数
    output                        write_cmd_ready,

    // 用户数据流接口
    input  [DATA_WIDTH-1:0]       write_data  ,
    input  [KEEP_WIDTH-1:0]       write_keep  ,
    input                         write_valid ,
    input                         write_last  ,
    output                        write_ready ,

    // DataMover 命令接口
    output  [40+ADDR_WIDTH-1 : 0]  s_axis_s2mm_cmd_tdata, 
    output                         s_axis_s2mm_cmd_tvalid,
    input                          s_axis_s2mm_cmd_tready,

    // DataMover stream 数据接口
    output [DATA_WIDTH-1:0]        s_axis_s2mm_tdata,
    output [KEEP_WIDTH-1:0]        s_axis_s2mm_tkeep,
    output                         s_axis_s2mm_tvalid,
    output                         s_axis_s2mm_tlast,
    input                          s_axis_s2mm_tready,

    // DataMover 状态接口
    input  [7:0]                   m_axis_s2mm_sts_tdata,
    input                          m_axis_s2mm_sts_tkeep,
    input                          m_axis_s2mm_sts_tlast,
    input                          m_axis_s2mm_sts_tvalid,
    output                         m_axis_s2mm_sts_tready
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
                if(write_cmd_valid && write_cmd_ready)
                    next_state = SEND_DATA;

            SEND_DATA:
                if(write_valid && write_last && write_ready)
                    next_state = WAIT_DONE;

            WAIT_DONE:          //STS通道判断
                if(m_axis_s2mm_sts_tvalid && m_axis_s2mm_sts_tready && m_axis_s2mm_sts_tdata == 8'b1000_0000)
                    next_state = IDLE;
        endcase
    end


    // Command 发送
    assign s_axis_s2mm_cmd_tvalid = write_cmd_valid && (state == IDLE);
    // 格式：{rsvd, tag, addr, drr, eof, dsa, type, btt}
    wire [22 : 0] btt = write_cmd_len[BTT_WIDTH-1 : 0];
    wire type = TYPE;                           //AXI INCR类型
    wire [5 : 0] dsa = 6'd0;
    wire eof = 1'b1;
    wire drr = 1'b0;
    wire [ADDR_WIDTH-1 : 0] addr = write_cmd_addr;
    wire [3 : 0] tag = 4'd0;
    wire [3 : 0] rsvd = 4'd0;
    assign s_axis_s2mm_cmd_tdata[40+ADDR_WIDTH-1 : 0] = {
                rsvd,
                tag,
                addr,
                drr,
                eof,
                dsa,
                type,
                btt
            };
    assign write_cmd_ready = (state == IDLE) ? s_axis_s2mm_cmd_tready : 1'b0;


    // DataMover stream 数据接口
    assign s_axis_s2mm_tdata  = write_data;
    assign s_axis_s2mm_tkeep  = write_keep;
    assign s_axis_s2mm_tvalid = (state == SEND_DATA) ? write_valid : 1'b0;
    assign s_axis_s2mm_tlast  = (state == SEND_DATA) ? write_last  : 1'b0;
    assign write_ready        = (state == SEND_DATA) ? s_axis_s2mm_tready : 1'b0;

    // DataMover 状态接口
    assign m_axis_s2mm_sts_tready = (state == WAIT_DONE) ? 1'b1 : 1'b0;


endmodule