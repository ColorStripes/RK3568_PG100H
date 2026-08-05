module async_rst #(
    parameter RESET_NUM = 1,
              RESET_CNT = 16
)(
    //原始时钟复位信号
    input      reset,

    //想要同步到的时钟和复位信号
    input      [RESET_NUM-1 : 0]  clk,
    output reg [RESET_NUM-1 : 0]  rst
);




    //异步复位同步释放
    (* ASYNC_REG = "TRUE" *)reg reset_i[RESET_NUM-1 : 0];
    //异步复位转同步复位
    (* ASYNC_REG = "TRUE" *)reg [RESET_NUM-1 : 0] reset_sync1 = {RESET_NUM{1'b1}};
    (* ASYNC_REG = "TRUE" *)reg reset_sync[RESET_NUM-1 : 0];
    //复位延长时间计数器
    reg [3 : 0] reset_cnt[RESET_NUM-1 : 0] ;

    
    

    generate
        for(genvar i = 0; i < RESET_NUM; i = i + 1) begin: RESET_NUMBER

            //异步复位转同步复位 减小扇出
            always @(posedge clk[i] or posedge reset) begin
                if(reset) begin
                    reset_i[i] <= 1'b1;
                    reset_sync1[i] <= 1'b1;
                    reset_sync[i] <= 1'b1;
                end
                else begin
                    reset_i[i] <= 1'b0;
                    reset_sync1[i] <= reset_i[i];
                    reset_sync[i]  <= reset_sync1[i];
                end

            end

            
            //延长reset
            always @(posedge clk[i]) begin
                if(reset_sync[i]) begin
                    reset_cnt[i] <= 4'd0;
                end
                else if(reset_cnt[i] < RESET_CNT-1) begin
                    reset_cnt[i] <= reset_cnt[i] + 1'b1;
                end
            end


            //复位信号生成
            always @(posedge clk[i]) begin
                rst[i] <= (reset_cnt[i] < RESET_CNT-1);
            end


        end
    endgenerate  

endmodule