//实现根据ip查找mac地址的功能  cache作为一个mac地址表
module arp_cache #(
    parameter INVALID_TIME = 32'hFFFF_FFFF,
              CACHE_SIZE = 16
)(
    input clk,
    input rst,
    input wen,
    input [31 : 0] wip,
    input [47 : 0] wmac,

    input ren,                          //启动查找 
    input [31 : 0] rip,                 //要查找的IP地址  
    output reg [47 : 0] rmac,           //mac输出
    output reg hit                      //命中标志
);

    //查找表结构
    reg [31 : 0] ip_cache[CACHE_SIZE-1 : 0];       
    reg [47 : 0] mac_cache[CACHE_SIZE-1 : 0];
    reg          valid_cache[CACHE_SIZE-1 : 0];                        //当前cache有效标志位



    
    wire [$clog2(CACHE_SIZE)-1 : 0] windex = wip[24 +: 8] ^ wip[16 +: 8] ^ wip[8 +: 8] ^ wip[0 +: 8];
    wire [$clog2(CACHE_SIZE)-1 : 0] rindex = rip[24 +: 8] ^ rip[16 +: 8] ^ rip[8 +: 8] ^ rip[0 +: 8];




    //总计数器
    reg [31 : 0] counter;
    always @(posedge clk) begin
        if(rst) begin
            counter <= 1'b0;
        end
        else if(counter == INVALID_TIME-1) begin
            counter <= 1'b0;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end



    reg aging_tick;
    always @(posedge clk) begin
        if(rst) begin
            aging_tick <= 1'b0;
        end
        else if(counter == INVALID_TIME-1) begin
            aging_tick <= 1'b1;
        end
        else begin
            aging_tick <= 1'b0;
        end
    end


    localparam AGING_WIDTH = 2;
    integer i;
    // Aging 计数器更新逻辑
    reg [AGING_WIDTH-1 : 0] aging_counter[CACHE_SIZE-1 : 0];
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < CACHE_SIZE; i = i + 1) begin
                aging_counter[i] <= {AGING_WIDTH{1'b0}};;
            end
        end 
        else if(wen && !valid_cache[windex]) begin
            aging_counter[windex] <= {AGING_WIDTH{1'b1}};
        end
        else if(ren && (valid_cache[rindex] && ip_cache[rindex] == rip)) begin
            aging_counter[windex] <= {AGING_WIDTH{1'b1}};
        end
        else if(aging_tick) begin
            for(i = 0; i < CACHE_SIZE; i = i + 1) begin
                if(valid_cache[i] && (aging_counter[i] > 0)) begin
                    aging_counter[i] <= aging_counter[i] - 1;
                end
            end
        end
    end


    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < CACHE_SIZE; i = i + 1) begin
                valid_cache[i] <= 1'b0;
            end
        end
        else if(wen && (!valid_cache[windex])) begin
            valid_cache[windex] <= 1;
        end
        else if(aging_tick) begin
            for(i = 0; i < CACHE_SIZE; i = i + 1) begin
                if(valid_cache[i] && (aging_counter[i] == 0)) begin
                    valid_cache[i] <= 1'b0;             // aging失效
                end
            end
        end
    end


    // 插入逻辑（替换或更新）
    always @(posedge clk) begin
        if(wen) begin
            // 替换项（仅当 aging 到期）
            if(!valid_cache[windex]) begin
                ip_cache[windex]  <= wip;
                mac_cache[windex] <= wmac;
            end
        end
    end


    // 查找逻辑
    always @(posedge clk) begin
        if(ren) begin
            if(valid_cache[rindex] && ip_cache[rindex] == rip) begin
                hit <= 1;
                rmac <= mac_cache[rindex];
            end 
            else begin
                hit <= 0;
            end
        end
        else begin
            hit <= 0;
        end
    end








endmodule