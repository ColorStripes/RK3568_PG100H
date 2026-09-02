module sync_fifo_replay #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 16
)(
    input wire clk,
    input wire rst,
    input wire rewind,        // 【新增】重读使能信号，高电平有效
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1 : 0] din,
    output wire [DATA_WIDTH-1 : 0] dout,
    output wire full,
    output wire empty
);

    localparam ADDR_WIDTH = $clog2(DATA_DEPTH);

    // 内部指针
    reg [ADDR_WIDTH-1 : 0] wr_ptr = 0;
    reg [ADDR_WIDTH-1 : 0] rd_ptr = 0;
    reg [ADDR_WIDTH : 0] count = 0;   // 数据计数器



    wire ren;
    wire [DATA_WIDTH-1:0] ram_dout;  
    // 实例化同步RAM
    fifo_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_DEPTH(DATA_DEPTH)
    ) 
    FIFO_BRAM(
        .clk(clk),
        .wen(wr_en && !full),
        .waddr(wr_ptr),
        .din(din),

        .ren(ren),
        .raddr(rd_ptr),
        .dout(ram_dout)
    );


    // FWFT相关信号
    reg dout_valid = 0;


    // 输出直接连接寄存器
    assign dout = ram_dout;
    // 只要 dout_valid 为 1，就不空（FWFT特性）
    assign empty = ~dout_valid;
    assign full = (count == DATA_DEPTH);
    assign ren = (~dout_valid && count > 0) || (rd_en && ~empty && (count > 1));

    // 写操作 (保持不变，但增加 rewind 时的保护可选用)
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end 
        else if (wr_en && !full) begin
            if(wr_ptr == DATA_DEPTH-1) begin
                wr_ptr <= 0;
            end
            else begin
                wr_ptr <= wr_ptr + 1;
            end
        end
    end

    // 读操作、FWFT逻辑 和 Rewind逻辑
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            dout_valid <= 0;
            count <= 0;
        end 
        else if (rewind) begin
            // 【新增】重读逻辑核心
            // 1. 读指针归零
            rd_ptr <= 0;
            
            // 2. 清除当前输出有效位，迫使 FWFT 逻辑在下个周期重新从地址 0 加载数据
            dout_valid <= 0;
            
            // 3. 重置计数器
            // 逻辑：剩下的可读数据 = 已经写入的数据位置 (假设从0写到wr_ptr)
            // 注意：如果 wr_ptr 绕回了 0 (写满了)，这里需要特殊处理防止 count 变成 0
            if (wr_ptr == 0 && count != 0) 
                count <= DATA_DEPTH; // 如果本来是满的，rewind 后还是满的
            else
                count <= wr_ptr;     // 否则 count 等于当前写指针的位置
        end
        else begin
            // --------------------------------------------------------
            // 1. 更新数据计数器 (常规读写)
            // --------------------------------------------------------
            case ({wr_en && ~full, rd_en && ~empty})
                2'b01: count <= count - 1;
                2'b10: count <= count + 1;
                default: count <= count;
            endcase

            // --------------------------------------------------------
            // 2. FWFT 预取逻辑
            // --------------------------------------------------------
            // 场景 A: 输出无效(刚复位或刚rewind) 且 RAM 里有数据
            if (~dout_valid && count > 0) begin
                dout_valid <= 1;
                // 指针移动到下一个位置，准备下一次读取
                rd_ptr <= (rd_ptr == DATA_DEPTH - 1) ? 0 : rd_ptr + 1;
            end
            // 场景 B: 外部正在读取，且 FIFO 不空
            else if (rd_en && ~empty) begin
                // 如果 RAM 里还有剩余数据 (>1 说明除了当前输出的，里面还有)
                if (count > 1) begin
                    dout_valid <= 1;
                    rd_ptr <= (rd_ptr == DATA_DEPTH - 1) ? 0 : rd_ptr + 1;
                end 
                else begin            
                    // 读完最后一个数据了，FIFO 变空
                    dout_valid <= 0;
                end
            end 
        end
    end

endmodule