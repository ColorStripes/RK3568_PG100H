//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2019 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:ips2l_pcie_dma_controller.v
//////////////////////////////////////////////////////////////////////////////
module ips2l_pcie_dma_controller #(
    parameter                           DEVICE_TYPE = 3'd0      ,   //3'd0:EP,3'd1:Legacy EP,3'd4:RC
    parameter                           ADDR_WIDTH  = 4'd10
)(
    input                               clk                     ,   //gen1:62.5MHz,gen2:125MHz
    input                               rst_n                   ,

    /////
    input                               i_mwr_tx_busy           , // [新增]
    input                               i_mrd_rx_busy           , // [新增]
    output  reg                         o_fpga_msi              ,  // [新增]
    //**********************************************************************
    //bar1 wr interface
    input                               i_bar1_wr_en            ,
    input           [ADDR_WIDTH-1:0]    i_bar1_wr_addr          ,
    input           [127:0]             i_bar1_wr_data          ,
    input           [15:0]              i_bar1_wr_byte_en       ,
    //**********************************************************************
    //apb interface
    input                               i_apb_psel              ,
    input           [9:0]               i_apb_paddr             ,
    input           [31:0]              i_apb_pwdata            ,
    input           [3:0]               i_apb_pstrb             ,
    input                               i_apb_pwrite            ,
    input                               i_apb_penable           ,
    output  reg                         o_apb_prdy              ,
    output  reg     [31:0]              o_apb_prdata            ,
    //**********************************************************************
    output  reg                         o_user_define_data_flag ,

    //**********************************************************************
    //to tx
    output  reg                         o_mwr32_req             ,
    input                               i_mwr32_req_ack         ,
    output  reg                         o_mwr64_req             ,
    input                               i_mwr64_req_ack         ,

    output  reg                         o_mrd32_req             ,
    input                               i_mrd32_req_ack         ,
    output  reg                         o_mrd64_req             ,
    input                               i_mrd64_req_ack         ,
    output  reg     [9:0]               o_req_length            ,
    output  reg     [63:0]              o_req_addr              ,
    output  reg     [31:0]              o_req_data              ,


    input           [63:0]              i_dma_check_result      ,
    output  wire                        o_tx_restart            ,
    output  reg                         o_cross_4kb_boundary    ,


    // [新增] 专门输出给 DDR3 读写控制逻辑的起始地址
    output  reg     [31:0]              o_ddr3_addr             ,
    output  reg     [31:0]              o_ddr3_length           ,
    output  reg     [31:0]              o_ddr3_total_length

);
//apb register for rc
reg     [31:0]      apb_cmd_reg;
reg     [31:0]      apb_cmd_length;
reg     [31:0]      apb_cmd_l_addr;
reg     [31:0]      apb_cmd_h_addr;
reg     [31:0]      apb_cmd_data;

reg     [31:0]      apb_pwdata;

reg                 apb_cmd_reg_vld;
reg                 apb_cmd_length_vld;
reg                 apb_cmd_l_addr_vld;
reg                 apb_cmd_h_addr_vld;
reg                 apb_cmd_data_vld;

reg                 apb_ctrl_cfg_done;
reg                 apb_length_cfg_done;
reg                 apb_l_addr_cfg_done;
reg                 apb_h_addr_cfg_done;
reg                 apb_data_cfg_done;

// [新增] DDR3 address register for RC
reg     [31:0]      apb_ddr3_addr;
reg                 apb_ddr3_addr_vld;
reg                 apb_ddr3_addr_cfg_done;


//mwr register for ep
reg     [31:0]      dma_cmd_reg;
reg     [31:0]      dma_cmd_l_addr;
reg     [31:0]      dma_cmd_h_addr;

reg     [31:0]      dma_wr_data;

reg                 dma_cmd_reg_vld;
reg                 dma_cmd_l_addr_vld;
reg                 dma_cmd_h_addr_vld;

reg                 dma_ctrl_cfg_done  ;
reg                 dma_l_addr_cfg_done;
reg                 dma_h_addr_cfg_done;

// [新增] DDR3 address register for EP
reg     [31:0]      dma_ddr3_addr;
reg                 dma_ddr3_addr_vld;
reg                 dma_ddr3_addr_cfg_done;

// [新增] Chunk Loop FSM 内部信号
reg     [31:0]      dma_total_length;
reg                 dma_total_length_vld;
reg                 dma_total_length_cfg_done;

