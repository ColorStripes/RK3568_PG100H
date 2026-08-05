module conv_out_buf #(
    parameter CHA_PAR_OUT = 8,                          //输出通道并行度
              CHA_IMG_OUT = 128,                        //图片输出最大通道数
              MAX_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),   //计算次数
              CALULATE_CNT_WIDTH = $clog2(MAX_CALULATE_NUM),
              INT = 8,                                  //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT,           //数据传输位宽    输出并行度 * INT8
              DATA_DEPTH = 5120,                        //数据深度  这里是 W*channal/并行度  RAM总容量应该大于一行数据所需字节个数
              ADDR_WIDTH = $clog2(DATA_DEPTH),          //地址位宽
              READ_DELAY = 1                            //读出数据所需要的延迟
)
(
    input          clk,
    input          rst,

    input          start,
    input [CALULATE_CNT_WIDTH : 0]  calculate_cout_num,      //输出计算次数 

    //当前模块接受数据
    //CHA_PAR_OUT个输出
    input [DATA_WIDTH-1 : 0]    s_data ,
    input                       s_valid,
    input                       s_last ,
    output                      s_req,                  //req是有数进就拉低请求的是一行 ready是有数进 请求的是一个 进到最后一个才拉低              


    //下级模块接受数据
    output [DATA_WIDTH-1 : 0]   m_data ,
    output                      m_last ,
    output                      m_valid,
    input                       m_req                   //这里是m_req 因为是下级FIFO请求

);


    reg [ADDR_WIDTH-1 : 0] waddr;
    reg [ADDR_WIDTH-1 : 0] raddr;
    reg r_last;


    //开始计算
    reg [CALULATE_CNT_WIDTH : 0]  calculate_cout_num_r;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cout_num_r <= 0;
        end
        else if(start) begin
            calculate_cout_num_r <= calculate_cout_num;
        end
    end

    //状态机
    localparam IDLE = 5'b00001, WRITE = 5'b00010, W_WAIT = 5'b00100, R_WAIT = 5'b01000, READ = 5'b10000;
    reg [4 : 0] state, next_state;
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
                next_state = WRITE;
            end
            WRITE:begin
                if(s_last & s_valid) begin
                    next_state = W_WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            W_WAIT:begin
                if(calculate_cnt == calculate_cout_num_r) begin
                    next_state = R_WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            R_WAIT:begin
                if(m_req) begin
                    next_state = READ;
                end
                else begin
                    next_state = R_WAIT;
                end
            end
            READ:begin
                if(m_valid & m_last) begin
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

    //计算计数器(和row_cnt一样 下周期拉高 下周期判断)
    reg [CALULATE_CNT_WIDTH : 0] calculate_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cnt <= 7'd0;
        end
        else if(state == READ) begin
            calculate_cnt <= 7'd0;
        end
        else if(s_last & s_valid) begin
            calculate_cnt <= calculate_cnt + 7'd1;    //成功输出前并行度个通道数的一行
        end 
    end




    //写时序
    wire wen = s_valid;                         //只要有效即写 因为我默认接受一行数据
    //wire [DATA_WIDTH-1 : 0] wdata = {s_data_7, s_data_6, s_data_5, s_data_4, s_data_3, s_data_2, s_data_1, s_data_0};
    wire [DATA_WIDTH-1 : 0] wdata = s_data;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            waddr <= 0;
        end
        else if(state == WRITE) begin
            if(wen) begin
                waddr <= waddr + calculate_cout_num_r;         //排列方式重组 前并行通道 后并行通道
            end
        end
        else begin
            waddr <= calculate_cnt;
        end                                  
    end
    

    //读写计数器
    reg [ADDR_WIDTH-1 : 0] w_r_cnt;
    always @(posedge clk) begin
        if(rst) begin
            w_r_cnt <= 0;
        end
        else if(wen) begin
            w_r_cnt <= w_r_cnt + 1;
        end
        else if(ren) begin
            w_r_cnt <= w_r_cnt - 1;
        end
    end

    //向上级请求数据
    reg s_req_r;
    always @(posedge clk ) begin
        if(rst) begin
            s_req_r <= 1'b0;
        end
        else if((state != WRITE) && (next_state == WRITE)) begin
            s_req_r <= 1'b1;
        end
        else if(s_valid) begin                                          //有数进来就拉低
            s_req_r <= 1'b0; 
        end
    end
    assign s_req = s_req_r;

    //读时序                                     
    wire ren = (w_r_cnt > 0) && (state == READ);
    wire r_valid = ren;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            if(ren) begin
                raddr <= raddr + 1'b1;
            end
        end
        else begin
            raddr <= 0;
        end                                   
    end

                                
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if((w_r_cnt == 2) & ren) begin
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
            m_valid_d  <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d <= {m_valid_d[READ_DELAY-1 : 0], r_valid};
            m_last_d  <= {m_last_d[READ_DELAY-1 : 0], r_last};
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
        .wdata (wdata ),
        .wen   (wen   ),
        .waddr (waddr ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (m_data)
    );




endmodule