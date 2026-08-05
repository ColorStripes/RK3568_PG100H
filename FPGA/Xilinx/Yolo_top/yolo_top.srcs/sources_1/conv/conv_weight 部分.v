module conv_weight #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              CHA_IMG_OUT = 256,                         //输出的IMG的最大通道数
              INT = 8,                                   //每个数的位宽
              //这是向DMA请求weight的总字节数 包括bias   ===》 ci*co*9 + co * 16字节
              //ci*co*9是weight总字节数 一个bias是128位的也就是16字节数，所以加上co*16，但bias只有32位是有效的  
              WEIGHT_SUM = CHA_IMG_IN * CHA_IMG_OUT * 9 + CHA_IMG_OUT * 16,  //每次取一小部分weight
              WEIGHT_SUM_WIDTH = $clog2(WEIGHT_SUM),
              //一个weight点的字节数
              WEIGHT_LEN = CHA_IMG_IN * CHA_IMG_OUT,
              WEIGHT33_LEN = CHA_IMG_IN * CHA_IMG_OUT,
              WEIGHT_LEN_WIDTH = $clog2(WEIGHT_LEN),
              //RAM-weight
              DATA_WIDTH = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              DATA_DEPTH = CHA_PAR_OUT,                  //数据深度  这里是 weight的个数/每一行的拿取的个数
              //BIAS
              BIAS_NUM = 2 ,                             //一行拼接的bias个数
              BISA_CNT_NUM = CHA_PAR_OUT / BIAS_NUM,     //bias的计数器   每次几行bias
              BIAS_LEN = (CHA_IMG_OUT / BIAS_NUM * CHA_PAR_IN) ,              //bias_len的长度包括bias全部通道数的字节数
              BIAS_LEN_WIDTH = $clog2(BIAS_LEN),
              //RAM-bias
              BIAS_WIDTH = 32 * BIAS_NUM,                         //偏置的位宽
              BIAS_DEPTH = CHA_IMG_OUT / BIAS_NUM,                //最大有多少个偏置  也就是输出通道个数
              //计算次数相关
              MAX_IN_COL = 320,                          //输入的IMG的最大列数
              COL_WIDTH = $clog2(MAX_IN_COL),
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),             //输出通道计算次数=输出通道数/输出并行度 
              OUT_CALULATE_CNT_WIDTH = $clog2(MAX_OUT_CALULATE_NUM),
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),


              READ_DELAY = 1
)
(
    input          clk         ,
    input          rst         ,

    input          start       ,
    input          type        ,
    input          stride      ,

    input  [AXI_DATA_WIDTH-1 : 0] base_addr,              //写内存的起始基地址
    input  [WEIGHT_SUM_WIDTH : 0] weight_sum,              //这是向DMA请求weight的总字节数 包括bias   ===》 ci*co*9 + co * 16字节
    input  [BIAS_LEN_WIDTH : 0]   bias_len,

    input  [ROW_WIDTH : 0]         row_num          ,

    input  [CALULATE_CNT_WIDTH : 0]      calculate_num         ,
    input  [OUT_CALULATE_CNT_WIDTH : 0]  calculate_cout_num    ,
    

    input  [DATA_WIDTH-1 : 0] s_data    ,
    input                     s_valid   ,
    input                     s_last    ,
    output                    s_ready   ,

    
    output [DATA_WIDTH-1 : 0] m_data_0    ,
    output [DATA_WIDTH-1 : 0] m_data_1    ,
    output [DATA_WIDTH-1 : 0] m_data_2    ,
    output [DATA_WIDTH-1 : 0] m_data_3    ,
    output reg [DATA_WIDTH-1 : 0] m_data_4    ,
    output [DATA_WIDTH-1 : 0] m_data_5    ,
    output [DATA_WIDTH-1 : 0] m_data_6    ,
    output [DATA_WIDTH-1 : 0] m_data_7    ,
    output [DATA_WIDTH-1 : 0] m_data_8    ,
    output                    m_valid,
    output                    m_last ,
    input                     m_req  ,


    output [BIAS_WIDTH-1 : 0]  bias        ,
    output                     bias_valid  ,
    output                     bias_last   ,
    input                      bias_req    ,

    output [AXI_ADDR_WIDTH-1 : 0]  cmd_addr    ,
    output [AXI_DATA_WIDTH-1 : 0]  cmd_len     ,
    output                         cmd_valid   ,
    input                          cmd_ready   ,

    input          calculate_end                //计算结束信号
    
);

    //部分拿取的倍数 MAX_MUL*CHA_PAR_OUT 不能超过FIFO的深度
    localparam MAX_MUL = 16;
    reg [CALULATE_CNT_WIDTH : 0] multiple;
    always @(posedge clk) begin
        if(calculate_num > MAX_MUL) begin
            multiple <= MAX_MUL;
        end 
        else begin
            multiple <= calculate_num;
        end
    end


    wire [RAM_CNT-1 : 0] almost_full, full, empty;
    wire almost_full_now, full_now;

    //状态机
    localparam IDLE = 4'b0001, WADDR = 4'b0010, WDATA = 4'b0100, W_WAIT = 4'b1000;
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
            WADDR:begin                                       //告诉DMA地址长度数据
                if(cmd_valid & cmd_ready) begin
                    next_state = WDATA;
                end
                else begin
                    next_state = WADDR;
                end
            end
            WDATA:begin                                        //从DMA里读数据出来并写入当前模块
                if(s_last & s_valid & s_ready) begin                 ////////////////////////////////////////这里不一样 ////////////////////////////////////
                    next_state = W_WAIT;
                end
                else begin
                    next_state = WDATA;
                end
            end
            W_WAIT:begin
                if(row_cnt == row_num_r) begin
                    next_state = IDLE;
                end
                else if(~almost_full_now) begin
                    next_state = WADDR;
                end
                else begin
                    next_state = W_WAIT;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end


    ////////////////////////////////////////////计算次数/////////////////////////////////////////

    reg [ROW_WIDTH : 0] row_num_r;
    always @(posedge clk) begin
        if(state == IDLE) begin
            if(stride) begin
                row_num_r <= row_num[COL_WIDTH : 1];
            end
            else begin
                row_num_r <= row_num;
            end
        end
    end


    reg [CALULATE_CNT_WIDTH : 0] calculate_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cnt <= 0;
        end
        else if(w_ram_cnt == 0) begin
            calculate_cnt <= 0;
        end
        else if((state == WDATA) && (next_state == W_WAIT)) begin
            if(calculate_cnt >= calculate_num - multiple) begin
                calculate_cnt <= 0;
            end
            else begin
                calculate_cnt <= calculate_cnt + multiple;
            end
        end
    end



    (*mark_debug = "true"*)reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk) begin
        if(rst) begin
            row_cnt <= 0;
        end
        else if(w_ram_cnt == 0) begin
            row_cnt <= 0;
        end
        else if(((state == WDATA) && (next_state == W_WAIT)) && (calculate_cnt >= calculate_num - multiple)) begin
            row_cnt <= row_cnt + 1;
        end
    end


    ////////////////////////////////////////////CMD////////////////////////////////////////////////
    localparam WEIGHT_STRIDE_33 = CHA_PAR_IN * CHA_PAR_OUT * 9;         //conv33的每次从DMAR中取的字节数
    localparam WEIGHT_STRIDE_11 = CHA_PAR_IN * CHA_PAR_OUT ;            //conv11的每次从DMAR中取的字节数

    reg [AXI_ADDR_WIDTH-1 : 0] type_stride;
    always @(posedge clk) begin
        if(type) begin
            type_stride <= WEIGHT_STRIDE_11 * multiple;
        end
        else begin
            type_stride <= WEIGHT_STRIDE_33 * multiple;
        end
    end

    (*mark_debug = "true"*)reg [AXI_ADDR_WIDTH-1 : 0] weight_stride;
    always @(posedge clk) begin
        if(w_ram_cnt == 0) begin
            weight_stride <= bias_len;
        end
        else if(base_addr + weight_sum - data_addr >= type_stride) begin
            weight_stride <= type_stride;
        end
        else begin
            weight_stride <= base_addr + weight_sum - data_addr;
        end
    end
    assign cmd_len = weight_stride;

    //内存读取地址更改
    reg [AXI_ADDR_WIDTH-1 : 0] data_addr;
    always @(posedge clk) begin
        if(state == IDLE) begin
            data_addr <= base_addr;
        end
        else if(cmd_valid & cmd_ready) begin
            if(data_addr + weight_stride == base_addr + weight_sum) begin       //读取到循环地址  重新读取weight 
                data_addr <= base_addr + bias_len;
            end
            else begin
                data_addr <= data_addr + weight_stride;
            end
        end
    end
    assign cmd_addr = data_addr;

    reg cmd_valid_r;
    always @(posedge clk) begin
        if(rst) begin
            cmd_valid_r <= 1'b0;
        end
        else if(cmd_valid & cmd_ready) begin
            cmd_valid_r <= 1'b0;
        end  
        else if(state == WADDR) begin
            cmd_valid_r <= 1'b1;
        end
    end
    assign cmd_valid = cmd_valid_r;



