module conv11_in_ctrl #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              MAX_IN_COL = 320,                          //输入的IMG的最大列数
              COL_WIDTH = $clog2(MAX_IN_COL),
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              CHA_IMG_OUT = 256,                         //输出的IMG的最大通道数
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),          //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),       //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              MAX_IN_LEN = 5120,                         //此模块所接受的最大字节数  也就是一行*所有通道的字节数
              DATA_DEPTH = MAX_IN_LEN / CHA_PAR_IN,      //数据深度  这里是 W*channal/输入并行度  RAM总容量应该大于一行数据所需字节个数
              READ_DELAY = 1
)
(
    input          clk             ,
    input          rst             ,

    input          start           ,

    input  [INT-1 : 0]                   zero_1                ,
    input  [COL_WIDTH : 0]               col_num               ,   //col_num = col
    input  [ROW_WIDTH : 0]               row_num               ,
    input  [IN_CALULATE_CNT_WIDTH : 0]   calculate_cin_num     ,
    input  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num    ,
    
    input  [DATA_WIDTH-1 : 0] s_data     ,  //当前模块的接受
    input                     s_valid    ,
    input                     s_last     ,
    output                    s_req      ,

    output [DATA_WIDTH-1 : 0] m_data_1        ,
    output                    m_valid         ,
    output                    m_last          ,
    input                     m_req            
);




    //状态机
    localparam IDLE = 6'b000001, W_FIRST = 6'b000010, R_FIRST = 6'b000100, W_CENTER = 6'b001000, R_CENTER = 6'b010000, R_LAST = 6'b100000;
    reg [5 : 0] state, next_state;
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
                    next_state = W_FIRST;
                end
                else begin
                    next_state = IDLE;
                end
            end
            W_FIRST:begin                                       //从上级写入第一行
                if((w_ram_cnt == 1) && s_last) begin
                    next_state = R_FIRST;
                end
                else begin
                    next_state = W_FIRST;
                end
            end
            R_FIRST:begin                                       //读出第一行数据
                if((calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last) begin
                    next_state = W_CENTER;
                end
                else begin
                    next_state = R_FIRST;
                end
            end
            W_CENTER:begin
                if(wr_cnt >= 2) begin
                    next_state = R_CENTER;
                end
                else begin
                    next_state = W_CENTER;
                end
            end
            R_CENTER:begin
                if((calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last) begin
                    if(row_cnt == (row_num - 1)) begin    //在执行最后一行的上一行后  状态要转移到最后一行
                        next_state = R_LAST;    
                    end
                    else begin
                        next_state = W_CENTER;
                    end
                end
                else begin
                    next_state = R_CENTER;
                end
            end
            R_LAST:begin            //最后一行  不算padding  是图像实际的最后一行
                if((calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = R_LAST;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end



////////////////////////////////////////////特殊信号////////////////////////////////////////////////
    // //非对称量化的0 在Padding和行不够组时补0
    // reg [INT-1 : 0] zero_img;
    // always @(posedge clk) begin
    //     if(start) begin
    //         zero_img = zero_1;
    //     end
    // end





////////////////////////////////////////////行列相关////////////////////////////////////////////////
    ///////对于列来说 padding的操作是用col_num_r 和 col_cnt 计数
    //列计数器
    reg [COL_WIDTH : 0] col_num_r;
    always @(posedge clk) begin
        if(rst) begin
            col_num_r <= 0;
        end
        else if(start) begin
            col_num_r <= col_num + 2 - 1;         //加了2个  也就是多了2个列 是padding的两个 左右各一个   -1是因为计数从0开始
        end
    end
    //对应计数器
    reg [COL_WIDTH : 0] col_cnt;
    always @(posedge clk) begin
        if(rst) begin
            col_cnt <= 0;                         //列数从（0 --- 行数-1）计数   是从0开始
        end
        else if(m_ready) begin
            col_cnt <= col_cnt + 1'b1;
        end
        else begin
            col_cnt <= 0;
        end
    end



    ///////对于行来说 padding的操作是用两个特殊状态 FIRST 和 LAST来控制
    //行计数器
    // reg [ROW_WIDTH : 0] row_num_r;
    // always @(posedge clk ) begin
    //     if(rst) begin
    //         row_num_r <= 0;
    //     end
    //     else if(start) begin
    //         row_num_r <= row_num;    
    //     end
    // end
    //对应计数器
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk) begin
        if(rst) begin
            row_cnt <= 1;                           //行数从（1-行数）计数   并不是从0开始
        end
        else if(state == IDLE) begin
            row_cnt <= 1;
        end
        else if((calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last) begin
            row_cnt <= row_cnt + 1;
        end
    end



    //读写动态行数计数器(存在读写同时进行)  表示现在有几行可以操作
    reg [RAM_CNT_WIDTH-1 : 0] wr_cnt;
    always @(posedge clk) begin
        if(rst) begin
            wr_cnt <= 3'd1;
        end
        else if(state == IDLE) begin
            wr_cnt <= 3'd1;
        end
        else begin  
            //写入的ram写完了 读还没读完 
            if( s_last && (!((calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last)) ) begin
                wr_cnt <= wr_cnt + 3'd1;
            end
            //读出的ram写完了 写还没写完 
            else if( !s_last && ( (calculate_cin_cnt == calculate_cin_num_r) && (calculate_cout_cnt == calculate_cout_num_r) && m_last ) ) begin
                wr_cnt <= wr_cnt - 3'd1;
            end    
        end
    end


//////////////////////////////////////////计算信号相关///////////////////////////////////////////////
    // localparam  MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),          //输入通道计算次数=输入通道数/输入并行度 
    //             IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
    //             MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),       //输出通道计算次数=输出通道数/输出并行度 
    //             OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM);


    //输入通道计算次数
    reg [IN_CALULATE_CNT_WIDTH-1 : 0] calculate_cin_num_r;
    always @(posedge clk) begin
        calculate_cin_num_r <= calculate_cin_num - 1; 
    end
    //输入对应计数器
    reg [IN_CALULATE_CNT_WIDTH-1 : 0] calculate_cin_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cin_cnt <= 0;
        end
        else if( |(state & 6'b110100) ) begin     //(state == R_FIRST) || (state == R_CENTER) || (state == R_LAST)
            if(m_last) begin
                if(calculate_cin_cnt == calculate_cin_num_r) begin
                    calculate_cin_cnt <= 0;
                end
                else begin
                    calculate_cin_cnt <= calculate_cin_cnt + 1;
                end
            end
        end
        else begin
            calculate_cin_cnt <= 0;
        end
    end


    //输出通道计算次数
    reg [OUT_CALULATE_CNT_WIDTH-1 : 0] calculate_cout_num_r;
    always @(posedge clk) begin
        calculate_cout_num_r <= calculate_cout_num - 1; 
    end
    //输出对应计数器
    reg [OUT_CALULATE_CNT_WIDTH-1 : 0] calculate_cout_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cout_cnt <= 0;
        end
        else if((calculate_cin_cnt == calculate_cin_num_r) && m_last)begin
            if(calculate_cout_cnt == calculate_cout_num_r) begin
                calculate_cout_cnt <= 0;
            end
            else begin
                calculate_cout_cnt <= calculate_cout_cnt + 1;
            end
        end
    end



/////////////////////////////////////////从上级写入当前模块/////////////////////////////////////////
    //写RAM循环计数器
    localparam RAM_CNT = 3,
               RAM_CNT_WIDTH = $clog2(RAM_CNT+1);
    reg [RAM_CNT_WIDTH-1 : 0] w_ram_cnt;
    always @(posedge clk) begin
        if(rst) begin
            w_ram_cnt <= {RAM_CNT_WIDTH{1'b0}};
        end
        else if(state == IDLE) begin
            w_ram_cnt <= {{(RAM_CNT_WIDTH-1){1'b0}}, 1'b1};
        end
        else if(s_last) begin
            if(w_ram_cnt == (RAM_CNT-1)) begin
                w_ram_cnt <= {RAM_CNT_WIDTH{1'b0}};
            end
            else begin
                w_ram_cnt <= w_ram_cnt + 1'b1;
            end
        end
    end

    //写使能
    reg wen_all;
    always @(posedge clk) begin
        if(rst) begin
            wen_all <= 1'b0;
        end
        else begin
            wen_all <= s_valid;
        end
    end

    //写使能(全部RAM)
    reg [RAM_CNT-1 : 0] wen;
    generate
    for(genvar i = 0; i < RAM_CNT; i = i + 1) begin : gen_wen_seq
        always @(posedge clk) begin
            if(rst) begin
                wen[i] <= 1'b0;
            end 
            else begin
                wen[i] <= (w_ram_cnt == i) ? s_valid : 1'b0;
            end
        end
    end
    endgenerate


    //写地址
    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);
    reg [ADDR_WIDTH-1 : 0] waddr;
    always @(posedge clk) begin
        if(rst) begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(wen_all) begin
            waddr <= waddr + 1'b1;
        end
        else begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
    end


    //写数据
    reg [DATA_WIDTH-1 : 0] wdata;
    always @(posedge clk) begin
        wdata <= s_data;
    end

    //向上级请求数据
    reg s_req_r;
    always @(posedge clk) begin
        if(rst) begin
            s_req_r <= 1'b0;
        end
        else if(s_valid) begin   //有数进来就拉低
            s_req_r <= 1'b0;
        end
        else if(wr_cnt <= (RAM_CNT-1)) begin      //存储器未满状态请求
            s_req_r <= 1'b1; 
        end
    end
    assign s_req = s_req_r;



/////////////////////////////////////////从当前模块读出到下级/////////////////////////////////////////
    //读RAM循环计数器  （与w_ram_cnt有本质不同）
    //每个RAM存的是一行数，每相邻3个RAM位一组即相邻三行数，这里生成组号 （组号的个数与RAM个数相同）
    reg [RAM_CNT_WIDTH-1 : 0] r_ram_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            r_ram_cnt <= 0;
        end
        else if(state == IDLE) begin
            r_ram_cnt <= 0;
        end
        else if( ((state == W_CENTER) && (next_state == R_CENTER)) || ((state == R_CENTER) && (next_state == R_LAST)) ) begin 
            if(r_ram_cnt == (RAM_CNT-1)) begin
                r_ram_cnt <= 0;  
            end
            else begin
                r_ram_cnt <= r_ram_cnt + 1;   //步长为1  组号每次+1
            end
        end
    end



    //读地址
    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk) begin
        if(rst) begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(ren_all) begin
            raddr <= raddr + (calculate_cin_num_r + 1);
        end
        else begin
            raddr <= calculate_cin_cnt;
        end
    end


    //读使能(全部RAM)
    wire ren_all = (col_cnt > 0) && (col_cnt < col_num_r);
    wire [RAM_CNT-1 : 0] ren;
    generate
        for(genvar i = 0; i < RAM_CNT; i = i + 1) begin
            if(i == 0) begin
                assign ren[0] = (r_ram_cnt == RAM_CNT-2) || (r_ram_cnt == RAM_CNT-1) || (r_ram_cnt == 0) ? ren_all : 1'b0;
            end
            else if(i == 1) begin
                assign ren[1] = (r_ram_cnt == RAM_CNT-1) || (r_ram_cnt == 0) || (r_ram_cnt == 1) ? ren_all : 1'b0;
            end
            else begin
                assign ren[i] = (r_ram_cnt == (i[RAM_CNT_WIDTH-1 : 0] - 2)) || (r_ram_cnt == (i[RAM_CNT_WIDTH-1 : 0] - 1)) || (r_ram_cnt == i[RAM_CNT_WIDTH-1 : 0]) ? ren_all : 1'b0;
            end
        end
    endgenerate



    //向下级输出数据 
    reg [DATA_WIDTH-1 : 0] m_data_1_r;
    always @(*) begin
        if((col_cnt_d[READ_DELAY-1] == 0) || (col_cnt_d[READ_DELAY-1] == col_num_r)) begin   //列第一个 和 最后一个 padding操作
            m_data_1_r = {CHA_PAR_IN{zero_1}};
        end
        else if(r_ram_cnt == (RAM_CNT-1)) begin
            m_data_1_r = rdata[0];
        end      
        else begin
            m_data_1_r = rdata[r_ram_cnt + 1];
        end
    end

    assign m_data_1 = m_data_1_r;





    //RAM生成
    wire [DATA_WIDTH-1 : 0] rdata [RAM_CNT-1 : 0];
    generate
        for(genvar i = 0; i < RAM_CNT; i = i + 1) begin
            spram #(.DP(DATA_DEPTH),    
                    .DW(DATA_WIDTH),    
                    .PIPE(READ_DELAY)  
            ) 
            ram(
                .clk   (clk   ),
                .wdata (wdata ),      // ? 改为打拍后的数据
                .wen   (wen[i]),      // ? 改为打拍后的写使能
                .waddr (waddr ),      // ? 改为打拍后的地址
                .ren   (ren[i]),
                .raddr (raddr ),
                .rdata (rdata[i])
            );
        end
    endgenerate



    //m_req变m_ready
    reg m_ready;                         
    always @(posedge clk) begin
        if(rst) begin
            m_ready <= 1'b0;
        end
        else if( |(next_state & 6'b110100) ) begin     //提前了一个周期 完全是因为在判断col_cnt == col_num_r的时候 因为READ_DELAY的原因 next_state仍然符合判断的状态
            if(m_req) begin                            //如果没有sparm的读延迟 那么这个判断只能是  |(state & 6'b110100)
                m_ready <= 1'b1;
            end
            else if(col_cnt == col_num_r) begin
                m_ready <= 1'b0;
            end
        end
        else begin
            m_ready <= 1'b0;
        end  
    end
    
    assign r_valid = m_ready;
    assign r_last = (col_cnt == col_num_r) && m_ready;
    

    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY-1 : 0] m_valid_d, m_last_d; 
    always @(posedge clk) begin
        if(rst) begin
            m_valid_d <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d  <= {m_valid_d[READ_DELAY-1 : 0], r_valid};
            m_last_d <= {m_last_d[READ_DELAY-1 : 0], r_last};
        end
    end

    


    //cnt的多周期延迟写法
    integer i;
    reg [COL_WIDTH : 0] col_cnt_d[0 : READ_DELAY-1];
    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < READ_DELAY; i = i + 1) begin
                col_cnt_d[i] <= 0;
            end
        end
        else begin
            //未延迟原始变量延一拍
            col_cnt_d[0] <= col_cnt;
            for (i = 1; i < READ_DELAY; i = i + 1) begin
                col_cnt_d[i] <= col_cnt_d[i-1];
            end
        end
    end


    

    //输出时序
    assign m_valid = m_valid_d[READ_DELAY-1];
    assign m_last = m_last_d[READ_DELAY-1];




endmodule