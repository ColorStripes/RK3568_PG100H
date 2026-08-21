module sppf_ctrl #(
    parameter CHA_PAR_IN = 16,                           //输入通道并行度
              MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW),
              CHA_IMG_IN = 128,                          //输入的IMG的最大通道数
                          
              MAX_IN_CALULATE_NUM = (CHA_IMG_IN / CHA_PAR_IN),                //输入通道计算次数=输入通道数/输入并行度 
              IN_CALULATE_CNT_WIDTH = $clog2(MAX_IN_CALULATE_NUM)

)
(
    input          clk          ,
    input          rst          ,

    input          start        ,

    input [ROW_WIDTH : 0]              row_num           ,
    input [IN_CALULATE_CNT_WIDTH : 0]  calculate_cin_num ,      //输入计算次数 


    input          s_valid   ,
    input          s_last    ,
    output         s_req     ,              //向55_in_ctrl请求三行数据


    input          calculate_req            //说明计算模块可以接受新的计算数据 请求给数据

    

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
                else if(calculate_req) begin
                    next_state = CALCULATE;
                end
                else begin
                    next_state = WAIT;
                end
            end
            CALCULATE:begin                                        //计算模块
                if(s_valid & s_last) begin               
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
    //向55_in_ctrl请求三行img数据
    reg s_req_r;
    always @(posedge clk) begin
        if(rst) begin
            s_req_r <= 1'b0;
        end
        else if((state == WAIT) && (next_state == CALCULATE))begin
            s_req_r <= 1'b1;
        end
        else if(s_req & s_valid)begin
            s_req_r <= 1'b0;
        end
    end
    assign s_req = s_req_r;
    



////////////////////////////////// 计算所需数据准备好了的信号 /////////////////////////////////////////////



    //全部计算计算结束信号
    reg calculate_end;
    always @(posedge clk) begin
        if(rst) begin
            calculate_end <= 1'b0;
        end
        else if(state == IDLE) begin
            calculate_end <= 1'b0;
        end
        else if((row_cnt == row_num_r) && (calculate_cin_cnt == calculate_cin_num_r) && s_last) begin
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
        else if(s_last) begin
            if(calculate_cin_cnt == calculate_cin_num_r) begin
                calculate_cin_cnt <= 0;
            end
            else begin
                calculate_cin_cnt <= calculate_cin_cnt + 1;
            end
        end
    end




////////////////////////////////// 行列相关 /////////////////////////////////////////////  
    //行数计数器
    reg [ROW_WIDTH : 0] row_num_r;
    always @(posedge clk) begin
        row_num_r  <= row_num - 1'b1;     
    end
    //对应计数器
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk) begin
        if(state == IDLE) begin
            row_cnt <= 0;
        end
        else if(s_last && (calculate_cin_cnt == calculate_cin_num_r))begin
            row_cnt <= row_cnt + 1'b1;
        end
    end

endmodule