module cat_add #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              INT = 8,
              DATA_WIDTH = CHA_PAR_IN * INT,             //数据传输位宽    输入并行度 * INT8
              //尺度位宽//
              SCALE_WIDTH = 16,                          //scale的位数
              SCALE_FRACTION_WIDTH = 15,                 //scale的小数位数
              //乘法器延迟
              MUL_DELAY = 4

)
(
    input         clk         ,
    input         rst         ,

    input         start       ,

    //尺度与zero
    input  [SCALE_WIDTH-1 : 0] scale_1,
    input  [SCALE_WIDTH-1 : 0] scale_2,
    input  [SCALE_WIDTH*2-1 : 0] scale_3,           //16位小数 32位数（16位小 + 16位整）
    input  [INT-1 : 0] zero_1        ,
    input  [INT-1 : 0] zero_2        ,


    input [DATA_WIDTH-1 : 0] s_data_0  ,
    input [DATA_WIDTH-1 : 0] s_data_1  ,
    input                    s_valid_0 ,
    input                    s_valid_1 ,
    input                    s_last    ,


    output [DATA_WIDTH-1 : 0]  m_data  ,
    output                     m_valid ,
    output                     m_last


);


    integer i;
// //////////////////////////启动数据///////////////////////////////////////
//     reg [INT-1 : 0] zero[0 : 1];
//     reg [SCALE_WIDTH-1 : 0] scale[0 : 1];
//     reg [SCALE_WIDTH*2-1 : 0] scale_add;            //当前模块scale
//     always @(posedge clk) begin
//         if(start) begin
//             scale[0] <= scale_1;
//             scale[1] <= scale_2;
//             scale_add <= scale_3;
//             zero[0]  <= zero_1 ;
//             zero[1]  <= zero_2 ;
//         end
//     end

////////////////////////////数据延迟/////////////////////////////////////////
    //scale_1 2 多周期延迟写法
    localparam SCALE_DELAY = 1;
    reg [SCALE_WIDTH-1 : 0] scale_d[0 : 1][0 : SCALE_DELAY-1];

    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < SCALE_DELAY; i = i + 1) begin
                scale_d[0][i] <= 0;
            end
        end
        else begin
            if(s_valid_0) begin
               scale_d[0][0] <= scale_1; 
            end
            for (i = 1; i < SCALE_DELAY; i = i + 1) begin
                scale_d[0][i] <= scale_d[0][i-1];
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < SCALE_DELAY; i = i + 1) begin
                scale_d[1][i] <= 0;
            end
        end
        else begin
            if(s_valid_1) begin
               scale_d[1][0] <= scale_2; 
            end
            for (i = 1; i < SCALE_DELAY; i = i + 1) begin
                scale_d[1][i] <= scale_d[1][i-1];
            end
        end
    end



    //scale_3 多周期延迟写法
    //一拍减法延迟 + scale1——2乘法器延迟 + 一拍加法延迟
    localparam SCALE_3_DELAY = 1 + MUL_DELAY + 1;
    reg [SCALE_WIDTH*2-1 : 0] scale_3_d[0 : SCALE_3_DELAY-1];
    always @(posedge clk) begin
        if(rst) begin
            for (i = 0; i < SCALE_3_DELAY; i = i + 1) begin
                scale_3_d[i] <= 0;
            end
        end
        else begin
            scale_3_d[0] <= scale_3;
            for (i = 1; i < SCALE_3_DELAY; i = i + 1) begin
                scale_3_d[i] <= scale_3_d[i-1];
            end
        end
    end