reg     [31:0]      apb_total_length;
reg                 apb_total_length_vld;
reg                 apb_total_length_cfg_done;

// [新增] cfg_done 重置后立即重新置位逻辑
reg                 chunk_done_d1;      // chunk_done 延迟一拍
reg                 chunk_done_1shot;   // chunk_done 上升沿单周期脉冲

wire                user_define_data_flag;
wire                dma_32_64_addr_cmd_flag;
wire                dma_wr_rd_cmd_flag;

wire                ack_rcv;

wire                device_rc;
wire                device_ep;

wire                apb_write;
wire                apb_read;

wire                cmd_reg_cfg_done;
wire                l_addr_cfg_done;
wire                h_addr_cfg_done;
// [新增]
wire                ddr3_addr_cfg_done;

wire                mwr32_req_vld;
wire                mwr64_req_vld;
wire                mrd32_req_vld;
wire                mrd64_req_vld;

//4KB boundary
wire    [12:0]      req_l_addr;
wire    [12:0]      total_data;
wire    [12:0]      target_addr;
wire                cross_4kb_boundary;
//dma check
wire                dma_check_success;

assign device_rc = (DEVICE_TYPE == 3'b100 ) ? 1'b1 : 1'b0;
assign device_ep = (DEVICE_TYPE == 3'b000 || DEVICE_TYPE == 3'b001) ? 1'b1 : 1'b0;

//req_ack
assign ack_rcv = i_mwr32_req_ack | i_mwr64_req_ack | i_mrd32_req_ack | i_mrd64_req_ack;

//********************************************************************dma controller register*********************************************************************
//dma_wr_data
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_wr_data <= 32'b0;
    else
        dma_wr_data <= i_bar1_wr_data[31:0];
end

//dma_cmd_reg_vld
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_reg_vld <= 1'b0;
    else if(dma_cmd_reg_vld)
        dma_cmd_reg_vld <= 1'b0;
    else
        dma_cmd_reg_vld <= &i_bar1_wr_byte_en && i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 9'h100);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_reg <= 32'd0;
    else if(dma_cmd_reg_vld)
        dma_cmd_reg <= dma_wr_data;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_ctrl_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        dma_ctrl_cfg_done <= 1'b0;
    else if(dma_cmd_reg_vld)
        dma_ctrl_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位，无需驱动再次写入
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        dma_ctrl_cfg_done <= 1'b1;
end

//dma_cmd_l_addr
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_l_addr_vld <= 1'b0;
    else if(dma_cmd_l_addr_vld)
        dma_cmd_l_addr_vld <= 1'b0;
    else
        dma_cmd_l_addr_vld <= &i_bar1_wr_byte_en && i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 9'h110);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_l_addr <= 32'd0;
    else if(dma_cmd_l_addr_vld)
        dma_cmd_l_addr <= dma_wr_data;
end

//l_addr_cfg_done
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_l_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        dma_l_addr_cfg_done <= 1'b0;
    else if(dma_cmd_l_addr_vld)
        dma_l_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        dma_l_addr_cfg_done <= 1'b1;
end

//dma_cmd_h_addr
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_h_addr_vld <= 1'b0;
    else if(dma_cmd_l_addr_vld)
        dma_cmd_h_addr_vld <= 1'b0;
    else
        dma_cmd_h_addr_vld <= &i_bar1_wr_byte_en && i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 9'h120);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_cmd_h_addr <= 32'd0;
    else if(dma_cmd_h_addr_vld)
        dma_cmd_h_addr <= dma_wr_data;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_h_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        dma_h_addr_cfg_done <= 1'b0;
    else if(dma_cmd_h_addr_vld)
        dma_h_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        dma_h_addr_cfg_done <= 1'b1;
end



//DDR3 addr
// [新增] dma_ddr3_addr (EP模式写入 9'h1E0)
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_ddr3_addr_vld <= 1'b0;
    else if(dma_ddr3_addr_vld)
        dma_ddr3_addr_vld <= 1'b0;
    else
        dma_ddr3_addr_vld <= &i_bar1_wr_byte_en && i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 9'h1E0);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_ddr3_addr <= 32'd0;
    else if(dma_ddr3_addr_vld)
        dma_ddr3_addr <= dma_wr_data;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_ddr3_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        dma_ddr3_addr_cfg_done <= 1'b0;
    else if(dma_ddr3_addr_vld)
        dma_ddr3_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        dma_ddr3_addr_cfg_done <= 1'b1;
end


// TOTAL_LENGTH (新增) - 总字节数，CPU写入后控制器自动完成所有chunk传输
// EP模式: BAR1 0x200
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_total_length_vld <= 1'b0;
    else if(dma_total_length_vld)
        dma_total_length_vld <= 1'b0;
    else
        dma_total_length_vld <= &i_bar1_wr_byte_en && i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 10'h200);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_total_length <= 32'd0;
    else if(dma_total_length_vld)
        dma_total_length <= dma_wr_data;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dma_total_length_cfg_done <= 1'b0;
    else if (ack_rcv)
        dma_total_length_cfg_done <= 1'b0;
    else if(dma_total_length_vld)
        dma_total_length_cfg_done <= 1'b1;
end

// APB TOTAL_LENGTH (新增) - RC模式: APB 0x1A0
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_total_length_vld <= 1'b0;
    else if(apb_total_length_vld)
        apb_total_length_vld <= 1'b0;
    else
        apb_total_length_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h1A0);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_total_length <= 32'd0;
    else if(apb_total_length_vld)
        apb_total_length <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_total_length_cfg_done <= 1'b0;
    else if (ack_rcv)
        apb_total_length_cfg_done <= 1'b0;
    else if(apb_total_length_vld)
        apb_total_length_cfg_done <= 1'b1;
