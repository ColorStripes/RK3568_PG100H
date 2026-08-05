module conv_add #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              MAX_OUT_COL = 320,                         //输出的IMG的最大列数
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数

              INT = 8,                                  //每个数的位宽

              BIAS_NUM = 2 ,                             //一行拼接的bias个数
              BISA_CNT_NUM = CHA_PAR_OUT / BIAS_NUM,     //bias的计数器
              BIAS_WIDTH = 32 * BIAS_NUM,                //偏置的位宽
              SCALE_WIDTH = 16,                          //scale的小数位数

              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_DATA_WIDTH = 2*INT + 4 + $clog2(CHA_PAR_IN),
              //DSP48E1的最大输入25位宽 所以只取25位送给乘法器  VIVADO可以通过LUT少位预取 最大达到27位  
              DSP_WIDTH = 25,
              //如果IN_DATA_WIDTH大于等于25  就不能固定25位位宽进行，否则会使数据阶段，符号位消失                           
              DATA_WIDTH = (IN_DATA_WIDTH > DSP_WIDTH) ? IN_DATA_WIDTH : DSP_WIDTH,  
              //数据传输位宽=传进来的位宽+此模块要加几次 （8个16通道要加7次 每加1次位数多1）
              //ADD_WIDTH = IN_DATA_WIDTH + (MAX_IN_CALULATE_NUM-1), 
              //这个数据位宽是cin_add_cin加法多一位
              ADD_WIDTH = DATA_WIDTH + 1,          
              DATA_DEPTH = MAX_OUT_COL,                  //输出的IMG的最大列数
              READ_DELAY = 1,
              MUL_DELAY = 4            
)
(
    input         clk         ,
    input         rst         ,

    input                      start       ,
    input                      stride        ,
    input                      en_relu       ,
    input  [SCALE_WIDTH-1 : 0] scale_3       ,
    input  [INT-1 : 0]         zero_3        ,

    //这两个信号应该与s_data_last传入的时刻保持一致
    //所以应该去conv33_ctrl延迟 conv时间的周期
    input                     calculate_first  ,
    input                     calculate_last   ,

    input  [BIAS_WIDTH-1 : 0] bias        ,
    input                     bias_valid  ,
    input                     bias_last   ,

    //从conv模块进来的8个核
    // input [IN_DATA_WIDTH-1 : 0] s_data_0    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_1    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_2    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_3    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_4    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_5    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_6    ,
    // input [IN_DATA_WIDTH-1 : 0] s_data_7    ,
    input [CHA_PAR_OUT * IN_DATA_WIDTH-1 : 0] s_data    ,
    input                                     s_valid   ,
    input                                     s_last    ,

    // output [INT-1 : 0]  m_data_0    ,
    // output [INT-1 : 0]  m_data_1    ,
    // output [INT-1 : 0]  m_data_2    ,
    // output [INT-1 : 0]  m_data_3    ,
    // output [INT-1 : 0]  m_data_4    ,
    // output [INT-1 : 0]  m_data_5    ,
    // output [INT-1 : 0]  m_data_6    ,
    // output [INT-1 : 0]  m_data_7    ,
    output [CHA_PAR_OUT * INT-1 : 0]  m_data    ,
    output                            m_valid   ,
    output                            m_last    ,


    output        add_last          //bias使用完毕
);


    // integer i;
///////////////////////////延迟数据//////////////////////////////
    // //scale 和 cin_add_cin 对齐   (读延迟 +  加法结果一拍)
    // localparam SCALE_DELAY = READ_DELAY + 1;
    // reg [SCALE_WIDTH-1 : 0] scale_d [0 : SCALE_DELAY-1];
    // always @(posedge clk) begin
    //     // 乘法计算（仅在第一阶段）
    //     scale_d[0] <= scale;
    //     // 流水线数据向后传输
    //     for(i = 1; i < SCALE_DELAY; i = i + 1) begin
    //         scale_d[i] <= scale_d[i-1];
    //     end
    // end



    // //zero使用结束的延迟  (读延迟 +  加法结果一拍 + 乘法器延迟 + 1拍加bias的延迟)
    // localparam ZERO_DELAY = READ_DELAY + 1 + MUL_DELAY + 1;
    // reg [INT-1 : 0] zero_d [0 : ZERO_DELAY-1];
    // always @(posedge clk) begin
    //     // 乘法计算（仅在第一阶段）
    //     zero_d[0] <= zero;
    //     // 流水线数据向后传输
    //     for(i = 1; i < ZERO_DELAY; i = i + 1) begin
    //         zero_d[i] <= zero_d[i-1];
    //     end
    // end



