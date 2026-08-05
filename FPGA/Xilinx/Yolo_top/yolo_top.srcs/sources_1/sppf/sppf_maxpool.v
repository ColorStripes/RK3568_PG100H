module sppf_maxpool #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = CHA_PAR_IN,                  //输出通道并行度
              INT = 8,                                   //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT              //数据传输位宽    输入并行度 * INT8
)
(
    input          clk         ,
    input          rst         ,


    //img数据的传输(5行)
    input [DATA_WIDTH-1 : 0] s_data_0      ,
    input [DATA_WIDTH-1 : 0] s_data_1      ,
    input [DATA_WIDTH-1 : 0] s_data_2      ,
    input [DATA_WIDTH-1 : 0] s_data_3      ,
    input [DATA_WIDTH-1 : 0] s_data_4      ,
    input                    s_valid       ,
    input                    s_last        ,

    

    output [DATA_WIDTH-1 : 0]  m_data   ,
    output                     m_valid  ,
    output                     m_last 

);


////////////////////////////////////////////////////输入5行img的处理/////////////////////////////////////////////////////////////////
    //取5行数据的25个点出来 （每个点是输入并行通道数的通道数）   5拍
    reg [DATA_WIDTH-1 : 0] data[4 : 0][4 : 0];
    always @(posedge clk) begin
        //第0行的5个数（最后的data_0是第5个数）
        data[0][4] <= s_data_0       ;
        data[0][3] <= data[0][4]     ;
        data[0][2] <= data[0][3]     ;
        data[0][1] <= data[0][2]     ;
        data[0][0] <= data[0][1]     ;

        //第1行的5个数（最后的data_1是第5个数）
        data[1][4] <= s_data_1       ;
        data[1][3] <= data[1][4]     ;
        data[1][2] <= data[1][3]     ;
        data[1][1] <= data[1][2]     ;
        data[1][0] <= data[1][1]     ;

        //第2行的5个数（最后的data_2是第5个数）
        data[2][4] <= s_data_2       ;
        data[2][3] <= data[2][4]     ;
        data[2][2] <= data[2][3]     ;
        data[2][1] <= data[2][2]     ;
        data[2][0] <= data[2][1]     ;

        //第3行的5个数（最后的data_3是第5个数）
        data[3][4] <= s_data_3       ;
        data[3][3] <= data[3][4]     ;
        data[3][2] <= data[3][3]     ;
        data[3][1] <= data[3][2]     ;
        data[3][0] <= data[3][1]     ;

        //第4行的5个数（最后的data_4是第5个数）
        data[4][4] <= s_data_4       ;
        data[4][3] <= data[4][4]     ;
        data[4][2] <= data[4][3]     ;
        data[4][1] <= data[4][2]     ;
        data[4][0] <= data[4][1]     ;
    end