end

//********************************************************************apb controller register*********************************************************************
assign apb_write = i_apb_psel && i_apb_penable && i_apb_pwrite;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_pwdata <= 32'b0;
    else
        apb_pwdata <= i_apb_pwdata;
end
//apb_cmd_reg for rc
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_reg_vld <= 1'b0;
    else if(apb_cmd_reg_vld)
        apb_cmd_reg_vld <= 1'b0;
    else
        apb_cmd_reg_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h140);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_reg <= 32'd0;
    else if(apb_cmd_reg_vld)
        apb_cmd_reg <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_ctrl_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_ctrl_cfg_done <= 1'b0;
    else if(apb_cmd_reg_vld)
        apb_ctrl_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位，无需驱动再次写入
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        apb_ctrl_cfg_done <= 1'b1;
end

//apb_cmd_length
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_length_vld <= 1'b0;
    else if(apb_cmd_length_vld)
        apb_cmd_length_vld <= 1'b0;
    else
        apb_cmd_length_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h150);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_length <= 32'd0;
    else if(apb_cmd_length_vld)
        apb_cmd_length <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_length_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_length_cfg_done <= 1'b0;
    else if(apb_cmd_length_vld)
        apb_length_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        apb_length_cfg_done <= 1'b1;
end

//apb_cmd_l_addr
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_l_addr_vld <= 1'b0;
    else if(apb_cmd_l_addr_vld)
        apb_cmd_l_addr_vld <= 1'b0;
    else
        apb_cmd_l_addr_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h160);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_l_addr <= 32'd0;
    else if(apb_cmd_l_addr_vld)
        apb_cmd_l_addr <= apb_pwdata;
end

//apb_l_addr_cfg_done
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_l_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_l_addr_cfg_done <= 1'b0;
    else if(apb_cmd_l_addr_vld)
        apb_l_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        apb_l_addr_cfg_done <= 1'b1;
end

//apb_cmd_h_addr
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_h_addr_vld <= 1'b0;
    else if(apb_cmd_h_addr_vld)
        apb_cmd_h_addr_vld <= 1'b0;
    else
        apb_cmd_h_addr_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h170);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_h_addr <= 32'd0;
    else if(apb_cmd_h_addr_vld)
        apb_cmd_h_addr <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_h_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_h_addr_cfg_done <= 1'b0;
    else if(apb_cmd_h_addr_vld)
        apb_h_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        apb_h_addr_cfg_done <= 1'b1;
end

//apb_cmd_data
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_data_vld <= 1'b0;
    else if(apb_cmd_data_vld)
        apb_cmd_data_vld <= 1'b0;
    else
        apb_cmd_data_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h180);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_cmd_data <= 32'd0;
    else if(apb_cmd_data_vld)
        apb_cmd_data <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_data_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_data_cfg_done <= 1'b0;
    else if(apb_cmd_data_vld)
        apb_data_cfg_done <= 1'b1;
end


