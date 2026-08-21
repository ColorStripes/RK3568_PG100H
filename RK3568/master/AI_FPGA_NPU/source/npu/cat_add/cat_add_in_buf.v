module cat_add_in_buf #(
    parameter CHA_PAR_IN = 16,                          //输入通道并行度
                            //图片通道//
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),          //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),   


              INT = 8,
              DATA_WIDTH = CHA_PAR_IN * INT,            //数据传输位宽    输入并行度 * INT8
              DATA_DEPTH = 160,                         //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
              ADDR_WIDTH = $clog2(DATA_DEPTH),          //地址位宽
              READ_DELAY = 2                            //读出数据所需要的延迟
              
)
(
    input          clk,
    input          rst,

    input          type,    //type 1 is cat; 0 is add

    //一次读取并行度个字节数 需要读取多少次才能把一行数据读完 read_num = col * channel / CHA_PAR_IN
    input  [ADDR_WIDTH : 0]   read_num, 
    //输入通道计算次数
    input  [IN_CALULATE_CNT_WIDTH : 0] calculate_cin_num,

    //当前模块接受数据
    input  [DATA_WIDTH-1 : 0]   s_data_0,
    input                       s_valid_0,
    input                       s_last_0,
    output                      s_ready_0,

    input  [DATA_WIDTH-1 : 0]   s_data_1,
    input                       s_valid_1,
    input                       s_last_1,
    output                      s_ready_1,

    output                      s_end,

    //下级模块接受数据
    input                       m_req,
    output [DATA_WIDTH-1 : 0]   m_data_0,
    output [DATA_WIDTH-1 : 0]   m_data_1,
    output                      m_valid_0,
    output                      m_valid_1,
    output                      m_last
                                          
);


    //状态机
    localparam IDLE = 4'b0001, WRITE = 4'b0010, WAIT = 4'b0100, READ = 4'b1000;
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
            IDLE: begin
                next_state = WRITE;
            end
            // WRITE_0:begin
            //     if((s_valid_0 & s_ready_0 & s_last_0) & (s_valid_1 & s_ready_1 & s_last_1)) begin
            //         next_state = WAIT;
            //     end
            //     else if((s_valid_0 & s_ready_0 & s_last_0) | (s_valid_1 & s_ready_1 & s_last_1)) begin
            //         next_state = WRITE_1;
            //     end
            //     else begin
            //         next_state = WRITE_0;
            //     end
            // end
            WRITE:begin
                if((s_valid_0 & s_ready_0 & s_last_0) & (s_valid_1 & s_ready_1 & s_last_1)) begin
                    next_state = WAIT;
                end
                else if(((s_valid_0 & s_ready_0 & s_last_0) | (s_valid_1 & s_ready_1 & s_last_1)) & s_flag) begin
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
                    next_state = IDLE;
                end
                else begin
                    next_state = READ;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end



    /////////////////////////////////计算相关/////////////////////////////////
    //输入计算次数
    reg [IN_CALULATE_CNT_WIDTH : 0] calculate_cin_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cin_cnt <= 0;
        end
        else if(ren) begin
            if(calculate_cin_cnt == (calculate_cin_num - 1))begin
                calculate_cin_cnt <= 0;
            end
            else begin
                calculate_cin_cnt <= calculate_cin_cnt + 1'b1;
            end
        end
        else begin
            calculate_cin_cnt <= 0;
        end
    end

    /////////////////////////////////////////////////////////////////////写时序////////////////////////////////////////////////////////////////
    //写时序 0 
    wire wen_0 = s_valid_0 & s_ready_0;

    reg [ADDR_WIDTH-1 : 0] waddr_0;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr_0 <= 0;
        end                                                                                                                                          
        else if(state == IDLE) begin
            waddr_0 <= 0;
        end
        else if(wen_0) begin
            waddr_0 <= waddr_0 + 1'b1;
        end                                   
    end

    reg s_ready_0_r;
    always @(posedge clk) begin
        if(rst) begin
            s_ready_0_r <= 1'b0;
        end
        else if((state == IDLE) && (next_state == WRITE)) begin
            s_ready_0_r <= 1'b1;
        end
        else if(s_valid_0 & s_ready_0 & s_last_0) begin
            s_ready_0_r <= 1'b0;
        end
    end
    assign s_ready_0 = s_ready_0_r;

    //写时序 1 
    wire wen_1 = s_valid_1 & s_ready_1;

    reg [ADDR_WIDTH-1 : 0] waddr_1;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr_1 <= 0;
        end                                                                                                                                          
        else if(state == IDLE) begin
            waddr_1 <= 0;
        end
        else if(wen_1) begin
            waddr_1 <= waddr_1 + 1'b1;
        end                                   
    end

    reg s_ready_1_r;
    always @(posedge clk) begin
        if(rst) begin
            s_ready_1_r <= 1'b0;
        end
        else if((state == IDLE) && (next_state == WRITE)) begin
            s_ready_1_r <= 1'b1;
        end
        else if(s_valid_1 & s_ready_1 & s_last_1) begin
            s_ready_1_r <= 1'b0;
        end
    end
    assign s_ready_1 = s_ready_1_r;

    reg s_flag;     //指示一组信号完成传输
    always @(posedge clk) begin
        if(rst) begin
            s_flag <= 1'b0;
        end
        else if((state == WRITE) && (next_state == WAIT)) begin
            s_flag <= 1'b0;
        end
        else if((s_valid_0 & s_ready_0 & s_last_0) | (s_valid_1 & s_ready_1 & s_last_1)) begin
            s_flag <= 1'b1;
        end
    end
                
    // reg s_end_r;    //指示两组信号已经接受完毕
    // always @(posedge clk) begin
    //     if(rst) begin
    //         s_end_r <= 1'b0;
    //     end
    //     else if((state == WRITE) && (next_state == WAIT)) begin
    //         s_end_r <= 1'b1;
    //     end
    //     else begin
    //         s_end_r <= 1'b0;
    //     end
    // end
    // assign s_end = s_end_r;
    assign s_end = (state == WRITE) && (next_state == WAIT);


   /////////////////////////////////////////////////////////////////////读时序////////////////////////////////////////////////////////////////
    //读时序                                     
    reg ren;
    always @(posedge clk) begin
        if(rst) begin
            ren <= 1'b0;
        end
        else if((state == WAIT) && (next_state == READ)) begin
            ren <= 1'b1;
        end
        else if((raddr_1 == read_num - 1) && ren_1) begin
            ren <= 1'b0;
        end
    end
    
    //乒乓时序
    wire ren_0, ren_1;
    reg ren_ctl;
    always @(posedge clk) begin
        if(rst) begin
            ren_ctl <= 1'b0;
        end
        else if(state == READ) begin
            if(calculate_cin_cnt == (calculate_cin_num - 1)) begin
                ren_ctl <= !ren_ctl;
            end
        end
        else begin
            ren_ctl <= 1'b0;
        end
    end
    assign ren_0 = type ? (ren & !ren_ctl) : ren;
    assign ren_1 = type ? (ren &  ren_ctl) : ren;

    reg [ADDR_WIDTH-1 : 0] raddr_0, raddr_1;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr_0 <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            if(ren_0) begin
                raddr_0 <= raddr_0 + 1'b1;
            end
        end
        else begin
            raddr_0 <= 0;
        end                                   
    end
    //1
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr_1 <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            if(ren_1) begin
                raddr_1 <= raddr_1 + 1'b1;
            end
        end
        else begin
            raddr_1 <= 0;
        end                                   
    end

    wire r_valid_0 = ren_0;
    wire r_valid_1 = ren_1;

    // reg r_last;                         
    // always @(posedge clk) begin
    //     if(rst) begin
    //         r_last <= 1'b0;
    //     end
    //     else if(raddr_1 == read_num - 2 + READ_DELAY) begin    //看文档这里对-2的解释
    //         r_last <= 1'b1;
    //     end
    //     else begin
    //         r_last <= 1'b0;
    //     end
    // end

    wire r_last = (raddr_1 == read_num - 1) && ren_1;

    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY-1 : 0] m_valid_d_0, m_valid_d_1, m_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            m_valid_d_0 <= 0;
            m_valid_d_1 <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d_0  <= {m_valid_d_0[READ_DELAY-1 : 0] , r_valid_0};
            m_valid_d_1  <= {m_valid_d_1[READ_DELAY-1 : 0] , r_valid_1};
            m_last_d <= {m_last_d[READ_DELAY-1 : 0] , r_last};
        end
    end

    //输出时序
    assign m_valid_0 = m_valid_d_0[READ_DELAY-1];
    assign m_valid_1 = m_valid_d_1[READ_DELAY-1];
    assign m_last = m_last_d[READ_DELAY-1];


    wire [DATA_WIDTH-1 : 0]  r_data_0, r_data_1;
    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(DATA_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) sparm_inst_0
    (
        .clk   (clk   ),
        .wdata (s_data_0 ),
        .wen   (wen_0   ),
        .waddr (waddr_0 ),
        .ren   (ren_0   ),
        .raddr (raddr_0 ),
        .rdata (r_data_0 )
    );


    spram #(.DP(DATA_DEPTH),    //存储单元深度
            .DW(DATA_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) sparm_inst_1
    (
        .clk   (clk   ),
        .wdata (s_data_1 ),
        .wen   (wen_1   ),
        .waddr (waddr_1 ),
        .ren   (ren_1   ),
        .raddr (raddr_1 ),
        .rdata (r_data_1 )
    );

    
    assign m_data_0 = r_data_0;
    assign m_data_1 = r_data_1;

endmodule