// //////////////////////////启动数据///////////////////////////////////////
//     reg [SCALE_WIDTH-1 : 0] scale;
//     reg [INT-1 : 0] zero        ;
//     always @(posedge clk) begin
//         if(start) begin
//             scale <= scale_3;
//             zero  <= zero_3 ;
//         end
//     end

/////////////////////////////////前后并行输入通道相加（前16+后16）////////////////////////////////
    // always @(posedge clk) begin
    //     if(calculate_first_d[READ_DELAY-1]) begin
    //         add_data[0] <= $signed(s_data_0_d[1]) + $signed(0);
    //         add_data[1] <= $signed(s_data_1_d[1]) + $signed(0);
    //         add_data[2] <= $signed(s_data_2_d[1]) + $signed(0);
    //         add_data[3] <= $signed(s_data_3_d[1]) + $signed(0);
    //         add_data[4] <= $signed(s_data_4_d[1]) + $signed(0);
    //         add_data[5] <= $signed(s_data_5_d[1]) + $signed(0);
    //         add_data[6] <= $signed(s_data_6_d[1]) + $signed(0);
    //         add_data[7] <= $signed(s_data_7_d[1]) + $signed(0);
    //     end
    //     else begin
    //         add_data[0] <= $signed(s_data_0_d[1]) + $signed(rdata[0]);
    //         add_data[1] <= $signed(s_data_1_d[1]) + $signed(rdata[1]);
    //         add_data[2] <= $signed(s_data_2_d[1]) + $signed(rdata[2]);
    //         add_data[3] <= $signed(s_data_3_d[1]) + $signed(rdata[3]);
    //         add_data[4] <= $signed(s_data_4_d[1]) + $signed(rdata[4]);
    //         add_data[5] <= $signed(s_data_5_d[1]) + $signed(rdata[5]);
    //         add_data[6] <= $signed(s_data_6_d[1]) + $signed(rdata[6]);
    //         add_data[7] <= $signed(s_data_7_d[1]) + $signed(rdata[7]);
    //     end
    // end
    genvar i, j;
    //并行通道+并行通道
    reg [ADD_WIDTH-1 : 0] cin_add_cin[CHA_PAR_OUT-1 : 0];
    generate 
        for (i = 0; i < CHA_PAR_OUT; i = i + 1) begin
            always @(posedge clk) begin
                if(calculate_first_d[READ_DELAY-1]) begin
                    cin_add_cin[i] <= $signed(s_data_d[i][READ_DELAY-1]) + $signed({ADD_WIDTH{1'b0}});
                end
                else begin
                    cin_add_cin[i] <= $signed(s_data_d[i][READ_DELAY-1]) + $signed(rdata[i]);
                end
            end
        end
    endgenerate

/////////////////////////////////前后（前16+后16）并行输入通道相加数据写入一个RAM寄存////////////////////////////////
    //有输出并行度个写数据
    wire [DATA_WIDTH-1 : 0] wdata[CHA_PAR_OUT-1 : 0];
    generate
        for (i = 0; i < CHA_PAR_OUT; i = i + 1) begin
            //符号位拼接  把这个数据固定到DSP能接受的位宽范围
            assign wdata[i] = {cin_add_cin[i][ADD_WIDTH-1], cin_add_cin[i][DATA_WIDTH-2 : 0]};
        end
    endgenerate

    //写使能  (多延迟了一周期 是因为读出来后 数据+法的结果还要一拍)
    reg wen_d;
    always @(posedge clk) begin
        wen_d <= s_valid_d[READ_DELAY-1];
    end
    wire wen = wen_d;

    //写地址
    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);
    reg [ADDR_WIDTH-1 : 0] waddr;
    always @(posedge clk) begin
        if(rst) begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(wen) begin
            waddr <= waddr + 1'b1;
        end
        else begin
            waddr <= {ADDR_WIDTH{1'b0}};
        end

    end


/////////////////////////////////读出上一次加和的结果////////////////////////////////
    //读使能
    wire ren = s_valid;

    //读地址
    reg [ADDR_WIDTH-1 : 0] raddr;
    always @(posedge clk ) begin
        if(rst) begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
        else if(ren) begin
            raddr <= raddr + 1'b1;
        end
        else begin
            raddr <= {ADDR_WIDTH{1'b0}};
        end
    end

    //RAM生成 （这里存储的是输出的一行数据点  前16通道和的点值）每一个地址代表一个点 下一个地址代表下一个点
    wire [DATA_WIDTH-1 : 0] rdata [CHA_PAR_OUT-1 : 0];
    generate
        for(i = 0; i < CHA_PAR_OUT; i = i + 1) begin: ADD_RAM
            spram #(
                .DP(DATA_DEPTH),    //存储单元深度
                .DW(DATA_WIDTH),    //数据位宽
                .PIPE(READ_DELAY)  
            ) 
            ram(
                .clk   (clk),
                .wdata (wdata[i]),
                .wen   (wen),
                .waddr (waddr),
                .ren   (ren),
                .raddr (raddr),
                .rdata (rdata[i])
            );
        end
    endgenerate





    //并行度待更改
    // wire [IN_DATA_WIDTH-1 : 0] s_data[CHA_PAR_OUT-1 : 0];
    // assign s_data[0] = s_data_0;
    // assign s_data[1] = s_data_1;
    // assign s_data[2] = s_data_2;
    // assign s_data[3] = s_data_3;
    // assign s_data[4] = s_data_4;
    // assign s_data[5] = s_data_5;
    // assign s_data[6] = s_data_6;
    // assign s_data[7] = s_data_7;

    //s_data多周期延迟写法
    // reg [IN_DATA_WIDTH * READ_DELAY-1 : 0] s_data_d[CHA_PAR_OUT-1 : 0];
    // generate
    //     for (genvar i = 0; i < CHA_PAR_OUT; i = i+1) begin
    //         always @(posedge clk) begin
    //             if(rst) begin
    //                 s_data_d[i] <= 0;
    //             end
    //             else begin
    //                 s_data_d[i] <= {s_data_d[i][IN_DATA_WIDTH * READ_DELAY-1 : 0], s_data[i]};
    //             end
    //         end
    //     end
    // endgenerate

    integer k;
    //s_data多周期延迟写法
    reg [IN_DATA_WIDTH-1 : 0] s_data_d[CHA_PAR_OUT-1 : 0][0 : READ_DELAY-1];
    generate
        for (j = 0; j < CHA_PAR_OUT; j = j+1) begin

            always @(posedge clk) begin
                if(rst) begin
                    for (k = 0; k < READ_DELAY; k = k + 1) begin
                        s_data_d[j][k] <= 0;
                    end
                end
                else begin
                    s_data_d[j][0] <= s_data[j * IN_DATA_WIDTH +: IN_DATA_WIDTH];
                    for (k = 1; k < READ_DELAY; k = k + 1) begin
                        s_data_d[j][k] <= s_data_d[j][k-1];
                    end
                end
            end

        end
    endgenerate


/////////////////////////////////bias处理////////////////////////////////
    //bias计数器
    //与conv33_weight中的一致 就是指出有几个卷积核在使用
    reg [$clog2(CHA_PAR_OUT)-1 : 0] kernel_cnt;
    always @(posedge clk) begin
        if(rst) begin
            kernel_cnt <= 0;
        end
        else if(bias_valid) begin
            kernel_cnt <= kernel_cnt + 1;
        end
        else begin
            kernel_cnt <= 0;
        end
    end

    ////////乒乓处理//////
    //写乒乓
    reg w_ctl;
    always @(posedge clk) begin
        if(rst) begin
            w_ctl <= 1'b0;
        end
        else if(start) begin
            w_ctl <= 1'b0;
        end
        else if(bias_last) begin
            w_ctl <= !w_ctl;
        end
    end


    //写数据
    // reg [BIAS_WIDTH-1 : 0] bias_mem_ping[CHA_PAR_OUT-1 : 0];
    // reg [BIAS_WIDTH-1 : 0] bias_mem_pang[CHA_PAR_OUT-1 : 0];
    reg [BIAS_WIDTH-1 : 0] bias_mem_ping[BISA_CNT_NUM-1 : 0];
    reg [BIAS_WIDTH-1 : 0] bias_mem_pang[BISA_CNT_NUM-1 : 0];
    always @(posedge clk) begin
        if(bias_valid) begin
            if(w_ctl == 1'b0) begin
                bias_mem_ping[kernel_cnt] <= bias;
            end
            else begin
                bias_mem_pang[kernel_cnt] <= bias;
            end
        end
    end



    ////////乒乓处理//////
    //读乒乓
    //r_ctl 与 bias 使用完才切换的对齐  (第一个ram读延迟 +  cin_add_cin加法结果一拍 + 乘法器延迟)
    localparam BIAS_DELAY = READ_DELAY + 1 + MUL_DELAY;
    reg r_ctl;
    always @(posedge clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(start) begin
            r_ctl <= 1'b0;
        end
        else if(calculate_last_d[BIAS_DELAY-1] & s_last_d[BIAS_DELAY-1]) begin
            r_ctl <= !r_ctl;
        end
    end

    //读数据
    // wire [BIAS_WIDTH-1 : 0] bias_data[CHA_PAR_OUT-1 : 0];
    // generate
    //     for (genvar i = 0; i < CHA_PAR_OUT; i = i+1) begin
    //         assign bias_data[i] = (r_ctl == 1'b0) ? bias_mem_ping[i] : bias_mem_pang[i];
    //     end
    // endgenerate
    wire [BIAS_WIDTH / BIAS_NUM-1 : 0] bias_data[CHA_PAR_OUT-1 : 0];
    generate
        for (i = 0; i < CHA_PAR_OUT/BIAS_NUM; i = i+1) begin
            if(BIAS_NUM == 1) begin
                assign bias_data[i] = (r_ctl == 1'b0) ? bias_mem_ping[i][BIAS_WIDTH/BIAS_NUM-1 : 0] : bias_mem_pang[i][BIAS_WIDTH/BIAS_NUM-1 : 0];
            end
            else begin
                assign bias_data[i*BIAS_NUM]   = (r_ctl == 1'b0) ? bias_mem_ping[i][BIAS_WIDTH/BIAS_NUM-1 : 0] : bias_mem_pang[i][BIAS_WIDTH/BIAS_NUM-1 : 0];
                assign bias_data[i*BIAS_NUM+1] = (r_ctl == 1'b0) ? bias_mem_ping[i][BIAS_WIDTH-1 : BIAS_WIDTH/BIAS_NUM] : bias_mem_pang[i][BIAS_WIDTH-1 : BIAS_WIDTH/BIAS_NUM];
            end
        end
    endgenerate
        
    assign add_last = calculate_last_d[BIAS_DELAY-1] & s_last_d[BIAS_DELAY-1];

////////////////////////////////scale是s1*s2/s3 这里是将q1*q2先变为f1*f2=f3 然后/s3 将f3变为q3定点数///////////////////////////////////////

    //q1*q2 乘以 s1*s2/s3     = p3
    wire [DATA_WIDTH+SCALE_WIDTH : 0] p3[CHA_PAR_OUT-1 : 0];
    generate
        for (i = 0; i < CHA_PAR_OUT; i = i + 1) begin: SCALE_S1_S2_S3
            scale_mul_s3 #(
                .DATA_WIDTH (DATA_WIDTH),
                .SCALE_WIDTH(SCALE_WIDTH+1),       //会多一个符号位
                .DELAY(MUL_DELAY)
            )
            scale_mul_inst(
                .clk(clk),
                .A(wdata[i]),  //{cin_add_cin[i][ADD_WIDTH-1], cin_add_cin[i][DATA_WIDTH-2 : 0]}
                .B({1'b0, scale_3}),
                .P(p3[i])
            );
        end
    endgenerate



////////////////////////////////q3 + b3  都是整数类型的///////////////////////////////////////
    //p3 + bias3 + Z3
    reg signed [DATA_WIDTH+SCALE_WIDTH : 0] p3_b3_z3[CHA_PAR_OUT-1 : 0];
    generate
        for(i = 0; i < CHA_PAR_OUT; i = i + 1) begin: Q3_B3_Z3
            always @(posedge clk) begin
                p3_b3_z3[i] <= $signed(p3[i]) + $signed(bias_data[i]) + $signed({1'b0, zero_3, {SCALE_WIDTH{1'b0}}} );
            end
        end
    endgenerate


    //调精度  限制在8位 
    reg [INT-1 : 0] p3_b3_z3_buff[CHA_PAR_OUT-1 : 0];
    generate
        for(i = 0; i < CHA_PAR_OUT; i = i + 1) begin: Q3_B3_Z3_BUF
            always @(posedge clk) begin
                if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH]) begin
                    p3_b3_z3_buff[i] <= {INT{1'b0}};
                end
                else begin
                    if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH - 1 : SCALE_WIDTH] >= {INT{1'b1}}) begin
                        p3_b3_z3_buff[i] <= {INT{1'b1}};
                    end
                    else begin
                        p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH] + p3_b3_z3[i][SCALE_WIDTH-1];
                    end
                end
            end
        end
    endgenerate

    // reg [INT-1 : 0] p3_b3_z3_buff[CHA_PAR_OUT-1 : 0];
    // generate
    //     for(genvar i = 0; i < CHA_PAR_OUT; i = i + 1) begin: Q3_B3_Z3_BUF
    //         always @(posedge clk) begin
    //             if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH]) begin
    //                 p3_b3_z3_buff[i] <= {INT{1'b0}};
    //             end
    //             else if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH - 1 : SCALE_WIDTH] >= {INT{1'b1}}) begin
    //                 p3_b3_z3_buff[i] <= {INT{1'b1}};
    //             end
    //             else if(p3_b3_z3[i][SCALE_WIDTH-1 : 0] < {1'b1, {SCALE_WIDTH-3{1'b0}}, 2'b01}) begin         //小于0.50000010就不变
    //                 p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH];
    //             end
    //             else begin
    //                 p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH] + 1'b1;
    //             end
    //         end
    //     end
    // endgenerate

    // //调精度  限制在8位 
    // reg [INT-1 : 0] p3_b3_z3_buff[CHA_PAR_OUT-1 : 0];
    // generate
    //     for(genvar i = 0; i < CHA_PAR_OUT; i = i + 1) begin: Q3_B3_Z3_BUF
    //         always @(posedge clk) begin
    //             if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH]) begin
    //                 p3_b3_z3_buff[i] <= {INT{1'b0}};
    //             end
    //             else if(p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH - 1 : SCALE_WIDTH] >= {INT{1'b1}}) begin
    //                 p3_b3_z3_buff[i] <= {INT{1'b1}};
    //             end
    //             // 3. 核心舍入逻辑：
    //             else begin
    //                 if(p3_b3_z3[i][SCALE_WIDTH-1 : 0] > 16'h8000) begin
    //                     // 大于 0.5，直接进位
    //                     p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH] + 1'b1;
    //                 end
    //                 else if(p3_b3_z3[i][SCALE_WIDTH-1 : 0] == 16'h8000) begin
    //                     // 刚好等于 0.5，执行银行家规则：加上整数的最低位
    //                     // 如果是奇数(int_lsb=1)，1+1=2进位变偶数；如果是偶数(int_lsb=0)，+0不变
    //                     p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH] + p3_b3_z3[i][SCALE_WIDTH]; 
    //                 end
    //                 else begin
    //                     // 小于 0.5，直接截断
    //                     p3_b3_z3_buff[i] <= p3_b3_z3[i][INT+SCALE_WIDTH-1 : SCALE_WIDTH];
    //                 end
    //             end
    //         end
    //     end
    // endgenerate



    // //位拼接   （符号位+INT+16位小数位）
    // // reg [INT+SCALE_WIDTH : 0] p3_b3_z3_buff[CHA_PAR_OUT-1 : 0];
    // generate
    //     for(genvar i = 0; i < CHA_PAR_OUT; i = i + 1) begin: Q3_B3_Z3_BUF
    //         //assign p3_b3_buff[i] = {p3_b3[i][DATA_WIDTH+SCALE_WIDTH], p3_b3[i][INT+SCALE_WIDTH-1 : 0]};
    //         //因为f3是relu后量化 所以都是正的 才量化为无符号数
    //         assign p3_b3_z3_buff[i] = p3_b3_z3[i][DATA_WIDTH+SCALE_WIDTH] ? 0 : {p3_b3[i][DATA_WIDTH+SCALE_WIDTH], p3_b3[i][INT+SCALE_WIDTH-1 : 0]} + p3_b3[i][SCALE_WIDTH-1];
    //     end
    // endgenerate






////////////////////////////////Relu激活///////////////////////////////////////
    //relu(r) >= relu(s(q-z))  
    reg [INT-1 : 0] relu[CHA_PAR_OUT-1 : 0];
    generate
        for(i = 0; i < CHA_PAR_OUT; i = i + 1) begin: RELU

            always @(posedge clk) begin
                if((p3_b3_z3_buff[i] < zero_3) & en_relu) begin
                    relu[i] <= zero_3;
                end
                else begin
                    relu[i] <= p3_b3_z3_buff[i];
                end
            end

        end
    endgenerate



////////////////////////////////数据输出////////////////////////////////////////待修改
    // assign m_data_0 = relu[0];
    // assign m_data_1 = relu[1];
    // assign m_data_2 = relu[2];
    // assign m_data_3 = relu[3];
    // assign m_data_4 = relu[4];
    // assign m_data_5 = relu[5];
    // assign m_data_6 = relu[6];
    // assign m_data_7 = relu[7];

    generate
        for(i = 0; i < CHA_PAR_OUT; i = i + 1) begin: OUT_PUT
            assign m_data[i * INT +: INT] = relu[i];
        end
    endgenerate



////////////////////////////////////////////计算结束信号输出延迟//////////////////////////////////////////////////////
    //输出信号延迟  是所有计算结束延迟 (读延迟 +  加法结果一拍 + 乘法器延迟 + 1拍加bias的延迟 + 1拍加zero的延迟 + relu延迟)
    localparam CALCULATE_DELAY = READ_DELAY + 1 + MUL_DELAY + 1 + 1 + 1;
    reg [CALCULATE_DELAY-1 : 0] s_valid_d, s_last_d, calculate_first_d, calculate_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            s_valid_d <= 0;
            s_last_d <= 0;
            calculate_first_d <= 0;
            calculate_last_d <= 0;
        end
        else begin
            s_valid_d <= {s_valid_d[CALCULATE_DELAY-1 : 0] , s_valid};
            s_last_d  <= {s_last_d[CALCULATE_DELAY-1 : 0]  , s_last};
            calculate_first_d <= {calculate_first_d[CALCULATE_DELAY-1 : 0] , calculate_first};
            calculate_last_d  <= {calculate_last_d[CALCULATE_DELAY-1 : 0]  , calculate_last};
        end
    end


    assign m_valid = s_valid_d[CALCULATE_DELAY-1] & calculate_last_d[CALCULATE_DELAY-1];
    //stride的时候会提前拉高一周期
    assign m_last= stride ? s_last_d[CALCULATE_DELAY-2] & calculate_last_d[CALCULATE_DELAY-2] : s_last_d[CALCULATE_DELAY-1] & calculate_last_d[CALCULATE_DELAY-1];


endmodule