// [新增] apb_ddr3_addr (RC模式写入 9'h1C0)
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_ddr3_addr_vld <= 1'b0;
    else if(apb_ddr3_addr_vld)
        apb_ddr3_addr_vld <= 1'b0;
    else
        apb_ddr3_addr_vld <= &i_apb_pstrb && apb_write && (i_apb_paddr == 9'h1C0);
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_ddr3_addr <= 32'd0;
    else if(apb_ddr3_addr_vld)
        apb_ddr3_addr <= apb_pwdata;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        apb_ddr3_addr_cfg_done <= 1'b0;
    else if (ack_rcv || cross_4kb_boundary || chunk_done_1shot)
        apb_ddr3_addr_cfg_done <= 1'b0;
    else if(apb_ddr3_addr_vld)
        apb_ddr3_addr_cfg_done <= 1'b1;
    // [修复] 中间chunk完成后自动重新置位
    else if(chunk_done && chunk_loop_active && !is_final_chunk)
        apb_ddr3_addr_cfg_done <= 1'b1;
end


assign cmd_reg_cfg_done = (device_ep && dma_ctrl_cfg_done)   || (device_rc && apb_ctrl_cfg_done);

assign l_addr_cfg_done  = (device_ep && dma_l_addr_cfg_done) || (device_rc && apb_l_addr_cfg_done);

assign h_addr_cfg_done  = (device_ep && dma_h_addr_cfg_done) || (device_rc && apb_h_addr_cfg_done);

// DDR3 addr 和 total_length 的 cfg_done 综合
assign ddr3_addr_cfg_done = (device_ep && dma_ddr3_addr_cfg_done) || (device_rc && apb_ddr3_addr_cfg_done);

//********************************************************************************************************************************
// Chunk Loop FSM internal working registers (新增)
// Tracks remaining bytes, current addresses, and chunk count for automatic multi-chunk DMA
// Chunk FSM: 将 total_length 自动拆分为多个 chunk，每次最大 4092 字节（不超过 PCIe 4KB 地址边界）
// PCIe 要求单个 TLP 的起始地址 + Length 不能跨 4KB 边界：
//   - 主机地址低 12 位 = x，chunk 最大字节数 = 4096 - x
//   - 为简化，固定每个 chunk 最大 4092 字节（1022 DWs），绝对不跨边界
localparam CHUNK_SIZE_LOG2 = 12;  // log2(4096)
localparam CHUNK_SIZE_MAX  = 32'd4096;  // 1022 DWs < 1024 (max TLP DW), 不会触发 cross_4kb_boundary

reg  [31:0]  chunk_rem_bytes;    // remaining bytes to transfer
reg  [31:0]  chunk_host_addr;    // current host DMA address (accumulated)
reg  [31:0]  chunk_ddr3_addr;    // current DDR3 address (accumulated)
reg  [15:0]  chunk_count;        // number of chunks already completed
reg          chunk_loop_active;  // asserted while chunk loop is in progress
reg          chunk_first_write;  // first CMD_REG write (before total_length was set)

// chunk_done: one-shot pulse asserted when a single chunk TLP transfer finishes
// (recognized by the falling edge of i_mwr_tx_busy / i_mrd_rx_busy)
// For the last chunk: we DO NOT re-assert cmd_reg_cfg_done, so the controller
// stays idle and chunk_loop_done = 1 -> MSI fires once.
// For intermediate chunks: cmd_reg_cfg_done is re-asserted to accept the next CMD_REG write.
wire         chunk_done;
wire         chunk_loop_done;    // all chunks finished -> triggers MSI
wire         is_last_chunk;

// Size of the current chunk (may be smaller for the final partial chunk or when near 4KB boundary)
// PCIe 4KB boundary rule: single TLP cannot cross a 4KB boundary
//   chunk_cur_size = min(remaining_bytes, 4096 - host_addr[11:0])
//   注意: 当 host_addr[11:0] == 0 (4KB对齐) 时, "到边界的字节数" = 4096
wire         chunk_near_boundary;
wire [31:0]  chunk_boundary_limit;
wire [31:0]  chunk_cur_size;
assign chunk_near_boundary  = (chunk_host_addr[11:0] != 12'd0);  // 1=未对齐, 0=4KB对齐
assign chunk_boundary_limit = chunk_near_boundary ?
                              (32'h1000 - {20'd0, chunk_host_addr[11:0]}) :  // 未对齐: 4096 - offset
                              32'h1000;                                       // 对齐: 最大4096
assign chunk_cur_size      = (chunk_rem_bytes[31:CHUNK_SIZE_LOG2] == 0) ?
                              chunk_rem_bytes :  CHUNK_SIZE_MAX;// 最后一个chunk: 直接用剩余字节 (必然<=boundary_limit)
                            //   (chunk_boundary_limit < CHUNK_SIZE_MAX ? chunk_boundary_limit : CHUNK_SIZE_MAX);
assign is_last_chunk       = (chunk_rem_bytes <= CHUNK_SIZE_MAX);

// Initialize internal chunk variables on TOTAL_LENGTH write
// Update them on each chunk boundary
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        chunk_rem_bytes   <= 32'd0;
        chunk_host_addr   <= 32'd0;
        chunk_ddr3_addr   <= 32'd0;
        chunk_count        <= 16'd0;
        chunk_loop_active  <= 1'b0;
        chunk_first_write  <= 1'b0;
    end else if (total_length_cfg_done) begin
        // CPU has written TOTAL_LENGTH -> initialize for first chunk
        chunk_rem_bytes   <= device_ep ? dma_total_length : apb_total_length;
        chunk_host_addr   <= device_ep ? dma_cmd_l_addr   : apb_cmd_l_addr;
        chunk_ddr3_addr   <= device_ep ? dma_ddr3_addr    : apb_ddr3_addr;
        chunk_count        <= 16'd0;
        chunk_loop_active  <= 1'b1;
        chunk_first_write  <= 1'b1;
    end else if (chunk_done && chunk_loop_active) begin
        // Advance to next chunk
        chunk_rem_bytes   <= chunk_rem_bytes - chunk_cur_size;
        chunk_host_addr   <= chunk_host_addr + chunk_cur_size;
        chunk_ddr3_addr   <= chunk_ddr3_addr + chunk_cur_size;
        chunk_count        <= chunk_count + 16'd1;
        chunk_first_write  <= 1'b0;
        // If this was the last chunk, exit loop
        if (is_last_chunk)
            chunk_loop_active <= 1'b0;
    end else begin
        chunk_first_write <= 1'b0;
    end
end


// o_ddr3_addr: first chunk uses register value; subsequent chunks use accumulated value
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_ddr3_total_length <= 32'd0;
    else if (dma_total_length_cfg_done)
        o_ddr3_total_length <= device_ep ? dma_total_length : apb_total_length;
end


// o_ddr3_addr: first chunk uses register value; subsequent chunks use accumulated value
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_ddr3_addr <= 32'd0;
    else if (ddr3_addr_cfg_done && !chunk_loop_active)
        o_ddr3_addr <= device_ep ? dma_ddr3_addr : apb_ddr3_addr;
    else if (chunk_done_d1 && chunk_loop_active && !is_final_chunk_d1)
        o_ddr3_addr <= chunk_ddr3_addr;
end

// o_ddr3_length: 完全由 total_length 和 chunk FSM 推导（不再依赖外部 ddr3_length 寄存器）
// 等价于 min(total_length, CHUNK_SIZE_MAX)，由 total_length_cfg_done 初始化，后续由 chunk FSM 更新
wire [31:0] total_length_val;
assign total_length_val = device_ep ? dma_total_length : apb_total_length;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_ddr3_length <= 32'd0;    
    else if (chunk_done_d1 && chunk_loop_active && !is_final_chunk_d1)
        o_ddr3_length <= chunk_cur_size;
    else if (total_length_cfg_done)
        o_ddr3_length <= (total_length_val <= CHUNK_SIZE_MAX) ? total_length_val : CHUNK_SIZE_MAX;
end

// o_req_addr: first chunk uses register value; subsequent chunks use accumulated host address
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_req_addr[31:0] <= 32'd0;    
    else if (l_addr_cfg_done && !chunk_loop_active)
        o_req_addr[31:0] <= device_ep ? dma_cmd_l_addr : apb_cmd_l_addr;
    else if (chunk_done_d1 && chunk_loop_active && !is_final_chunk_d1)
        o_req_addr[31:0] <= chunk_host_addr;
end

// o_req_length: 直接等于要传输的 DW 数，后续 DMA 引擎按原值使用（无 +1）
//   第一个 chunk: 驱动写入的是 (DW数-1)，所以要 +1
//   后续 chunk:   chunk_cur_size/4 直接是 DW 数
// 最后一包: chunk_done_d1时刻，chunk_cur_size已是正确值，is_final_chunk_d1记录"刚完成的是最后一包"
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_req_length <= 10'd0;
    else if (chunk_done_d1 && chunk_loop_active && !is_final_chunk_d1) begin
        o_req_length <= {1'b0, chunk_cur_size[11:2]};  // chunk_cur_size/4 = DW 数
    end
    else if (cmd_reg_cfg_done) begin
        if (device_ep)
            o_req_length <= dma_cmd_reg[9:0]; // 驱动写的是 DW
        else if (device_rc && apb_length_cfg_done)
            o_req_length <= apb_cmd_length[9:0];       // RC 写的是 DW 数
    end
    
end

assign chunk_done     = (tx_done_pulse && tx_active) || (rx_done_pulse && rx_active);
assign chunk_loop_done = chunk_done && chunk_loop_active && is_last_chunk;

// chunk_done_d1: delayed version of chunk_done for edge detection
// chunk_done_1shot: rising edge one-shot pulse of chunk_done
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        chunk_done_d1    <= 1'b0;
        chunk_done_1shot <= 1'b0;
    end else begin
        chunk_done_d1    <= chunk_done;
        chunk_done_1shot <= chunk_done && !chunk_done_d1;  // rising edge of chunk_done
    end
end

assign total_length_cfg_done = (device_ep && dma_total_length_cfg_done) || (device_rc && apb_total_length_cfg_done);

//********************************************************************************************************************************
//********************************************************************req information*********************************************************************
// o_req_addr_hi: 锁存高 32 位（只在 DMA 启动时设置一次，后续 chunk 保持不变）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_req_addr[63:32] <= 32'd0;
    else if (l_addr_cfg_done)
        o_req_addr[63:32] <= device_ep ? dma_cmd_h_addr : apb_cmd_h_addr;
end

//o_req_data
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_req_data <= 32'd0;
    else if(apb_data_cfg_done)
        o_req_data[31:0]  <= apb_cmd_data;
end




// [新增] DDR3 address 综合 (已在 Chunk FSM 中实现，此处删除以避免冲突)


//******************************************************************tx request*************************************************************************
assign user_define_data_flag     = device_rc ? apb_cmd_reg[8]  : 1'b0;  //0:use ram data; 1:use user define data
assign dma_32_64_addr_cmd_flag   = device_rc ? apb_cmd_reg[16] : (device_ep ? dma_cmd_reg[16] : 1'b0);  //0:32; 1:64;
assign dma_wr_rd_cmd_flag        = device_rc ? apb_cmd_reg[24] : (device_ep ? dma_cmd_reg[24] : 1'b0);  //0:read; 1:write;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_user_define_data_flag <= 1'd0;
    else
        o_user_define_data_flag <= user_define_data_flag;
end

//gen req valid
assign mwr32_req_vld = !dma_32_64_addr_cmd_flag &&  dma_wr_rd_cmd_flag && cmd_reg_cfg_done && l_addr_cfg_done && !cross_4kb_boundary;
assign mwr64_req_vld =  dma_32_64_addr_cmd_flag &&  dma_wr_rd_cmd_flag && cmd_reg_cfg_done && l_addr_cfg_done && h_addr_cfg_done && !cross_4kb_boundary;
assign mrd32_req_vld = !dma_32_64_addr_cmd_flag && !dma_wr_rd_cmd_flag && cmd_reg_cfg_done && l_addr_cfg_done && !cross_4kb_boundary;
assign mrd64_req_vld =  dma_32_64_addr_cmd_flag && !dma_wr_rd_cmd_flag && cmd_reg_cfg_done && l_addr_cfg_done && h_addr_cfg_done && !cross_4kb_boundary;

//mwr_32_req
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_mwr32_req <= 1'b0;
    else if(i_mwr32_req_ack)
        o_mwr32_req <= 1'b0;
    else if(mwr32_req_vld)
    begin
        if(!user_define_data_flag)              ////这里就可以放almost_full
            o_mwr32_req  <= 1'b1;
        else if(apb_data_cfg_done)
            o_mwr32_req  <= 1'b1;
        else
            o_mwr32_req  <= 1'b0;
    end
end

//mwr_64_req
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_mwr64_req <= 1'b0;
    else if(i_mwr64_req_ack)
        o_mwr64_req <= 1'b0;
    else if(mwr64_req_vld)
    begin
        if(!user_define_data_flag)
            o_mwr64_req  <= 1'b1;
        else if(apb_data_cfg_done)
            o_mwr64_req  <= 1'b1;
        else
            o_mwr64_req  <= 1'b0;
    end
end
//mrd_32_req
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_mrd32_req <= 1'b0;
    else if(i_mrd32_req_ack)
        o_mrd32_req <= 1'b0;
    else if(mrd32_req_vld)
        o_mrd32_req  <= 1'b1;
end

//mrd_64_req
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_mrd64_req <= 1'b0;
    else if(i_mrd64_req_ack)
        o_mrd64_req <= 1'b0;
    else if(mrd64_req_vld)
        o_mrd64_req  <= 1'b1;
end

//**********************************************************************apb_read***************************************************************************
// 关键修复: 在 chunk 边界处, ack_rcv 会将所有 cfg_done 清零, 导致请求 FSM 无法
// 在下一个周期重新发起请求.
// 解决方案: 将 cfg_done 的"重置"和"重置后立即重新置位"分成两个 always 块执行.
// chunk_done_d1 脉冲时触发重新置位, 让请求 FSM 在同一时钟周期内识别到所有配置就绪,
// 并用新的 req_length/req_addr/ddr3_addr/ddr3_length 发起下一个 chunk 的请求.
//**************************************************************************************************************************************
assign apb_read  = i_apb_psel && i_apb_penable && ~i_apb_pwrite ;

assign dma_check_success = ~(|i_dma_check_result);

assign dma_check_success = ~(|i_dma_check_result);

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_apb_prdata <= 32'd0;
    else if(apb_read)
        case(i_apb_paddr)
            9'h100: o_apb_prdata <= dma_cmd_reg;
            9'h110: o_apb_prdata <= dma_cmd_l_addr;
            9'h120: o_apb_prdata <= dma_cmd_h_addr;
            
            9'h140: o_apb_prdata <= apb_cmd_reg;
            9'h150: o_apb_prdata <= {22'b0,apb_cmd_length};
            9'h160: o_apb_prdata <= apb_cmd_l_addr;
            9'h170: o_apb_prdata <= apb_cmd_h_addr;
            9'h180: o_apb_prdata <= apb_cmd_data;
            9'h190: o_apb_prdata <= i_dma_check_result[31:0];
            9'h1A0: o_apb_prdata <= i_dma_check_result[63:32];
            9'h1B0: o_apb_prdata <= {31'b0,dma_check_success};
            9'h1C0: o_apb_prdata <= apb_ddr3_addr;      // RC DDR3 地址回读
            9'h1D0: o_apb_prdata <= apb_total_length;  // RC TOTAL_LENGTH

            // EP 寄存器 (BAR1 地址，从 APB 回读时也用同一地址数字)
            // 0x1E0 = dma_ddr3_addr (仍在使用，告知 FPGA DDR3 读写起始地址)
            // 0x1F0 = 原 ddr3_length 寄存器，已删除（由 total_length 推导）
            10'h200: o_apb_prdata <= dma_total_length;   // EP TOTAL_LENGTH (BAR1 0x200)
            10'h210: o_apb_prdata <= chunk_rem_bytes;   // chunk 剩余字节数
            10'h220: o_apb_prdata <= {chunk_loop_active, 15'b0, chunk_count}; // chunk FSM 状态
            10'h230: o_apb_prdata <= o_ddr3_addr;      // 当前 DDR3 地址
            10'h240: o_apb_prdata <= o_ddr3_length;    // 当前 DDR3 chunk 长度
            10'h250: o_apb_prdata <= {22'b0, o_req_length}; // 当前 TLP 长度 DW

            default: o_apb_prdata <= 32'd0;
        endcase
