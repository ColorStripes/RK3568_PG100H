module upsample_in_buf_ctrl #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_IN = 16,              //输入通道并行度
              INT = 8,                        //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT,  //数据传输位宽    并行度 * INT8
              MAX_IN_LEN = 5120,            //此模块所接受的最大字节数  也就是一行*通道的字节数
              LEN_WIDTH = $clog2(MAX_IN_LEN),
              MAX_IN_ROW = 640,             //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW)
              
)
(
    input          clk              ,
    input          rst              ,

    input          start         ,//起始信号
    input  [AXI_DATA_WIDTH-1 : 0]   base_addr          ,//读取内存的起始基地址
    input  [LEN_WIDTH : 0]          in_col_channel_num ,//这是需要读取一行的总字节数 col_num = col * channel
    input  [ROW_WIDTH : 0]          row_num            ,//最大的行数  （多留一位是因为计数器会访问数值而没有-1）

    input  [DATA_WIDTH-1 : 0]   s_data        ,//接受数据
    input                       s_valid       ,
    input                       s_last        ,
    output                      s_ready       ,


    input                       m_req         ,//向下级传输数据
    output [DATA_WIDTH-1 : 0]   m_data        ,
    output                      m_valid       ,
    output                      m_last        ,



    output [DATA_WIDTH-1 : 0]   ping_s_data   ,//ping数据
    output                      ping_s_valid  ,
    output                      ping_s_last   ,
    input                       ping_s_ready  ,

    output                      ping_m_req    ,
    input  [DATA_WIDTH-1 : 0]   ping_m_data ,
    input                       ping_m_valid  ,
    input                       ping_m_last   ,


    output [DATA_WIDTH-1 : 0]   pang_s_data   ,//pang数据
    output                      pang_s_valid  ,
    output                      pang_s_last   ,
    input                       pang_s_ready  ,


    output                      pang_m_req    ,
    input  [DATA_WIDTH-1 : 0]   pang_m_data   ,
    input                       pang_m_valid  ,
    input                       pang_m_last   ,



    output  [AXI_ADDR_WIDTH-1 : 0]    cmd_addr      ,//指令数据
    output  [AXI_DATA_WIDTH-1 : 0]    cmd_len       ,
    output                            cmd_valid     ,
    input                             cmd_ready      
);

    //状态机
    localparam IDLE = 4'b0001, WADDR = 4'b0010, WDATA = 4'b0100, WAIT = 4'b1000;
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
            IDLE:begin
                if(start) begin
                    next_state = WADDR;
                end
                else begin
                    next_state = IDLE;
                end
            end
            WADDR:begin                                     //告诉DMA从哪里读  W代表写给DMA
                if(cmd_valid & cmd_ready) begin
                    next_state = WDATA;
                end
                else begin
                    next_state = WADDR;
                end
            end
            WDATA:begin                                     //从DMA里读数据出来写入当前模块
                if(s_valid & s_ready & s_last) begin
                    next_state = WAIT;
                end
                else begin
                    next_state = WDATA;
                end
            end
            WAIT:begin
                if(row_cnt == row_num) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = WADDR;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end


    //行控制
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            row_cnt <= 0;
        end
        else if(state == IDLE) begin
            row_cnt <= 0;
        end
        else if((state == WDATA) && (next_state == WAIT)) begin
            row_cnt <= row_cnt + 1;
        end
    end



    //内存读取地址更改
    reg [31 : 0] data_addr;
    always @(posedge clk) begin
        if(start) begin
            data_addr <= base_addr;
        end
        else if(cmd_valid & cmd_ready) begin
            data_addr <= data_addr + in_col_channel_num;
        end
    end
    assign cmd_addr = data_addr;


    reg cmd_valid_r;
    always @(posedge clk ) begin
        if(rst) begin
            cmd_valid_r <= 1'b0;
        end
        else if(s_ready && (next_state == WADDR)) begin
            cmd_valid_r <= 1'b1;
        end
        else if(cmd_valid & cmd_ready) begin
            cmd_valid_r <= 1'b0;
        end    
    end
    assign cmd_valid = cmd_valid_r;

    reg [LEN_WIDTH : 0] cmd_len_r;
    always @(posedge clk ) begin
        if(start) begin
            cmd_len_r <= in_col_channel_num;
        end
    end
    assign cmd_len = cmd_len_r;
 


    //乒乓控制器  写
    reg w_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if((state == WDATA) && (next_state == WAIT)) begin
            w_ctl <= !w_ctl; 
        end
    end

    assign ping_s_data  = (w_ctl == 1'b0) ? s_data : 0;
    assign ping_s_valid = (w_ctl == 1'b0) ? s_valid : 1'b0;
    assign ping_s_last  = (w_ctl == 1'b0) ? s_last  : 1'b0;

    assign pang_s_data  = (w_ctl == 1'b1) ? s_data : 0;
    assign pang_s_valid = (w_ctl == 1'b1) ? s_valid : 1'b0;
    assign pang_s_last  = (w_ctl == 1'b1) ? s_last  : 1'b0;

    assign s_ready = (w_ctl == 1'b1) ? pang_s_ready : ping_s_ready;



    //乒乓控制器  读
    reg r_ctl;
    always @(posedge clk ) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(m_last & m_valid & double_row) begin
            r_ctl <= !r_ctl;
        end
    end

    //行倍增
    reg double_row;
    always @(posedge clk) begin
        if(rst) begin
            double_row <= 1'b0;
        end
        else if(m_last & m_valid) begin
            double_row <= ~double_row;
        end
    end

    assign ping_m_req = (r_ctl == 1'b0) ? m_req : 1'b0;
    assign pang_m_req = (r_ctl == 1'b1) ? m_req : 1'b0;

    assign m_valid = (r_ctl == 1'b0) ? ping_m_valid : pang_m_valid;
    assign m_last  = (r_ctl == 1'b0) ? ping_m_last  : pang_m_last ;
    assign m_data  = (r_ctl == 1'b0) ? ping_m_data : pang_m_data;




endmodule