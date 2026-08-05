module focus_in_buf #(
    parameter CHA_PAR_IN = 16,                          //输入通道并行度
              CHA_PAR_OUT = 16,                         //输入通道并行度
              CHA_IMG_IN = 3,                           //输入的IMG的最大通道数
              INT = 8,
              DATA_WIDTH = CHA_IMG_IN*4 * INT,          //数据传输位宽    输入并行度 * INT8
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
    input  [CHA_PAR_IN*INT-1 : 0]  s_data,
    input                          s_valid,
    input                          s_last,
    output                         s_ready,

    //下级模块接受数据
    input                          m_req,
    output [CHA_PAR_OUT*INT-1 : 0] m_data,
    output                         m_valid,
    output                         m_last
                                          
);




    //状态机
    localparam WRITE = 4'b0001, W_WAIT = 4'b0010, WAIT= 4'b0100, READ = 4'b1000;
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
                    next_state = W_WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            W_WAIT: begin
                if(w_double) begin
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
                if(m_last) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = READ;
                end
            end
            default:begin
                next_state = WRITE;
            end
        endcase
    end



    //写两行数据
    reg w_double;
    always @(posedge clk) begin
        if(rst) begin
           w_double <= 1'b0;
        end
        else if(state == W_WAIT) begin
            w_double <= !w_double;
        end
    end

    //写时序
    assign s_ready = (state == WRITE);

    wire wen = s_valid & s_ready;

    // reg w_ctl;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         w_ctl <= 1'b0;
    //     end
    //     else if(wen) begin
    //         w_ctl <= !w_ctl;
    //     end
    // end

    // wire wen_0 = wen & !w_ctl & !w_double;
    // wire wen_1 = wen & !w_ctl &  w_double;
    // wire wen_2 = wen &  w_ctl & !w_double;
    // wire wen_3 = wen &  w_ctl &  w_double;

    wire wen_0 = wen & !w_double;
    wire wen_1 = wen &  w_double;

    //
    wire [DATA_WIDTH- 1 : 0] wdata;
    assign wdata = {s_data[INT * (CHA_IMG_IN + 1) * 3 +: INT * CHA_IMG_IN], s_data[INT * (CHA_IMG_IN + 1) * 2 +: INT * CHA_IMG_IN], s_data[INT * (CHA_IMG_IN + 1) +: INT * CHA_IMG_IN], s_data[0 +: INT * CHA_IMG_IN]};


    //写地址
    reg [ADDR_WIDTH-1 : 0] waddr_0;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr_0 <= 0;
        end                                                                                                                                          
        else if(state == WRITE) begin
            if(wen_0) begin
                waddr_0 <= waddr_0 + 1;  
            end
        end
        else if(state == W_WAIT) begin
            waddr_0 <= 0;
        end                                   
    end
    //1
    reg [ADDR_WIDTH-1 : 0] waddr_1;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr_1 <= 0;
        end                                                                                                                                          
        else if(state == WRITE) begin
            if(wen_1) begin
                waddr_1 <= waddr_1 + 1;
            end
        end
        else if(state == W_WAIT) begin
            waddr_1 <= 0;
        end                                   
    end

    ////////////////////////////////////////////////////// 读时序  /////////////////////////////////////////////////////
    reg ren;
    always @(posedge clk) begin
        if(rst) begin
            ren <= 1'b0;
        end
        else if((state == WAIT) && (next_state == READ)) begin
            ren <= 1'b1;
        end
        else if((raddr == read_num - 1) & r_ctl) begin
            ren <= 1'b0;
        end
    end
    wire r_valid = ren;

    reg r_ctl;
    always @(posedge clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(ren) begin
            r_ctl <= !r_ctl;
        end
    end


    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            if(ren & r_ctl) begin               //每行读两次
                raddr <= raddr + 1'b1;
            end
        end
        else begin
            raddr <= 0;
        end                                   
    end


    reg r_last;                              
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if((raddr == read_num - 1) & !r_ctl) begin    //看文档这里对-2的解释
            r_last <= 1'b1;
        end
        else begin
            r_last <= 1'b0;
        end
    end

    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY-1 : 0] m_valid_d, m_last_d, r_ctl_d; 
    always @(posedge clk ) begin
        if(rst) begin
            m_valid_d <= 0;
            m_last_d <= 0;
            r_ctl_d <= 0;
        end
        else begin
            m_valid_d <= {m_valid_d[READ_DELAY-1 : 0], r_valid};
            m_last_d <= {m_last_d[READ_DELAY-1 : 0] , r_last};
            r_ctl_d <= {r_ctl_d[READ_DELAY-1 : 0] , r_ctl};
        end
    end

    //输出时序
    assign m_valid = m_valid_d[READ_DELAY-1];
    assign m_last = m_last_d[READ_DELAY-1];


    wire [DATA_WIDTH-1 : 0] rdata_0, rdata_1;
    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(DATA_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) sparm_inst_0
    (
        .clk   (clk   ),
        .wdata (wdata ),
        .wen   (wen_0   ),
        .waddr (waddr_0 ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (rdata_0 )
    );


    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(DATA_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) sparm_inst_1
    (
        .clk   (clk   ),
        .wdata (wdata ),
        .wen   (wen_1   ),
        .waddr (waddr_1 ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (rdata_1 )
    );

    wire [CHA_PAR_OUT*INT-1 : 0] m_data_0, m_data_1;
    assign m_data_0 = {{(CHA_PAR_OUT*INT - CHA_IMG_IN*4*INT){1'b0}}, rdata_1[CHA_IMG_IN * INT +: CHA_IMG_IN*INT], rdata_0[CHA_IMG_IN * INT +: CHA_IMG_IN*INT], rdata_1[0 +: CHA_IMG_IN*INT],                rdata_0[0 +: CHA_IMG_IN*INT]};
    assign m_data_1 = {{(CHA_PAR_OUT*INT - CHA_IMG_IN*4*INT){1'b0}}, rdata_1[CHA_IMG_IN*3*INT +: CHA_IMG_IN*INT], rdata_0[CHA_IMG_IN*3*INT +: CHA_IMG_IN*INT], rdata_1[CHA_IMG_IN*2*INT +: CHA_IMG_IN*INT], rdata_0[CHA_IMG_IN*2*INT +: CHA_IMG_IN*INT]};


    assign m_data = r_ctl_d[READ_DELAY-1] ? m_data_1 : m_data_0;

endmodule