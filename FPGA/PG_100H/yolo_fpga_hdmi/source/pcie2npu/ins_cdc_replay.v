// ============================================================================
// ins_cdc_replay : 异步 FIFO（128bit 写 -> 32bit 读）+ FWFT 读 + rewind 重放
// ============================================================================
// 用途：合并原 ins_cdc(异步+位宽转换) 与 sync_fifo_replay(重放) 两个 FIFO。
//
// 写侧（axi_clk）：128bit 突发数据直接写入。
// 读侧（npu_clk）：FWFT 输出 32bit 指令，rd_empty=!fwft_valid；
//                  rd_en 消费当前字；rewind 把读指针拨回 0，用于逐层重放。
//
// 存储复用 Pango ipm2l_sdpram_v1_10_ins_cdc（128->32 位宽转换 + 双时钟 BRAM）。
// 指针/CDC 逻辑为自定义（等价于 Pango fifo_ctrl 的 ASYN_CTRL，外加 rewind）。
//
// 参数约束：WR_DEPTH * WR_DATA_WIDTH == RD_DEPTH * RD_DATA_WIDTH（位宽比 4:1）。
// ============================================================================

module ins_cdc_replay #(
    parameter WR_DATA_WIDTH  = 128,
    parameter RD_DATA_WIDTH  = 32,
    parameter WR_DEPTH       = 1024,
    parameter RD_DEPTH       = 4096,
    parameter WR_AW          = $clog2(WR_DEPTH),   // 10
    parameter RD_AW          = $clog2(RD_DEPTH),   // 12
    parameter ALMOST_FULL_NUM = 1020,
    parameter ALMOST_EMPTY_NUM = 16
)(
    // ---- 写侧（axi_clk 域） ----
    input  wire                          wr_clk,
    input  wire                          wr_rst,
    input  wire                          wr_en,
    input  wire [WR_DATA_WIDTH-1 : 0]    wr_data,
    output wire                          wr_full,
    output wire                          almost_full,

    // ---- 读侧（npu_clk 域） ----
    input  wire                          rd_clk,
    input  wire                          rd_rst,
    input  wire                          rd_en,      // 消费当前 FWFT 字（高有效）
    output wire [RD_DATA_WIDTH-1 : 0]    rd_data,    // FWFT 输出
    output wire                          rd_empty,   // = !fwft_valid
    output wire                          almost_empty, // 可读字数 <= ALMOST_EMPTY_NUM
    input  wire                          rewind      // 读指针复位到 0（重放）
);

    // =========================================================================
    // 写域指针
    // =========================================================================
    reg  [WR_AW:0] wbin;
    reg  [WR_AW:0] wgray;
    reg  [RD_AW:0] rptr_sync1;   // 读 gray -> 写域 同步链
    reg  [RD_AW:0] rptr_sync2;

    reg  [RD_AW:0] rbin_synced;  // 读指针(13bit) 同步到写域后的二进制
    integer        ri;

    // gray -> binary（读指针，同步到写域后）
    always @(*) begin
        for (ri = 0; ri <= RD_AW; ri = ri + 1)
            rbin_synced[ri] = ^(rptr_sync2 >> ri);
    end

    // 写侧看到的读指针（换算到 128bit 条目粒度 = 去掉低 2bit 子字）
    wire [WR_AW:0] rd_ptr_128 = rbin_synced[RD_AW : RD_AW - WR_AW];

    reg  wr_full_r;
    reg  [WR_AW:0] wr_water_level;

    // 写使能（满时不再写，防止覆盖）
    wire wr_en_int = wr_en & ~wr_full_r;

    // 下一写指针
    wire [WR_AW:0] wbin_next = wbin + wr_en_int;
    wire [WR_AW:0] wgray_next = (wbin_next >> 1) ^ wbin_next;

    // 满判定（写指针 vs 同步读指针，位宽比 4:1）
    wire full_comb = (wbin_next[WR_AW] != rbin_synced[RD_AW]) &&
                     (wbin_next[WR_AW-1:0] == rbin_synced[RD_AW-1 : RD_AW - WR_AW]);

    // 写水位（128bit 条目数）
    wire [WR_AW:0] wwptr = wbin_next;
    wire [WR_AW:0] wrptr = rd_ptr_128;

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wbin           <= {WR_AW+1{1'b0}};
            wgray          <= {WR_AW+1{1'b0}};
            rptr_sync1     <= {RD_AW+1{1'b0}};
            rptr_sync2     <= {RD_AW+1{1'b0}};
            wr_full_r      <= 1'b0;
            wr_water_level <= {WR_AW+1{1'b0}};
        end
        else begin
            rptr_sync1 <= rgray;
            rptr_sync2 <= rptr_sync1;
            wbin       <= wbin_next;
            wgray      <= wgray_next;
            wr_full_r  <= full_comb;

            case ({wwptr[WR_AW], wrptr[WR_AW]})
                2'b00: wr_water_level <= wwptr[WR_AW-1:0] - wrptr[WR_AW-1:0];
                2'b01: wr_water_level <= {1'b1, wwptr[WR_AW-1:0]} - wrptr[WR_AW-1:0];
                2'b10: wr_water_level <= wwptr[WR_AW:0] - wrptr[WR_AW-1:0];
                2'b11: wr_water_level <= wwptr[WR_AW-1:0] - wrptr[WR_AW-1:0];
            endcase
        end
    end

    assign wr_full     = wr_full_r;
    assign almost_full = (wr_water_level >= ALMOST_FULL_NUM);

    // =========================================================================
    // 读域指针 + FWFT
    // =========================================================================
    reg  [RD_AW:0] rbin;
    reg  [RD_AW:0] rgray;
    reg  [WR_AW:0] wptr_sync1;   // 写 gray -> 读域 同步链
    reg  [WR_AW:0] wptr_sync2;

    reg  [WR_AW:0] wbin_synced;  // 写指针(11bit) 同步到读域后的二进制
    integer        wi;

    reg            fwft_valid;

    // gray -> binary（写指针，同步到读域后）
    always @(*) begin
        for (wi = 0; wi <= WR_AW; wi = wi + 1)
            wbin_synced[wi] = ^(wptr_sync2 >> wi);
    end

    // 写指针换算到 32bit 字粒度（左移 2bit）
    wire [RD_AW:0] wbin_ext = {wbin_synced, {RD_AW - WR_AW{1'b0}}};

    // 空判定：1 拍读延迟下 rbin 是取数指针，当前送出的字在 mem[rbin-1]，
    // 消费后下一个字是 mem[rbin]，故「有无下一个字」与「是否为空」都判 rbin == wbin_ext
    wire rd_empty_now = (rbin == wbin_ext);

    // 读侧真实可读字数（32bit）：FWFT 预取使 rbin 超前 1，需加回 fwft_valid
    // 不变式：rbin = 已消费字数 + fwft_valid，故 真实剩余 = wbin_ext - rbin + fwft_valid
    wire [RD_AW:0] rd_valid_words = wbin_ext - rbin + fwft_valid;

    // almost_empty：
    //   ALMOST_EMPTY_NUM == 0 时，almost_empty 等价于「FIFO 空」，复用短路径的
    //   rd_empty(=!fwft_valid) 与 rd_empty_now(=rbin==wbin_ext)，避免 rd_valid_words
    //   那条 13bit 减法 + 比较的长组合路径导致时序违例。
    //   ALMOST_EMPTY_NUM > 0 时（末尾有占位），才用 rd_valid_words 比较。
    generate
        if (ALMOST_EMPTY_NUM == 0) begin : gen_almost_empty_zero
            reg almost_empty_r;
            always @(posedge rd_clk or posedge rd_rst) begin
                if (rd_rst)
                    almost_empty_r <= 1'b1;   // 复位时 FIFO 为空
                else
                    almost_empty_r <= rd_empty && rd_empty_now;
            end
            assign almost_empty = almost_empty_r;
        end
        else begin : gen_almost_empty_n
            reg almost_empty_r;
            always @(posedge rd_clk or posedge rd_rst) begin
                if (rd_rst)
                    almost_empty_r <= 1'b1;   // 复位时 FIFO 为空
                else
                    almost_empty_r <= (rd_valid_words <= ALMOST_EMPTY_NUM);
            end
            assign almost_empty = almost_empty_r;
        end
    endgenerate

    // 预取：无当前字且不空，或 消费中且还有下一个字
    wire sdpram_rd_en = !rewind && !rd_empty_now && (!fwft_valid || rd_en);

    wire [RD_AW:0] rbin_next  = rbin + sdpram_rd_en;
    wire [RD_AW:0] rgray_next = (rbin_next >> 1) ^ rbin_next;

    // 下一拍 FWFT 有效
    wire next_fwft_valid = !fwft_valid ? !rd_empty_now :
                           (rd_en       ? !rd_empty_now : 1'b1);

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rbin        <= {RD_AW+1{1'b0}};
            rgray       <= {RD_AW+1{1'b0}};
            wptr_sync1  <= {WR_AW+1{1'b0}};
            wptr_sync2  <= {WR_AW+1{1'b0}};
            fwft_valid  <= 1'b0;
        end
        else begin
            wptr_sync1 <= wgray;
            wptr_sync2 <= wptr_sync1;

            if (rewind) begin
                rbin       <= {RD_AW+1{1'b0}};
                rgray      <= {RD_AW+1{1'b0}};
                fwft_valid <= 1'b0;
            end
            else begin
                rbin       <= rbin_next;
                rgray      <= rgray_next;
                fwft_valid <= next_fwft_valid;
            end
        end
    end

    wire [RD_DATA_WIDTH-1:0] sdpram_rd_data;
    assign rd_data  = sdpram_rd_data;
    assign rd_empty = ~fwft_valid;

    // =========================================================================
    // 存储：Pango 双时钟 SDPRAM（128 -> 32 位宽转换）
    // =========================================================================

    ipm2l_sdpram_v1_10_ins_cdc #(
        .c_CAS_MODE          ("36K" ),
        .c_WR_ADDR_WIDTH     (WR_AW ),
        .c_WR_DATA_WIDTH     (WR_DATA_WIDTH),
        .c_RD_ADDR_WIDTH     (RD_AW ),
        .c_RD_DATA_WIDTH     (RD_DATA_WIDTH),
        .c_OUTPUT_REG        (0     ),
        .c_RD_OCE_EN         (0     ),
        .c_FAB_REG           (0     ),
        .c_WR_ADDR_STROBE_EN (0     ),
        .c_RD_ADDR_STROBE_EN (0     ),
        .c_WR_CLK_EN         (1     ),
        .c_RD_CLK_EN         (1     ),
        .c_RESET_TYPE        ("ASYNC"),
        .c_POWER_OPT         (0     ),
        .c_RD_CLK_OR_POL_INV (0     ),
        .c_INIT_FILE         ("NONE"),
        .c_INIT_FORMAT       ("BIN" ),
        .c_WR_BYTE_EN        (0     ),
        .c_BE_WIDTH          (1     )
    ) u_sdpram (
        .wr_data        (wr_data        ),
        .wr_addr        (wbin[WR_AW-1:0]),
        .wr_en          (wr_en_int      ),
        .wr_clk         (wr_clk         ),
        .wr_clk_en      (1'b1           ),
        .wr_rst         (wr_rst         ),
        .wr_byte_en     (1'b1           ),
        .wr_addr_strobe (1'b0           ),

        .rd_data        (sdpram_rd_data ),
        .rd_addr        (rbin[RD_AW-1:0]),
        .rd_clk         (rd_clk         ),
        .rd_clk_en      (sdpram_rd_en   ),
        .rd_rst         (rd_rst         ),
        .rd_oce         (1'b0           ),
        .rd_addr_strobe (1'b0           )
    );

endmodule