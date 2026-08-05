module conv_conv #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              OUT_DATA_WIDTH = 2*INT + 4 + $clog2(CHA_PAR_IN),
              MUL_DELAY = 4                              //conv的乘法器延迟
)
(
    input          clk         ,
    input          rst         ,

    input          start       ,
    input          type        ,            //type = 0 conv33;   type = 1 conv11

    //权重的传输（9个点 输入并行度位宽）
    input [DATA_WIDTH-1 : 0] weight_0    ,
    input [DATA_WIDTH-1 : 0] weight_1    ,
    input [DATA_WIDTH-1 : 0] weight_2    ,
    input [DATA_WIDTH-1 : 0] weight_3    ,
    input [DATA_WIDTH-1 : 0] weight_4    ,
    input [DATA_WIDTH-1 : 0] weight_5    ,
    input [DATA_WIDTH-1 : 0] weight_6    ,
    input [DATA_WIDTH-1 : 0] weight_7    ,
    input [DATA_WIDTH-1 : 0] weight_8    ,
    input                       weight_valid,
    input                       weight_last ,

    //img数据的传输(3行)
    input [DATA_WIDTH-1 : 0] s_data_0      ,
    input [DATA_WIDTH-1 : 0] s_data_1      ,
    input [DATA_WIDTH-1 : 0] s_data_2      ,
    input                       s_valid  ,
    input                       s_last   ,

    

    output [CHA_PAR_OUT * OUT_DATA_WIDTH-1 : 0]  m_data   ,
    output                                       m_valid,
    output                                       m_last 

    // output         mul_last                 //乘法器接受的最后一组数据
);


////////////////////////////////////////////////////输入三行img的处理/////////////////////////////////////////////////////////////////
    //取三行数据的9个点出来 （每个点是输入并行通道数的通道数）
    reg [DATA_WIDTH-1 : 0] data_r[2 : 0][2 : 0];
    always @(posedge clk) begin
        //第0行的三个数（最后的data_0是第三个数）
        data_r[0][2] <= s_data_0         ;
        data_r[0][1] <= data_r[0][2]     ;
        data_r[0][0] <= data_r[0][1]     ;

        //第1行的三个数（最后的data_1是第三个数）
        data_r[1][2] <= s_data_1         ;
        data_r[1][1] <= data_r[1][2]     ;
        data_r[1][0] <= data_r[1][1]     ;

        //第2行的三个数（最后的data_2是第三个数）
        data_r[2][2] <= s_data_2         ;
        data_r[2][1] <= data_r[2][2]     ;
        data_r[2][0] <= data_r[2][1]     ;
    end

    reg [DATA_WIDTH-1 : 0] data[2 : 0][2 : 0];
    always @(posedge clk) begin
        data[0][2] <= data_r[0][2]; 
        data[0][1] <= data_r[0][1];
        data[0][0] <= data_r[0][0];

        data[1][2] <= data_r[1][2]; 
        data[1][1] <= data_r[1][1];
        data[1][0] <= data_r[1][0];

        data[2][2] <= data_r[2][2]; 
        data[2][1] <= data_r[2][1];
        data[2][0] <= data_r[2][0];
    end

