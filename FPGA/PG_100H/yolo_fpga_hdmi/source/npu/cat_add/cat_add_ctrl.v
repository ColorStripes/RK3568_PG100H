module cat_add_ctrl #(
    parameter MAX_IN_ROW = 320,                          //输入的IMG的最大行数
              ROW_WIDTH = $clog2(MAX_IN_ROW)
)
(
    input          clk          ,
    input          rst          ,
    input          start        ,

    input [ROW_WIDTH : 0]   row_num  ,



    input          s_valid   ,
    input          s_last    ,
    output         s_req     ,             

    input          calculate_req               //说明计算模块可以接受新的计算数据 请求给数据

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
                if(row_cnt == row_num) begin
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


//////////////////////////////行列数据///////////////////////////////////////
    //对应计数器
    reg [ROW_WIDTH : 0] row_cnt;
    always @(posedge clk) begin
        if(state == IDLE) begin
            row_cnt <= 0;
        end
        else if((state == CALCULATE) && (next_state == WAIT))begin
            row_cnt <= row_cnt + 1'b1;
        end
    end




//////////////////////////////输出请求///////////////////////////////////////
    reg s_req_r;
    always @(posedge clk) begin
        if(rst) begin
            s_req_r <= 1'b0;
        end
        if((state == WAIT) && (next_state == CALCULATE)) begin
            s_req_r <= 1'b1;
        end
        else if(s_req_r & s_valid)begin
            s_req_r <= 1'b0;
        end
    end
    assign s_req = s_req_r;



endmodule