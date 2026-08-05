module conv_ctrl #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              CHA_PAR_OUT = 8,                           //输出通道并行度
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
              CHA_IMG_OUT = 256,                         //输出的IMG的最大通道数
                          
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM),
              MAX_OUT_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),             //输出通道计算次数=输出通道数/输出并行度 
              CALULATE_NUM = MAX_IN_CALULATE_NUM * MAX_OUT_CALULATE_NUM,      //总通道计算次数=输入通道计算次数 * 输出通道计算次数 
              CALULATE_CNT_WIDTH = $clog2(CALULATE_NUM),
              MUL_DELAY = 4                                //conv乘法器延迟
)
(
    input          clk          ,
    input          rst          ,

    input          type         ,
    input          start        ,
    input          stride       ,

    input [ROW_WIDTH : 0]              row_num           ,
    input [CALULATE_CNT_WIDTH : 0]     calculate_num     ,
    input [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num ,      //输入计算次数 


    input          data_valid   ,
    input          data_last    ,
    output         data_req     ,               //向conv33_in_ctrl请求三行数据

    input          weight_valid ,
    input          weight_last  ,
    output         weight_req   ,

    input          bias_valid   ,
    input          bias_last    ,
    output         bias_req     ,


    input          calculate_req   ,            //说明计算模块可以接受新的计算数据 请求给数据
    output         calculate_first   ,
    output         calculate_last    ,
    
    // input          mul_last,      /////////////////  mul计算最后一组了 
    input          add_last,       /////////////////  bias被使用完最后一组了

    output reg     calculate_end
);






    //状态机
    localparam IDLE = 3'b001, WAIT = 3'b010, CALCULATE = 3'b100;
    reg [2 : 0] state, next_state;
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
                    next_state = WAIT;
                end
                else begin
                    next_state = IDLE;
                end
            end
            WAIT:begin                                            //等待数据准备好模块
                if(calculate_end) begin
                    next_state = IDLE;
                end
                else if(calculate_req & weight_ready) begin
                    next_state = CALCULATE;
                end
                else begin
                    next_state = WAIT;
                end
            end
            CALCULATE:begin                                        //计算模块
                if(data_last) begin               
                    next_state = WAIT;
                end
                else begin
                    next_state = CALCULATE;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end



////////////////////////////////// 计算所需数据请求 /////////////////////////////////////////////
    //向conv33_in_ctrl请求三行img数据
    reg data_req_r;
    always @(posedge clk) begin
        if(rst) begin
            data_req_r <= 1'b0;
        end
        else if((state == WAIT) && (next_state == CALCULATE))begin
            data_req_r <= 1'b1;
        end
        else if(data_req & data_valid)begin
            data_req_r <= 1'b0;
        end
    end
    assign data_req = data_req_r;
    


    //weight的实际拥有的有效个数(乒乓的个数)
    reg [1 : 0] weight_cnt;
    always @(posedge clk) begin
        if(rst) begin
            weight_cnt <= 2'd0;
        end
        else if(state == IDLE) begin
            weight_cnt <= 2'd0;
        end
        else begin
            weight_cnt <= weight_cnt + weight_last - data_last;
        end
    end
    //请求权重数据
    reg weight_req_r;
    always @(posedge clk) begin
        if(rst) begin
            weight_req_r <= 1'b0;
        end
        else if(state == IDLE) begin
            weight_req_r <= 1'b0;
        end
        else if(!weight_req_r & !weight_valid) begin
            if(weight_cnt < 2'd2) begin                         //乒乓2组权重   就是乒乓有空的时候
                weight_req_r <= 1'b1;
            end
        end
        else if(weight_req & weight_valid)begin
            weight_req_r <= 1'b0;
        end
    end
    assign weight_req = weight_req_r;

    //bias的实际拥有的有效个数(乒乓的个数)
    reg [1 : 0] bias_cnt;
    always @(posedge clk) begin
        if(rst) begin
            bias_cnt <= 2'd0;
        end
        else if(state == IDLE) begin
            bias_cnt <= 2'd0;
        end
        else begin
            bias_cnt <= bias_cnt + bias_last - add_last;
        end
    end
    //请求bias数据
    reg bias_req_r;
    always @(posedge clk) begin
        if(rst) begin
            bias_req_r <= 1'b0;
        end
        else if(state == IDLE) begin
            bias_req_r <= 1'b0;
        end
        else if(!bias_req_r & !bias_valid) begin
            if((bias_cnt < 2'd2) & (weight_cnt > 2'd0)) begin                         //当bias已经写入总RAM是才能读请求
                bias_req_r <= 1'b1;
            end
        end
        else if(bias_req & bias_valid)begin
            bias_req_r <= 1'b0;
        end
    end
    assign bias_req = bias_req_r;



///////////////////////////////////////// 计算信号相关(发送到ADD计算单元的信号) ///////////////////////////////////////////////////
    wire calc_first = (calculate_cin_cnt == 0) & data_valid;                         //输入通道计算次数的头一次计算
    wire calc_last  = (calculate_cin_cnt == calculate_cin_num_r) & data_valid;       //输入通道计算次数的最后一次计算

    //多周期延迟  （以下代码与conv的延迟时间有关）
    //1拍的数据进入延迟/weight广播延迟 + 3拍数据延迟 + 4拍乘法器延迟 + 2拍3*3点加法延迟 + $clog2(CHA_PAR_IN)拍输入并行通道相加延迟
    localparam DELAY = 1 + 3 + MUL_DELAY + 2 + $clog2(CHA_PAR_IN);
    reg [DELAY-1 : 0] calculate_first_d, calculate_last_d; 
    always @(posedge clk) begin
        if(rst) begin
            calculate_first_d <= 0;
            calculate_last_d <= 0;
        end
        else begin
            calculate_first_d  <= {calculate_first_d[DELAY-1 : 0], calc_first};
            calculate_last_d <= {calculate_last_d[DELAY-1 : 0], calc_last};
        end
    end

    assign calculate_first = type ? calculate_first_d[DELAY-1-2] & calculate_first_d[(DELAY-2)-1-2] : calculate_first_d[DELAY-1] & calculate_first_d[(DELAY-2)-1];
    assign calculate_last  = type ? calculate_last_d[DELAY-1-2] & calculate_last_d[(DELAY-2)-1-2] : calculate_last_d[DELAY-1] & calculate_last_d[(DELAY-2)-1];




////////////////////////////////// 计算所需数据准备好了的信号 /////////////////////////////////////////////
    //权重准备好了
    // reg weight_ready;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         weight_ready <= 1'b0;
    //     end
    //     else if(weight_cnt >= 2'd1) begin     //有一组权重就可以开始计算
    //         weight_ready <= 1'b1;
    //     end
    //     else begin
    //         weight_ready <= 1'b0;
    //     end
    // end
    wire weight_ready;
    assign weight_ready = (weight_cnt >= 2'd1) ? 1'b1 : 1'b0;


    //全部计算计算结束信号
    // reg calculate_end;
    always @(posedge clk) begin
        if(rst) begin
            calculate_end <= 1'b0;
        end
        else if(state == IDLE) begin
            calculate_end <= 1'b0;
        end
        else if((row_cnt == row_num_r) && (calculate_cnt == calculate_num_r) && data_last) begin
            calculate_end <= 1'b1;
        end
    end


////////////////////////////////// 计算个数相关 /////////////////////////////////////////////  
    //输入计算次数
    reg [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num_r;
    always @(posedge clk) begin
        calculate_cin_num_r <= calculate_cin_num - 1;         //这里这个数字都是在当前last时刻判断 所以要-1
    end
    //对应计数器
    reg [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_cnt;
    always @(posedge clk ) begin
        if(rst) begin
            calculate_cin_cnt <= 0;
        end
        else if(state == IDLE) begin
            calculate_cin_cnt <= 0;
        end
        else if(data_last) begin
            if(calculate_cin_cnt == calculate_cin_num_r) begin
                calculate_cin_cnt <= 0;
            end
            else begin
                calculate_cin_cnt <= calculate_cin_cnt + 1;
            end
        end
    end


    //总的计算次数  （in/par_in * out/par_out)      
    reg [CALULATE_CNT_WIDTH : 0] calculate_num_r;
    always @(posedge clk) begin
        calculate_num_r <= calculate_num - 1;         //这里这个数字都是在当前last时刻判断 所以要-1
    end
    //对应计数器
    reg [CALULATE_CNT_WIDTH : 0] calculate_cnt;
    always @(posedge clk ) begin
        if(state == IDLE) begin
            calculate_cnt <= 0;
        end
        else if(data_last) begin
            if(calculate_cnt == calculate_num_r) begin
                calculate_cnt <= 0;
            end
            else begin
                calculate_cnt <= calculate_cnt + 1'b1;
            end
        end
    end


////////////////////////////////// 行列相关 /////////////////////////////////////////////  
    //行数计数器
    reg [ROW_WIDTH : 0] row_num_r;
    always @(posedge clk) begin
        if(rst) begin
            row_num_r <= 0;
        end
        else if(start)begin
            if(stride) begin
                row_num_r  <= row_num[ROW_WIDTH : 1] - 1'b1;
            end
            else begin
                row_num_r  <= row_num - 1'b1;
            end       
        end
    end
    //对应计数器
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk) begin
        if(state == IDLE) begin
            row_cnt <= 0;
        end
        else if(data_last && (calculate_cnt == calculate_num_r))begin
            row_cnt <= row_cnt + 1'b1;
        end
    end

endmodule