////////////////////////////////////////////计算相关////////////////////////////////////////////////
    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);
    localparam DEPTH_ADDR = DATA_DEPTH - 1;       //每次拿取权重的深度的地址


/////////////////////////////////////////从上级写入当前模块/////////////////////////////////////////
    //写循环RAM计数器
    localparam RAM_CNT = 9,                                 //固定9个ram 每个ram存储9个点中一个
               RAM_CNT_WIDTH = $clog2(RAM_CNT+1);
    reg [RAM_CNT_WIDTH-1 : 0] w_ram_cnt;
    always @(posedge clk ) begin
        if(rst)begin
            w_ram_cnt <= 4'd0;
        end
        else if(state == IDLE) begin
            w_ram_cnt <= 4'd0;
        end
        else if((waddr_bias == (calculate_cout_num * CHA_PAR_OUT / BIAS_NUM - 1)) && wen_all) begin                  //写完BIAS
            w_ram_cnt <= 4'd1;
        end 
        else if((waddr == DEPTH_ADDR) && (w_ram_cnt == RAM_CNT) && wen_all) begin                   //下一轮写WEIGHT
            w_ram_cnt <= 4'd1;
        end 
        else if( (waddr == DEPTH_ADDR) && wen_all ) begin       //从0计数 -1
            w_ram_cnt <= w_ram_cnt + 4'd1;
        end
    end

    //写使能(全部RAM)
    wire wen_all = s_valid & s_ready;
    wire [RAM_CNT-1 : 0] wen;
    generate
        for(genvar i = 1; i <= RAM_CNT; i = i + 1) begin
            assign wen[i-1] = (w_ram_cnt == i) ? wen_all : 1'b0;
        end
    endgenerate

    //写地址
    reg [ADDR_WIDTH-1 : 0] waddr;
    always @(posedge clk) begin
        if(rst) begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(state == WDATA) begin
            if(wen_all && ( (w_ram_cnt > 0) && (w_ram_cnt <= RAM_CNT) ) ) begin
                if(waddr == DEPTH_ADDR) begin
                    waddr <= {ADDR_WIDTH{1'b0}};
                end
                else begin
                    waddr <= waddr + 1'b1;
                end
            end
        end
    end

    //写数据
    wire [DATA_WIDTH-1 : 0] wdata = s_data;

    //写完成信号
    // reg s_ready_r;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         s_ready_r <= 1'b0;
    //     end
    //     else if(state == WADDR) begin
    //         s_ready_r <= 1'b1;
    //     end
    //     else if((state == WDATA) && (next_state == W_WAIT)) begin
    //         s_ready_r <= 1'b0;
    //     end
    // end
    // assign s_ready = s_ready_r;
    assign almost_full_now = (w_ram_cnt == 0) ? 1'b0 : almost_full[w_ram_cnt-1];
    assign full_now = (w_ram_cnt == 0) ? 1'b0 : full[w_ram_cnt-1];
    assign s_ready = (state == WDATA) && ~full_now;

    localparam BRAM_BITS_TOTAL = 36864 * 2;   //bit 不是字节 //512深度

    parameter integer FIFO_DATA_DEPTH = (DATA_WIDTH <= 72)  ? (BRAM_BITS_TOTAL / 72) :
                                        (DATA_WIDTH <= 144) ? (BRAM_BITS_TOTAL / 144) :
                                                              (BRAM_BITS_TOTAL / DATA_WIDTH);
    localparam ALMOST_FULL_NUM  = FIFO_DATA_DEPTH - CHA_PAR_OUT * MAX_MUL;                     
    //RAM生成
    
    wire [DATA_WIDTH-1 : 0] rdata [RAM_CNT-1 : 0];
    generate
        for(genvar i = 0; i < RAM_CNT; i = i + 1) begin

            sync_fifo #(                
                .DATA_WIDTH(DATA_WIDTH),
                .ALMOST_FULL_NUM(ALMOST_FULL_NUM),
                .DATA_DEPTH(FIFO_DATA_DEPTH)         //Vivado固定占用两块BRAM
            )
            weight_fifo(
                .clk(clk),
                .rst(rst),
                .wr_en(wen[i]),
                .rd_en(ren[i]),
                .din(wdata),
                .dout(rdata[i]),
                .full(full[i]),
                .almost_full(almost_full[i]),
                .empty(empty[i])
            );

        end
    endgenerate



/////////////////////////////////////////从当前模块读出到下级/////////////////////////////////////////
    //读循环RAM计数器
    reg [RAM_CNT_WIDTH-1 : 0] r_ram_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            r_ram_cnt <= 4'd1;
        end
        else if(calculate_end) begin
            r_ram_cnt <= 4'd1;
        end
        else if((raddr == DEPTH_ADDR) && (r_ram_cnt == RAM_CNT) && |ren) begin                   //下一轮写WEIGHT
            r_ram_cnt <= 4'd1;
        end 
        else if(raddr == DEPTH_ADDR) begin       //从0计数 -1
            r_ram_cnt <= r_ram_cnt + 4'd1;
        end
    end


    //m_req变m_ready
    reg m_ready;                         
    always @(posedge clk) begin
        if(rst) begin
            m_ready <= 1'b0;
        end
        else if(raddr == DEPTH_ADDR) begin
            m_ready <= 1'b0;
        end 
        else if(m_req & !m_valid) begin
            m_ready <= 1'b1;
        end
    end


    //读使能(全部RAM)
    wire ren_all = m_ready;
    (*mark_debug = "true"*)reg [RAM_CNT-1 : 0] ren;


    integer i;

    always @(posedge clk) begin
        if(rst) begin
            ren <= 0;
        end
        else begin
            if(raddr == DEPTH_ADDR) begin
                for(i = 0; i < RAM_CNT; i = i + 1) begin
                    ren[i] <= 1'b0;
                end
            end
            else if(type) begin
                for(i = 0; i < RAM_CNT; i = i + 1) begin
                    if(r_ram_cnt == (i+1)) begin
                        if( ((w_ram_cnt != (i+1)) && ~empty[i]) || ((w_ram_cnt == (i+1)) && almost_full[i]) ) begin
                            ren[i] <= ren_all;
                        end
                    end
                end
            end
            else begin                    
                if((w_ram_cnt != RAM_CNT) && ~empty[RAM_CNT-1]) begin
                    for(i = 0; i < RAM_CNT; i = i + 1) begin
                        ren[i] <= ren_all;
                    end
                end
            end
        end    
    end




    //读地址
    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk ) begin
        if(rst) begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(|ren) begin
            if(raddr == DEPTH_ADDR) begin
                raddr <= {ADDR_WIDTH{1'b0}};
            end
            else begin
                raddr <= raddr + 1'b1;
            end
        end
    end

    wire r_valid = |ren;
    wire r_last = (raddr == CHA_PAR_OUT-1);     //所需要输出并行度的最后一个




    // integer  i;
    // reg [RAM_CNT-1 : 0] ren_d[READ_DELAY-1 : 0];
    // always @(posedge clk) begin
    //     // 乘法计算（仅在第一阶段）
    //     ren_d[0] <= ren;
    //     // 流水线数据向后传输
    //     for(i = 1; i < READ_DELAY; i = i + 1) begin
    //         ren_d[i] <= ren_d[i-1];
    //     end
    // end



    // //多周期延迟  （以下代码全部与spram的延迟有关）
    // reg [READ_DELAY-1 : 0] m_valid_d, m_last_d; 
    // always @(posedge clk) begin
    //     if(rst) begin
    //         m_valid_d <= 0;
    //         m_last_d <= 0;
    //     end
    //     else begin
    //         m_valid_d  <= {m_valid_d[READ_DELAY-1 : 0], r_valid};
    //         m_last_d <= {m_last_d[READ_DELAY-1 : 0], r_valid};
    //     end
    // end


    //输出时序
    // assign m_valid = m_valid_d[READ_DELAY-1];
    // assign m_last = m_last_d[READ_DELAY-1];
    assign m_valid = r_valid;
    assign m_last  = r_last;
    //向下级输出数据
    assign m_data_0 = rdata[0];
    assign m_data_1 = rdata[1];
    assign m_data_2 = rdata[2];
    assign m_data_3 = rdata[3];
    always @(*) begin
        case(1'b1)
            (!type):begin
                m_data_4 = rdata[4];
            end
            ren[0]:begin
                m_data_4 = rdata[0];
            end
            ren[1]:begin
                m_data_4 = rdata[1];
            end
            ren[2]:begin
                m_data_4 = rdata[2];
            end
            ren[3]:begin
                m_data_4 = rdata[3];
            end
            ren[4]:begin
                m_data_4 = rdata[4];
            end
            ren[5]:begin
                m_data_4 = rdata[5];
            end
            ren[6]:begin
                m_data_4 = rdata[6];
            end
            ren[7]:begin
                m_data_4 = rdata[7];
            end
            ren[8]:begin
                m_data_4 = rdata[8];
            end
            default:begin
                m_data_4 = 0;
            end
        endcase
    end
    assign m_data_5 = rdata[5];
    assign m_data_6 = rdata[6];
    assign m_data_7 = rdata[7];
    assign m_data_8 = rdata[8];



    //////////////////BIAS偏置///////////////////////////
    localparam ADDR_WIDTH_BIAS = $clog2(BIAS_DEPTH);
    //偏置写使能
    wire wen_bias = wen_all & (w_ram_cnt == 0);
    //偏置写地址
    reg [ADDR_WIDTH_BIAS-1 : 0] waddr_bias;
    always @(posedge clk) begin
        if(rst) begin
            waddr_bias <= {ADDR_WIDTH_BIAS{1'b0}};
        end
        else if(state == IDLE) begin
            waddr_bias <= {ADDR_WIDTH_BIAS{1'b0}};
        end
        else if(wen_bias) begin
            waddr_bias <= waddr_bias + 1;
        end
    end
    //偏置写数据
    wire [BIAS_WIDTH-1:0] wdata_bias;  // 声明在 generate 块外 全局可见
    generate
        if(BIAS_NUM == 1) begin
            assign wdata_bias = s_data[BIAS_WIDTH-1 : 0];
        end
        else begin
            assign wdata_bias = {s_data[BIAS_WIDTH +: BIAS_WIDTH/BIAS_NUM], s_data[0 +: BIAS_WIDTH/BIAS_NUM]};
        end
    endgenerate


    //////////////////BIAS偏置///////////////////////////

    //bias_req变bias_ready
    reg bias_ready;                         
    always @(posedge clk) begin
        if(rst) begin
            bias_ready <= 1'b0;
        end
        else if(bias_cnt == BISA_CNT_NUM) begin
            bias_ready <= 1'b0;
        end 
        else if(bias_req & !bias_valid) begin
            bias_ready <= 1'b1;
        end
    end

    //偏置的个数计数器
    reg [$clog2(CHA_PAR_OUT) : 0] bias_cnt;
    always @(posedge clk) begin
        if(rst) begin
            bias_cnt <= 0;
        end
        else if(bias_cnt == BISA_CNT_NUM) begin
            bias_cnt <= 0;
        end
        else if(bias_ready) begin
            bias_cnt <= bias_cnt + 1;
        end
    end


    //偏置读使能
    wire ren_bias = (bias_cnt < BISA_CNT_NUM) & bias_ready;   //当cnt为输出并行度所需要的bias时 cnt就不动了 ren也就拉低了
    //偏置读地址
    reg [ADDR_WIDTH_BIAS-1 : 0] raddr_bias;
    always @(posedge clk) begin
        if(rst) begin
            raddr_bias <= {ADDR_WIDTH_BIAS{1'b0}};
        end
        else if(calculate_end) begin
            raddr_bias <= {ADDR_WIDTH_BIAS{1'b0}};
        end
        else if(ren_bias) begin
            if(raddr_bias == (calculate_cout_num * CHA_PAR_OUT / BIAS_NUM - 1)) begin
                raddr_bias <= 0;
            end
            else begin
                raddr_bias <= raddr_bias + 1;
            end
        end
    end

    //偏置读数据
    assign bias = rdata_bias;

    //向下级输出
    wire r_valid_bias = ren_bias;
    wire r_last_bias = ren_bias & (bias_cnt == BISA_CNT_NUM - 1);     //所需要输出并行度的最后一个


    //多周期延迟  （以下代码全部与spram的延迟有关）
    reg [READ_DELAY-1 : 0] bias_valid_d, bias_last_d; 
    always @(posedge clk) begin
        if(rst) begin
            bias_valid_d <= 0;
            bias_last_d <= 0;
        end
        else begin
            bias_valid_d  <= {bias_valid_d[READ_DELAY-1 : 0], r_valid_bias};
            bias_last_d <= {bias_last_d[READ_DELAY-1 : 0], r_last_bias};
        end
    end

    //RAM生成(bias)
    wire [BIAS_WIDTH-1 : 0] rdata_bias;
    spram #(.DP(BIAS_DEPTH),    //存储单元深度
            .DW(BIAS_WIDTH),    //数据位宽
            .PIPE(READ_DELAY)  
    ) ram
    (
        .clk   (clk   ),
        .wdata (wdata_bias),
        .wen   (wen_bias),
        .waddr (waddr_bias),
        .ren   (ren_bias),
        .raddr (raddr_bias),
        .rdata (rdata_bias)
    );

    //输出时序
    assign bias_valid = bias_valid_d[READ_DELAY-1];
    assign bias_last = bias_last_d[READ_DELAY-1];



endmodule