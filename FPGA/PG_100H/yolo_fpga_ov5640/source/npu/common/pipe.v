/*
    无气泡传输插入寄存器（双向切断）
*/
`timescale 1ns/1ps

module pipe #(
    parameter WIDTH = 32	
) (
    input                   clk,
    input                   rst,

    // 上游接口 (Upstream)
    input                   up_valid,
    output                  up_ready,
    input      [WIDTH-1:0]  data_in,

    // 下游接口 (Downstream)
    output                  down_valid,
    input                   down_ready,
    output     [WIDTH-1:0]  data_out
);

  // ==========================================================
  // 第一级：防滑缓冲级 (Skid Buffer / 原 s2mPipe)
  // ==========================================================
  wire                           skid_valid;
  reg                            skid_ready;
  wire       [WIDTH - 1:0]       skid_data;
  
  reg                            up_rValidN;     // 标记防滑寄存器是否为空 (1: 空, 0: 满)
  reg        [WIDTH - 1:0]       up_rData;       // 防滑数据寄存器 (用于暂存刹不住的数据)
  
  // ==========================================================
  // 第二级：输出寄存器级 (Output Register / 原 m2sPipe)
  // ==========================================================
  wire                           out_valid;
  wire                           out_ready;
  wire       [WIDTH - 1:0]       out_data;
  
  reg                            out_rValid;     // 输出级有效信号寄存器
  reg        [WIDTH - 1:0]       out_rData;      // 输出级数据寄存器
  
  wire                           out_is_empty;

  // ----------------------------------------------------------
  // 核心组合逻辑连线
  // ----------------------------------------------------------
  
  // 【切断反向 ready】上游看到的 ready 完全由本地的空满标志决定
  assign up_ready = up_rValidN;
  
  // 防滑级数据有效：上游来了新数据，或者防滑寄存器里本身就积压了历史数据
  assign skid_valid = (up_valid || (! up_rValidN));
  
  // 防滑级数据选择：防滑寄存器空时透传新数据，满时使用积压数据
  assign skid_data = (up_rValidN ? data_in : up_rData);
  
  // 防滑级的向后推进逻辑：如果下游 ready 了，或者输出级目前是空的，就可以往后推数据
  always @(*) begin
    skid_ready = out_ready;
    if(out_is_empty) begin
      skid_ready = 1'b1;
    end
  end

  assign out_is_empty = (! out_valid);
  assign out_valid = out_rValid;
  assign out_data = out_rData;
  
  // 【切断前向 valid/data】下游看到的信号完全来自输出级寄存器
  assign down_valid = out_valid;
  assign out_ready  = down_ready;
  assign data_out   = out_data;
  
  // ----------------------------------------------------------
  // 状态机与控制信号时序逻辑
  // ----------------------------------------------------------
  always @(posedge clk) begin
    if(rst) begin
      up_rValidN <= 1'b1;   // 复位时：防滑寄存器初始为空 (1代表Empty)
      out_rValid <= 1'b0;   // 复位时：输出级有效信号拉低
    end else begin
      // 维护防滑寄存器的空/满状态
      if(up_valid) begin
        up_rValidN <= 1'b0; // 只要上游发有效数据，默认防滑寄存器被占用 (变为0)
      end
      if(skid_ready) begin
        up_rValidN <= 1'b1; // 如果数据成功向后流动了，防滑寄存器重新变为空 (变为1，此句优先级更高)
      end
      
      // 维护输出级的有效状态
      if(skid_ready) begin
        out_rValid <= skid_valid; // 往下游推数据时，同步更新输出寄存器的 valid 状态
      end
    end
  end

  // ----------------------------------------------------------
  // 数据路径时序逻辑
  // ----------------------------------------------------------
  always @(posedge clk) begin
    // 第一级：抓取上游数据（仅在本地准备好接收时）
    if(up_ready) begin
      up_rData <= data_in;
    end
    
    // 第二级：将数据锁入最终的输出寄存器
    if(skid_ready) begin
      out_rData <= skid_data;
    end
  end

endmodule