/////////////////////////////////数据减掉zero    1周期////////////////////////////////
    //                          通道数       需要减去zero的数据数量
    reg [INT-1 : 0] sub_zero[CHA_PAR_IN-1 : 0][0 : 1];
    generate 
        for (genvar i = 0; i < CHA_PAR_IN; i = i + 1) begin
            //sub_s_data_0
            always @(posedge clk) begin
                if(s_valid_0) begin
                    if(s_data_0[i * 8 +: 8] < zero_1) begin                //数据修正到非负
                        sub_zero[i][0] <= {INT{1'b0}};
                    end
                    else begin
                        sub_zero[i][0] <= s_data_0[i * 8 +: 8] - zero_1;
                    end
                end
            end
            //sub_s_data_1
            always @(posedge clk) begin
                if(s_valid_1) begin
                    if(s_data_1[i * 8 +: 8] < zero_2) begin                //数据修正到非负
                        sub_zero[i][1] <= {INT{1'b0}};
                    end
                    else begin
                        sub_zero[i][1] <= s_data_1[i * 8 +: 8] - zero_2;
                    end
                end
            end
        end
    endgenerate

///////////////////////////////////////////数据反量化   MUL_DELAY周期//////////////////////////////////////////////////////
    wire [INT+SCALE_WIDTH-1 : 0] scale_sub[CHA_PAR_IN-1 : 0][0 : 1];
    generate
        for (genvar i = 0; i < CHA_PAR_IN; i = i + 1) begin
            scale_mul_unsign #(
                .DATA_WIDTH(INT),
                .SCALE_WIDTH(SCALE_WIDTH),
                .DELAY(MUL_DELAY)
            )
            scale_mul_unsign_0(
                .clk(clk),
                .A(sub_zero[i][0]),
                .B(scale_d[0][SCALE_DELAY-1]),
                .P(scale_sub[i][0])
            );


            scale_mul_unsign #(
                .DATA_WIDTH(INT),
                .SCALE_WIDTH(SCALE_WIDTH),
                .DELAY(MUL_DELAY)
            )
            scale_mul_unsign_1(
                .clk(clk),
                .A(sub_zero[i][1]),
                .B(scale_d[1][SCALE_DELAY-1]),
                .P(scale_sub[i][1])
            );

        end
    endgenerate

///////////////////////////////////////////ADD计算    1周期//////////////////////////////////////////////////////
    localparam CAT_DELAY = SCALE_3_DELAY - 1;
    reg [CAT_DELAY-1 : 0] s_valid_0_d, s_valid_1_d; 
    always @(posedge clk) begin
        if(rst) begin
            s_valid_0_d <= 0;
            s_valid_1_d <= 0;
        end
        else begin
            s_valid_0_d <= {s_valid_0_d[CAT_DELAY-1 : 0] , s_valid_0};
            s_valid_1_d <= {s_valid_1_d[CAT_DELAY-1 : 0] , s_valid_1};
        end
    end

    reg [INT+SCALE_WIDTH : 0] add_data[CHA_PAR_IN-1 : 0];
    generate
        for (genvar i = 0; i < CHA_PAR_IN; i = i + 1) begin
            always @(posedge clk) begin
                if(s_valid_0_d[CAT_DELAY-1] & s_valid_1_d[CAT_DELAY-1]) begin
                    add_data[i] <= scale_sub[i][0] + scale_sub[i][1];
                end
                else if(s_valid_0_d[CAT_DELAY-1]) begin
                    add_data[i] <= scale_sub[i][0];
                end
                else if(s_valid_1_d[CAT_DELAY-1]) begin
                    add_data[i] <= scale_sub[i][1];
                end
            end
        end
    endgenerate


/////////////////////////////////////////重新量化 数据3    MUL_DELAY周期//////////////////////////////////////
    wire [SCALE_WIDTH*2 + INT+SCALE_WIDTH : 0] q3[CHA_PAR_IN-1 : 0];
    generate
        for (genvar i = 0; i < CHA_PAR_IN; i = i + 1) begin
            scale_mul_unsign #(
                .DATA_WIDTH(INT+SCALE_WIDTH+1),
                .SCALE_WIDTH(SCALE_WIDTH*2),
                .DELAY(MUL_DELAY)
            )
            scale_mul_unsign_3(
                .clk(clk),
                .A(add_data[i]),
                .B(scale_3_d[SCALE_3_DELAY-1]),
                .P(q3[i])
            );


            // mult_gen_0 mult_gen_3333(
            //     .CLK(clk),
            //     .A(add_data[i]),
            //     .B(scale_3_d[SCALE_3_DELAY-1]),
            //     .P(q3[i])
            // );
        end
    endgenerate


/////////////////////////////////////////数据截断    1周期//////////////////////////////////////
    reg [INT-1 : 0] m_data_r[CHA_PAR_IN-1 : 0];
    generate
        for (genvar i = 0; i < CHA_PAR_IN; i = i + 1) begin

            always @(posedge clk) begin 
                if(q3[i][SCALE_WIDTH*2 + INT+SCALE_WIDTH : SCALE_FRACTION_WIDTH*2] >= 8'd255) begin
                    m_data_r[i] <= 8'd255;
                end
                else begin
                    m_data_r[i] <= q3[i][SCALE_FRACTION_WIDTH*2 + INT-1 : SCALE_FRACTION_WIDTH*2] + q3[i][SCALE_FRACTION_WIDTH*2-1];
                end
            end

        end
    endgenerate

 //////////////////////////////////////数据拼接输出////////////////////////////////////////
    generate
        for (genvar i = 0; i < CHA_PAR_IN; i = i+1) begin
            assign m_data[i*8 +: 8] = m_data_r[i];
        end
    endgenerate

/////////////////////////////////输出数据信号延迟////////////////////////////////
    //输出信号延迟  是所有计算结束延迟 (scale3延迟 + scale3的乘法器延迟 + 1拍数据截断)
    localparam ALL_DELAY = SCALE_3_DELAY + MUL_DELAY + 1;
    reg [ALL_DELAY-1 : 0] s_valid_d, s_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            s_valid_d <= 0;
            s_last_d <= 0;
        end
        else begin
            s_valid_d <= {s_valid_d[ALL_DELAY-1 : 0] , (s_valid_1 | s_valid_0)};
            s_last_d  <= {s_last_d[ALL_DELAY-1 : 0]  , s_last};
        end
    end

    assign m_valid = s_valid_d[ALL_DELAY-1];
    assign m_last = s_last_d[ALL_DELAY-1];



endmodule