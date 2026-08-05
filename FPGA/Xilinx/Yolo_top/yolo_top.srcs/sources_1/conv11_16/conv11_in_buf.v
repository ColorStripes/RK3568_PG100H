module conv11_in_buf #(
    parameter CHA_PAR_IN = 16,                          //输入通道并行度
              INT = 8,
              DATA_WIDTH = CHA_PAR_IN * INT,            //数据传输位宽    输入并行度 * INT8
              DATA_DEPTH = 512,                         //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
              ADDR_WIDTH = $clog2(DATA_DEPTH),          //地址位宽
              READ_DELAY = 2                            //读出数据所需要的延迟
              
)
(
    input          clk,
    input          rst,

    //一次读取并行度个字节数 需要读取多少次才能把一行数据读完 read_num = col * channel / CHA_PAR_IN
    input  [ADDR_WIDTH : 0]   read_num, 

    //当前模块接受数据
    input  [DATA_WIDTH-1 : 0]   s_data,
    input                       s_valid,
    input                       s_last,
    output                      s_ready,

    //下级模块接受数据
    input                       m_req,
    output [DATA_WIDTH-1 : 0]   m_data,
    output                      m_valid,
    output                      m_last
                                          
);


    reg [ADDR_WIDTH-1 : 0] waddr;
    reg [ADDR_WIDTH-1 : 0] raddr;
    reg r_last; 

    //状态机
    localparam WRITE = 4'b0001, WAIT = 4'b0010, READ = 4'b0100, LAST = 4'b1000;
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
            WRITE:begin
                if(s_valid & s_last) begin
                    next_state = WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            WAIT:begin
                if(m_req) begin
                    next_state = READ;
                end
                else begin
                    next_state = WAIT;
                end
            end
            READ:begin
                if(r_last) begin
                    next_state = LAST;
                end
                else begin
                    next_state = READ;
                end
            end
            LAST:begin
                if(m_last) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = LAST;
                end
            end
            default:begin
                next_state = WRITE;
            end
        endcase
    end

    //写时序
    assign s_ready = (state == WRITE);
    wire wen = s_valid & s_ready;
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

    //读时序                                     
    wire ren = (state == READ);
    wire r_valid = ren;
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
                                 
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if(raddr == read_num - 2) begin    //看文档这里对-2的解释
            r_last <= 1'b1;
        end
        else begin
            r_last <= 1'b0;
        end
    end

    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY-1 : 0] m_valid_d, m_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            m_valid_d <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d  <= {m_valid_d[READ_DELAY-1 : 0] , r_valid};
            m_last_d <= {m_last_d[READ_DELAY-1 : 0] , r_last};
        end
    end

    //输出时序
    assign m_valid = m_valid_d[READ_DELAY-1];
    assign m_last = m_last_d[READ_DELAY-1];

    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(DATA_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) spram_inst
    (
        .clk   (clk   ),
        .wdata (s_data ),
        .wen   (wen   ),
        .waddr (waddr ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (m_data )
    );

endmodule