/////////////////////////////////// maxpooling计算 //////////////////////////////////////////////////////////
    //一行中的比较      1拍
    //                     第几行   通道数          
    reg [INT-1 : 0] max_col[0 : 4][0 : CHA_PAR_IN-1];
    generate
        for(genvar i = 0; i < CHA_PAR_IN; i = i+1) begin: CHA_0

            for(genvar j = 0; j < 5; j = j+1) begin : LANE
                always @(posedge clk) begin
                    if( (data[j][0][i*INT +: INT] >= data[j][1][i*INT +: INT]) && (data[j][0][i*INT +: INT] >= data[j][2][i*INT +: INT]) && (data[j][0][i*INT +: INT] >= data[j][3][i*INT +: INT]) && (data[j][0][i*INT +: INT] >= data[j][4][i*INT +: INT]) ) begin
                        max_col[j][i] <= data[j][0][i*INT +: INT];
                    end
                    else if( (data[j][1][i*INT +: INT] >= data[j][2][i*INT +: INT]) && (data[j][1][i*INT +: INT] >= data[j][3][i*INT +: INT]) && (data[j][1][i*INT +: INT] >= data[j][4][i*INT +: INT]) ) begin
                        max_col[j][i] <= data[j][1][i*INT +: INT];
                    end
                    else if( (data[j][2][i*INT +: INT] >= data[j][3][i*INT +: INT]) && (data[j][2][i*INT +: INT] >= data[j][4][i*INT +: INT]) ) begin
                        max_col[j][i] <= data[j][2][i*INT +: INT];
                    end
                    else if( (data[j][3][i*INT +: INT] >= data[j][4][i*INT +: INT]) ) begin
                        max_col[j][i] <= data[j][3][i*INT +: INT];
                    end
                    else begin
                        max_col[j][i] <= data[j][4][i*INT +: INT];
                    end
                end
            end

        end
    endgenerate


    //五行中比较      1拍
    //                          通道数          
    reg [INT-1 : 0] max_row[0 : CHA_PAR_IN-1];
    generate
        for(genvar i = 0; i < CHA_PAR_IN; i = i+1) begin: CHA_1

            always @(posedge clk) begin
                if( (max_col[0][i] >= max_col[1][i]) && (max_col[0][i] >= max_col[2][i]) && (max_col[0][i] >= max_col[3][i]) && (max_col[0][i] >= max_col[4][i]) ) begin
                    max_row[i] <= max_col[0][i];
                end
                else if( (max_col[1][i] >= max_col[2][i]) && (max_col[1][i] >= max_col[3][i]) && (max_col[1][i] >= max_col[4][i]) ) begin
                    max_row[i] <= max_col[1][i];
                end
                else if( (max_col[2][i] >= max_col[3][i]) && (max_col[2][i] >= max_col[4][i]) ) begin
                    max_row[i] <= max_col[2][i];
                end
                else if( (max_col[3][i] >= max_col[4][i]) ) begin
                    max_row[i] <= max_col[3][i];
                end
                else begin
                    max_row[i] <= max_col[4][i];
                end
            end

        end
    endgenerate


    
/////////////////////////////////// 结算结果输出 //////////////////////////////////////////////////////////              
    //数组重排
    generate
        for(genvar j = 0; j < CHA_PAR_OUT; j = j+1) begin: OUT_PUT
                assign m_data[j*INT +: INT] = max_row[j]; 
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
    //多周期延迟  （以下代码与所有周期延迟有关）  //5拍数据延迟 + 2拍maxpooling计算延迟
    localparam DELAY = 5 + 2;
    reg [DELAY-1-4 : 0] data_valid_d, data_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            data_valid_d <= 0;
            data_last_d <= 0;
        end
        else begin
            data_valid_d <= {data_valid_d[DELAY-2-4 : 0], s_valid};
            data_last_d  <= {data_last_d[DELAY-2-4 : 0] , s_last};
        end
    end

    //如果valid的进来的太快就要计数行数5要记录4 避免延迟的valid和刚进来的valid重合误valid
    reg [2 : 0] delay_cnt;
    always @(posedge clk) begin
        if(rst) begin
            delay_cnt <= 0;
        end
        else if(data_last_d[(DELAY-4)-1]) begin
            delay_cnt <= 0;
        end
        else if(delay_cnt == 4) begin
            delay_cnt <= delay_cnt;
        end
        else if(data_valid_d[(DELAY-4)-1]) begin
            delay_cnt <= delay_cnt + 1;
        end
    end
    
    //计算完成信号输出   （文档有解释）
    //（1拍数据延迟 + 2拍maxpooling计算延迟） & （1拍数据延迟 + 相对1拍数据延迟的 4拍数据延迟填充）
    assign m_valid = data_valid_d[(DELAY-4)-1] && (delay_cnt == 4);
    // 1拍数据延迟 + 2拍maxpooling计算延迟
    assign m_last  = data_last_d[(DELAY-4)-1];

endmodule