end
//apb_rdy
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_apb_prdy <= 1'b0;
    else if(i_apb_psel && i_apb_penable && !o_apb_prdy)
        o_apb_prdy <= 1'b1;
    else
        o_apb_prdy <= 1'b0;
end

assign o_tx_restart = i_bar1_wr_en && (i_bar1_wr_addr[9:0] == 9'h110);

//detect 4-KB boundary
assign req_l_addr = device_rc ? apb_cmd_l_addr[12:0] : dma_cmd_l_addr[12:0];

assign total_data   = ~((device_rc && apb_length_cfg_done) || (device_ep && dma_ctrl_cfg_done)) ? 13'd0 :
                        {1'b0, o_req_length[9:0], 2'b0}; // o_req_length = 传输 DW 数，乘4得字节数

assign target_addr  = ~l_addr_cfg_done ? 13'd0 : (req_l_addr[12:0] + total_data);

assign cross_4kb_boundary = ~l_addr_cfg_done ? 1'b0 :
                            (target_addr[12] == req_l_addr[12]) ? 1'b0 : |target_addr[11:0];

//4-KB boundary flag
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_cross_4kb_boundary <= 1'b0;
    else if(cross_4kb_boundary)
        o_cross_4kb_boundary <= 1'b1;
    else if(cmd_reg_cfg_done)
        o_cross_4kb_boundary <= 1'b0;
end







//**********************************************************************
// MSI Interrupt Generation Logic (Supports both TX/MWr and RX/MRd)
//**********************************************************************

// 1. 打两拍防亚稳态并提取 TX (写 DDR3 -> CPU) 忙信号的下降沿
reg mwr_tx_busy_d1, mwr_tx_busy_d2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mwr_tx_busy_d1 <= 1'b0;
        mwr_tx_busy_d2 <= 1'b0;
    end else begin
        mwr_tx_busy_d1 <= i_mwr_tx_busy;
        mwr_tx_busy_d2 <= mwr_tx_busy_d1;
    end
end
wire tx_done_pulse = ~mwr_tx_busy_d1 & mwr_tx_busy_d2;

// 2. 打两拍防亚稳态并提取 RX (读 CPU -> DDR3) 忙信号的下降沿
reg mrd_rx_busy_d1, mrd_rx_busy_d2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mrd_rx_busy_d1 <= 1'b0;
        mrd_rx_busy_d2 <= 1'b0;
    end else begin
        mrd_rx_busy_d1 <= i_mrd_rx_busy;
        mrd_rx_busy_d2 <= mrd_rx_busy_d1;
    end
end
wire rx_done_pulse = ~mrd_rx_busy_d1 & mrd_rx_busy_d2;

// 3. DMA 活跃状态跟踪 (防止意外跳变引起虚假中断)
reg tx_active, rx_active;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_active <= 1'b0;
        rx_active <= 1'b0;
    end else begin
        // 监控 TX 状态
        if (o_mwr32_req || o_mwr64_req) tx_active <= 1'b1;
        else if (tx_done_pulse)         tx_active <= 1'b0;
        
        // 监控 RX 状态
        if (o_mrd32_req || o_mrd64_req) rx_active <= 1'b1;
        else if (rx_done_pulse)         rx_active <= 1'b0;
    end
end



// 5. 判断是否为最后一个chunk
// 注意: 在 chunk_done 上升沿时刻, chunk_rem_bytes 尚未被更新 (always块按顺序执行)
// 此时 chunk_rem_bytes 仍表示当前 chunk 的剩余字节数.
// 当 (chunk_rem_bytes <= CHUNK_SIZE_MAX) 时, 当前 chunk 就是最后一个.
wire is_final_chunk = (chunk_rem_bytes <= CHUNK_SIZE_MAX);

// 5b. is_final_chunk 延迟一拍: 在 chunk_done 上升沿所在周期, is_final_chunk 已经在
// 同一非阻塞赋值的同一 always 块中变为 false.
// 所以 o_fpga_msi 的条件判断里必须用上一周期的 is_final_chunk 值.
// 即: "上一个chunk是最后一个chunk" = is_final_chunk_d1.
reg is_final_chunk_d1;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        is_final_chunk_d1 <= 1'b0;
    else
        is_final_chunk_d1 <= is_final_chunk;
end

// 6. 触发 MSI 脉冲：只在最后一chunk完成时发一次MSI
// is_final_chunk_d1 = 1 means "the chunk that just completed (chunk_done) was the last one"
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_fpga_msi <= 1'b0;
    end
    else if (chunk_loop_active && chunk_done && is_final_chunk_d1) begin
        o_fpga_msi <= 1'b1;  // 最后一chunk完成 -> 发MSI
    end
    else if (!chunk_loop_active && ((tx_done_pulse && tx_active) || (rx_done_pulse && rx_active))) begin
        o_fpga_msi <= 1'b1;  // 单chunk模式，兼容旧流程
    end
    else begin
        o_fpga_msi <= 1'b0;
    end
end






endmodule
