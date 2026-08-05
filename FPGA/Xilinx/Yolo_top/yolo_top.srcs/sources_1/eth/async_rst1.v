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


    reg [3 : 0] reset_cnt[RESET_NUM-1 : 0] ;
    reg         ui_reset[RESET_NUM-1 : 0]  ;
    reg         ui_reset_d[RESET_NUM-1 : 0];


    generate
        for(genvar i = 0; i < RESET_NUM; i = i + 1) begin: RESET_NUMBER

            //延长reset
            always @(posedge clk[i] or posedge reset) begin
                if(reset) begin
                    reset_cnt[i] <= 4'd0;
                end
                else if(reset_cnt[i] < RESET_CNT-1) begin
                    reset_cnt[i] <= reset_cnt[i] + 1'b1;
                end
            end

            //复位信号生成
            always @(posedge clk[i] or posedge reset) begin
                if(reset) begin
                    ui_reset[i] <= 1'b1;
                end
                else if(reset_cnt[i] < RESET_CNT-1) begin
                    ui_reset[i] <= 1'b1;
                end
                else begin
                    ui_reset[i] <= 1'b0;
                end
            end

            //打两拍输出复位
            always @(posedge clk[i] or posedge reset) begin
                if(reset) begin
                    ui_reset_d[i] <= 1'b1;
                    rst[i] <= 1'b1;
                end
                else begin
                    ui_reset_d[i] <= ui_reset[i];
                    rst[i] <= ui_reset_d[i];
                end
            end

        end
    endgenerate  

endmodule