////////////////////////////////////////////////////输入九个weight的处理/////////////////////////////////////////////////////////////////
    //与conv33_weight中的一致 就是指出有几个卷积核在使用
    reg [$clog2(CHA_PAR_OUT)-1 : 0] kernel_cnt;
    always @(posedge clk) begin
        if(rst) begin
            kernel_cnt <= 0;
        end
        else if(weight_valid) begin
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
        else if(weight_last) begin
            w_ctl <= !w_ctl;
        end
    end

    //（每个点是输入并行通道数的通道数）  输出并行通道数个          行      列
    reg [DATA_WIDTH-1 : 0] weight_mem_ping[CHA_PAR_OUT-1 : 0][2 : 0][2 : 0];
    reg [DATA_WIDTH-1 : 0] weight_mem_pang[CHA_PAR_OUT-1 : 0][2 : 0][2 : 0];

    always @(posedge clk ) begin
        if(weight_valid)begin

            if(w_ctl == 1'b0) begin
                weight_mem_ping[kernel_cnt][0][0] <= weight_0;
                weight_mem_ping[kernel_cnt][0][1] <= weight_1;
                weight_mem_ping[kernel_cnt][0][2] <= weight_2;

                weight_mem_ping[kernel_cnt][1][0] <= weight_3;
                weight_mem_ping[kernel_cnt][1][1] <= weight_4;
                weight_mem_ping[kernel_cnt][1][2] <= weight_5;

                weight_mem_ping[kernel_cnt][2][0] <= weight_6;
                weight_mem_ping[kernel_cnt][2][1] <= weight_7;
                weight_mem_ping[kernel_cnt][2][2] <= weight_8;
            end       
            else begin
                weight_mem_pang[kernel_cnt][0][0] <= weight_0;
                weight_mem_pang[kernel_cnt][0][1] <= weight_1;
                weight_mem_pang[kernel_cnt][0][2] <= weight_2;

                weight_mem_pang[kernel_cnt][1][0] <= weight_3;
                weight_mem_pang[kernel_cnt][1][1] <= weight_4;
                weight_mem_pang[kernel_cnt][1][2] <= weight_5;

                weight_mem_pang[kernel_cnt][2][0] <= weight_6;
                weight_mem_pang[kernel_cnt][2][1] <= weight_7;
                weight_mem_pang[kernel_cnt][2][2] <= weight_8;
            end

        end
    end

    wire mul_last;
    ////////乒乓处理//////
    //读乒乓
    reg r_ctl;
    always @(posedge clk) begin
        if(rst) begin
            r_ctl <= 1'b0;
        end
        else if(start) begin
            r_ctl <= 1'b0;
        end
        else if(mul_last) begin
            r_ctl <= !r_ctl;
        end
    end

    /////////weight的读出////////      输入通道并行度      输出通道并行度      行     列
    reg [INT-1 : 0] weight_data[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0][0 : 2][0 : 2];
    // wire [INT-1 : 0] weight_data_0_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_0_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_0_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_1_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_1_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_1_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_2_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_2_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [INT-1 : 0] weight_data_2_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    
    genvar i, j, l;
    generate
        for(i = 0; i < CHA_PAR_IN; i = i + 1) begin: WIGHT_I
            for(j = 0; j < CHA_PAR_OUT; j = j + 1) begin: WIGHT_J
                always @(posedge clk) begin
                    weight_data[i][j][0][0] <= (r_ctl == 1'b0) ? weight_mem_ping[j][0][0][i*INT +: INT] : weight_mem_pang[j][0][0][i*INT +: INT];
                    weight_data[i][j][0][1] <= (r_ctl == 1'b0) ? weight_mem_ping[j][0][1][i*INT +: INT] : weight_mem_pang[j][0][1][i*INT +: INT];
                    weight_data[i][j][0][2] <= (r_ctl == 1'b0) ? weight_mem_ping[j][0][2][i*INT +: INT] : weight_mem_pang[j][0][2][i*INT +: INT];

                    weight_data[i][j][1][0] <= (r_ctl == 1'b0) ? weight_mem_ping[j][1][0][i*INT +: INT] : weight_mem_pang[j][1][0][i*INT +: INT];
                    weight_data[i][j][1][1] <= (r_ctl == 1'b0) ? weight_mem_ping[j][1][1][i*INT +: INT] : weight_mem_pang[j][1][1][i*INT +: INT];
                    weight_data[i][j][1][2] <= (r_ctl == 1'b0) ? weight_mem_ping[j][1][2][i*INT +: INT] : weight_mem_pang[j][1][2][i*INT +: INT];

                    weight_data[i][j][2][0] <= (r_ctl == 1'b0) ? weight_mem_ping[j][2][0][i*INT +: INT] : weight_mem_pang[j][2][0][i*INT +: INT];
                    weight_data[i][j][2][1] <= (r_ctl == 1'b0) ? weight_mem_ping[j][2][1][i*INT +: INT] : weight_mem_pang[j][2][1][i*INT +: INT];
                    weight_data[i][j][2][2] <= (r_ctl == 1'b0) ? weight_mem_ping[j][2][2][i*INT +: INT] : weight_mem_pang[j][2][2][i*INT +: INT];
                end
            end
        end
    endgenerate

    




/////////////////////////////////// 乘法输出 //////////////////////////////////////////////////////////
    //9点乘法  CIN * COUT输出    4个周期出结果
    //                      输入通道并行度      输出通道并行度      行     列
    wire [2*INT-1 : 0] mul[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0][0 : 2][0 : 2];
    // wire [2*INT-1 : 0] mul_0_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_0_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_0_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_1_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_1_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_1_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_2_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_2_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    // wire [2*INT-1 : 0] mul_2_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    generate
        for(i = 0; i < CHA_PAR_IN; i = i + 1) begin
            for(j = 0; j < CHA_PAR_OUT/2; j = j + 1) begin
                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_0_0(
                    .clk(clk),
                    .a(weight_data[i][j*2][0][0]  )  ,
                    .b(weight_data[i][j*2+1][0][0])  ,
                    .c(data[0][0][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][0][0]),
                    .b_c(mul[i][j*2+1][0][0])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_0_1(
                    .clk(clk),
                    .a(weight_data[i][j*2][0][1]  )  ,
                    .b(weight_data[i][j*2+1][0][1])  ,
                    .c(data[0][1][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][0][1]),
                    .b_c(mul[i][j*2+1][0][1])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_0_2(
                    .clk(clk),
                    .a(weight_data[i][j*2][0][2]  )  ,
                    .b(weight_data[i][j*2+1][0][2])  ,
                    .c(data[0][2][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][0][2]),
                    .b_c(mul[i][j*2+1][0][2])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_1_0(
                    .clk(clk),
                    .a(weight_data[i][j*2][1][0]  )  ,
                    .b(weight_data[i][j*2+1][1][0])  ,
                    .c(data[1][0][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][1][0]),
                    .b_c(mul[i][j*2+1][1][0])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_1_1(
                    .clk(clk),
                    .a(weight_data[i][j*2][1][1]  )  ,
                    .b(weight_data[i][j*2+1][1][1])  ,
                    .c(data[1][1][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][1][1]),
                    .b_c(mul[i][j*2+1][1][1])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_1_2(
                    .clk(clk),
                    .a(weight_data[i][j*2][1][2]  )  ,
                    .b(weight_data[i][j*2+1][1][2])  ,
                    .c(data[1][2][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][1][2]),
                    .b_c(mul[i][j*2+1][1][2])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_2_0(
                    .clk(clk),
                    .a(weight_data[i][j*2][2][0]  )  ,
                    .b(weight_data[i][j*2+1][2][0])  ,
                    .c(data[2][0][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][2][0]),
                    .b_c(mul[i][j*2+1][2][0])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_2_1(
                    .clk(clk),
                    .a(weight_data[i][j*2][2][1]  )  ,
                    .b(weight_data[i][j*2+1][2][1])  ,
                    .c(data[2][1][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][2][1]),
                    .b_c(mul[i][j*2+1][2][1])    
                );


                conv_mul_E2 #(
                    .INT(INT),
                    .MUL_DELAY(MUL_DELAY)
                )
                conv_mul_inst_2_2(
                    .clk(clk),
                    .a(weight_data[i][j*2][2][2]  )  ,
                    .b(weight_data[i][j*2+1][2][2])  ,
                    .c(data[2][2][i*INT +: INT])  ,
                    .a_c(mul[i][j*2][2][2]),
                    .b_c(mul[i][j*2+1][2][2])    
                );
 
            end
        end
    endgenerate

/////////////////////////////////// 加法输出 //////////////////////////////////////////////////////////
    //9点相加    ///////////2周期输出///////////    ///////////多4个位宽///////
    reg [2*INT+1 : 0] add_0[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    reg [2*INT+1 : 0] add_1[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    reg [2*INT+1 : 0] add_2[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];
    reg [2*INT+3 : 0] add_33[CHA_PAR_IN-1 : 0][CHA_PAR_OUT-1 : 0];     //3*3卷积点的+法和   i的通道 j是核  
    generate
        for(i = 0; i < CHA_PAR_IN; i = i+1) begin: ADD_PIPE_0_I
            for(j = 0; j < CHA_PAR_OUT; j = j+1) begin: ADD_PIPE_0_J
                always @(posedge clk ) begin
                    if(type == 1'b0) begin
                        //一拍
                        add_0[i][j] <= $signed(mul[i][j][0][0]) + $signed(mul[i][j][0][1]) + $signed(mul[i][j][0][2]);
                        add_1[i][j] <= $signed(mul[i][j][1][0]) + $signed(mul[i][j][1][1]) + $signed(mul[i][j][1][2]);
                        add_2[i][j] <= $signed(mul[i][j][2][0]) + $signed(mul[i][j][2][1]) + $signed(mul[i][j][2][2]);
                        //两拍
                        add_33[i][j] <= $signed(add_0[i][j]) + $signed(add_1[i][j]) + $signed(add_2[i][j]);  
                    end
                    // else begin
                    //     //一拍
                    //     add_33[i][j][0] <= $signed(mul[i][j][0][0]);  
                    //     add_33[i][j][1] <= $signed(mul[i][j][0][1]); 
                    //     add_33[i][j][2] <= $signed(mul[i][j][0][2]); 
                    //     add_33[i][j][3] <= $signed(mul[i][j][1][0]); 
                    //     add_33[i][j][4] <= $signed(mul[i][j][1][1]); 
                    //     add_33[i][j][5] <= $signed(mul[i][j][1][2]); 
                    //     add_33[i][j][6] <= $signed(mul[i][j][2][0]); 
                    //     add_33[i][j][7] <= $signed(mul[i][j][2][1]); 
                    //     add_33[i][j][8] <= $signed(mul[i][j][2][2]);
                    // end
                     
                end
            end
        end
    endgenerate

    // //每个核的 输入通道点相加    ///////////$clog2(CHA_PAR_IN)周期输出///////////
    // generate
    //     //核的编号
    //     for(genvar j = 0; j < CHA_PAR_OUT; j = j+1) begin: KERNEL
    //         //层级
    //         for(genvar l = 0; l < $clog2(CHA_PAR_IN); l = l+1) begin: ADD_LAYER
    //         //层级的通道相加
    //             for(genvar i = 0; i < (CHA_PAR_IN >> (l+1)); i = i+1) begin: ADD_LAYER_CIN

    //                 //      加法后的位宽                   层级                      通道数                      核数                            
    //                 reg [2*INT+4 + l : 0] add_cin[$clog2(CHA_PAR_IN)-1 : 0][(CHA_PAR_IN >> (l+1)) -1 : 0][CHA_PAR_OUT-1 : 0];
    //                 if(l == 0) begin       //第一层级生成前一级的+和
    //                     always @(posedge clk) begin
    //                         add_cin[l][i][j][2*INT+4+l : 0] <= $signed(add_33[i*2][j]) + $signed(add_33[i*2+1][j]); 
    //                     end
    //                 end
    //                 else begin             //后面层级生成前一级的+和
    //                     always @(posedge clk) begin
    //                         add_cin[l][i][j][2*INT+4+l : 0] <= $signed(add_cin[l-1][i*2][j]) + $signed(add_cin[l-1][i*2+1][j]);
    //                     end
    //                 end
                    
    //             end
    //         end
    //     end
    // endgenerate

    ///////每个核的 输入通道点相加 /////   ///////////$clog2(CHA_PAR_IN)周期输出/////////// 
    //                                        层级                      通道                   核数         
    reg [OUT_DATA_WIDTH-1 : 0] add_cin[0 : $clog2(CHA_PAR_IN)-1][0 : (CHA_PAR_IN >> 1)-1][0 : CHA_PAR_OUT-1];
    generate
        //核的编号
        for(j = 0; j < CHA_PAR_OUT; j = j+1) begin: KERNEL
            //层级
            for(l = 0; l < $clog2(CHA_PAR_IN); l = l+1) begin: LAYER
            //层级的通道相加
                for(i = 0; i < (CHA_PAR_IN >> (l+1)); i = i+1) begin: ADD_CIN
                    
                    if(l == 0) begin
                        always @(posedge clk) begin
                            if(type == 1'b0) begin
                                add_cin[l][i][j] <= $signed(add_33[i*2][j]) + $signed(add_33[i*2+1][j]); 
                            end
                            else begin
                                add_cin[l][i][j] <= $signed(mul[i*2][j][1][1]) + $signed(mul[i*2+1][j][1][1]);
                            end
                        end
                    end
                    else begin
                        always @(posedge clk) begin
                            add_cin[l][i][j] <= $signed(add_cin[l-1][i*2][j]) + $signed(add_cin[l-1][i*2+1][j]);
                        end
                    end


                end
            end
        end
    endgenerate



    
/////////////////////////////////// 结算结果输出 //////////////////////////////////////////////////////////              
    //数组重排
    generate
        for(j = 0; j < CHA_PAR_OUT; j = j+1) begin: OUT_PUT
                                                                    //        最后一层级     第1个通道     第几个核
                assign m_data[j*OUT_DATA_WIDTH +: OUT_DATA_WIDTH] = add_cin[$clog2(CHA_PAR_IN)-1][0][j]; 
        end
    endgenerate              
    
    // //先写了8个输出并行度  后面改
    // assign m_data_0 = m_data[0];
    // assign m_data_1 = m_data[1];
    // assign m_data_2 = m_data[2];
    // assign m_data_3 = m_data[3];
    // assign m_data_4 = m_data[4];
    // assign m_data_5 = m_data[5];
    // assign m_data_6 = m_data[6];
    // assign m_data_7 = m_data[7];

/////////////////////////////////// 数据信号 //////////////////////////////////////////////////////////
    //多周期延迟  （以下代码与所有周期延迟有关）  //1拍的数据进入延迟/weight广播延迟 + 3拍数据延迟 + 4拍乘法器延迟 + 2拍3*3点加法延迟 + $clog2(CHA_PAR_IN)拍输入并行通道相加延迟
    localparam DELAY = 1 + 3 + MUL_DELAY + 2 + $clog2(CHA_PAR_IN);
    reg [DELAY-1-2 : 0] data_valid_d, data_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            data_valid_d <= 0;
            data_last_d <= 0;
        end
        else begin
            data_valid_d <= {data_valid_d[DELAY-2-2 : 0], s_valid};
            data_last_d  <= {data_last_d[DELAY-2-2 : 0] , s_last};
        end
    end

    //一行中最后一个数被使用 也就是data[0][2] <= data_0这一拍就使用了  //看文档 5.12
    assign mul_last = data_last_d[0];
    
    //如果valid的进来的太快就要计数行数3要记录2 避免延迟的valid和刚进来的valid重合误valid
    // reg [1 : 0] delay_cnt_33;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         delay_cnt_33 <= 0;
    //     end
    //     else if(data_last_d[(DELAY-2)-1]) begin
    //         delay_cnt_33 <= 0;
    //     end
    //     else if(delay_cnt_33 == 2) begin
    //         delay_cnt_33 <= delay_cnt_33;
    //     end
    //     else if(data_valid_d[(DELAY-2)-1]) begin
    //         delay_cnt_33 <= delay_cnt_33 + 1;
    //     end
    // end


    reg [1 : 0] delay_cnt;
    always @(posedge clk) begin
        if(rst) begin
            delay_cnt <= 0;
        end
        else if((type && data_last_d[(DELAY-2)-1-2]) || (!type && data_last_d[(DELAY-2)-1])) begin
            delay_cnt <= 0;
        end
        else if(delay_cnt == 2) begin
            delay_cnt <= delay_cnt;
        end
        else if((type && data_valid_d[(DELAY-2)-1-2]) || (!type && data_valid_d[(DELAY-2)-1])) begin
            delay_cnt <= delay_cnt + 1;
        end
    end


    //计算完成信号输出   （文档有解释）
    //3拍数据延迟 + 4拍乘法器延迟 + 2拍3*3点加法延迟 + $clog2(CHA_PAR_IN)拍输入并行通道相加延迟     (1*1没有2拍3*3带你加法延迟)
    // assign m_valid = type ? data_valid_d[DELAY-1-2] & data_valid_d[(DELAY-2)-1-2] : data_valid_d[DELAY-1] & data_valid_d[(DELAY-2)-1];

    assign m_valid = type ? data_valid_d[(DELAY-2)-1-2] && (delay_cnt == 2) : data_valid_d[(DELAY-2)-1] && (delay_cnt == 2);
    //1拍数据延迟 + 4拍乘法器延迟 + 2拍3*3点加法延迟 + $clog2(CHA_PAR_IN)拍输入并行通道相加延迟     (1*1没有2拍3*3带你加法延迟)
    assign m_last  = type ? data_last_d[(DELAY-2)-1-2] : data_last_d[(DELAY-2)-1];

endmodule



