module sync_fifo_LUT #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 16
)(
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1 : 0] din,
    output wire [DATA_WIDTH-1 : 0] dout,
    output wire full,
    output wire empty
);

    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);

    reg [DATA_WIDTH-1 : 0] mem [0 : DATA_DEPTH-1];

    reg [ADDR_WIDTH-1 : 0] wr_ptr = 0;
    reg [ADDR_WIDTH-1 : 0] rd_ptr = 0;
    reg [ADDR_WIDTH : 0] count = 0;   // 数据计数器

    // FWFT相关信号
    reg [DATA_WIDTH-1 : 0] dout_reg;
    reg dout_valid = 0;


    // 输出直接连接寄存器
    assign dout = dout_reg;
    assign empty = ~dout_valid;
    assign full = (count == DATA_DEPTH);
    //assign data_count = count;


    // 写操作
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end 
        else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            if(wr_ptr == DATA_DEPTH-1) begin
                wr_ptr <= 0;
            end
            else begin
                wr_ptr <= wr_ptr + 1;
            end
        end
    end

    // 读操作和FWFT逻辑
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            dout_valid <= 0;
            count <= 0;
        end 
        else begin
            // 更新数据计数器
            case ({wr_en && ~full, rd_en && ~empty})
                2'b01: count <= count - 1;
                2'b10: count <= count + 1;
                default: count <= count;
            endcase

            // FWFT逻辑
            if (rd_en && ~empty) begin
                // 正常读取
                if(rd_ptr == DATA_DEPTH-1) begin
                    rd_ptr <= 0;
                end
                else begin
                    rd_ptr <= rd_ptr + 1; 
                end
                
                if (count > 1) begin
                    // 预取下一个数据
                    if(rd_ptr == DATA_DEPTH-1) begin
                        dout_reg <= mem[0];
                    end
                    else begin
                        dout_reg <= mem[rd_ptr + 1];
                    end
                end 
                else begin
                    dout_valid <= 0;
                end
            end 
            else if (~dout_valid && count > 0) begin
                // FWFT特性：当输出无效但FIFO不空时，自动加载第一个数据
                dout_reg <= mem[rd_ptr];
                dout_valid <= 1;
            end
        end
    end





endmodule