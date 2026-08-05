/*===============================================================
MSI中断仲裁器 (msi_arbiter.v)
===============================================================
  功能描述:
    - 管理多个MSI中断请求的优先级仲裁
    - 当dma_active=1时优先响应msi[0]的DMA完成中断
    - cfg_msi_en控制整体中断使能
    - 通过ven_msi_req/ven_msi_grant接口与PCIe主机通信
    - ven_msi_grant是1bit握手信号，用于清除ven_msi_vector对应的pending位
    - ven_msi_vector表示当前待处理的中断向量号

  设计理念:
    - KISS原则：简单直观，易于维护和调试
    - 优先级固定：中断0优先级最高，依次递减
===============================================================*/

module msi_arbiter #(
    parameter MSI_NUM = 5  // MSI中断数量
)(
    input clk,              // 时钟信号
    input rst,              // 异步复位，高有效

    input       cfg_msi_en/* synthesis PAP_MARK_DEBUG="true" */, // MSI使能寄存器，为0时屏蔽所有中断
    input       dma_active/* synthesis PAP_MARK_DEBUG="true" */, // DMA活动标志，为1时优先响应msi[0]

    input      [MSI_NUM-1 : 0] msi_req      /* synthesis PAP_MARK_DEBUG="true" */,           // MSI中断请求信号，来自各外设
    output reg [MSI_NUM-1 : 0] msi_grant    /* synthesis PAP_MARK_DEBUG="true" */,      // 仲裁结果grant信号

    output reg                 ven_msi_req      /* synthesis PAP_MARK_DEBUG="true" */,   // 向PCIe主机发送的中断请求
    input                      ven_msi_grant    /* synthesis PAP_MARK_DEBUG="true" */, // PCIe主机的握手应答信号1bit握手
    output reg     [4 : 0]     ven_msi_vector   /* synthesis PAP_MARK_DEBUG="true" */, // 当前仲裁选中的中断向量号
     
    output      [31 : 0]       cfg_msi_pending  /* synthesis PAP_MARK_DEBUG="true" */ // MSI待处理中断状态寄存器
);

    // 中断向量寄存器
    reg [MSI_NUM-1 : 0] ven_msi_vector_r;
    // 仲裁结果编码
    always @(*) begin
        case(ven_msi_vector_r)
            5'b00001:
                ven_msi_vector = 5'd0;         //DMA
            5'b00010:
                ven_msi_vector = 5'd1;         //CMA 
            5'b00100:
                ven_msi_vector = 5'd1;         //CAM
            5'b01000:
                ven_msi_vector = 5'd3;
            5'b10000:
                ven_msi_vector = 5'd4;
            default:
                ven_msi_vector = 5'd0;
        endcase
    end

/*---------------------------------------------------------------
信号定义
---------------------------------------------------------------*/
// msi_req打一拍用于边沿检测
reg [MSI_NUM-1 : 0] msi_d1;
// 检测msi_req的上升沿，即新中断到来
wire [MSI_NUM-1 : 0] msi_rise;
// 中断pending位，收到请求置1，grant后清0
reg  [MSI_NUM-1 : 0] msi_pending;
// 有效中断信号，pending与使能逻辑运算后得到
wire [MSI_NUM-1 : 0] msi_valid;
// 仲裁结果，one-hot编码
reg  [MSI_NUM-1 : 0] msi_arb;
/*-------------------------------------------------------------*/

/*---------------------------------------------------------------
对msi_req打一拍用于边沿检测
msi_rise[i] = 1 表示msi[i]有新的上升沿到来
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_d1 <= {MSI_NUM{1'b0}};  // 复位清零
    end else begin
        msi_d1 <= msi_req;              // 打一拍延迟
    end
end

// 上升沿检测：当前为1且上一周期为0
assign msi_rise = msi_req & ~msi_d1;

/*---------------------------------------------------------------
维护pending状态位
- 有新的上升沿时置1表示中断待处理
- ven_msi_grant时根据ven_msi_vector清零对应位
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_pending <= {MSI_NUM{1'b0}};  // 复位清零
    end else if (ven_msi_grant) begin
        msi_pending <= msi_pending & ~ven_msi_vector_r;  // grant后清除对应pending位
    end else begin
        msi_pending <= msi_pending | msi_rise;         // 新中断到来则置位pending
    end
end

/*---------------------------------------------------------------
仲裁使能逻辑
- cfg_msi_en=1 且 msi_pending=1 时正常进行仲裁
- dma_active=1时旁路仲裁直接响应msi[0]的DMA完成中断
---------------------------------------------------------------*/
assign msi_valid = (cfg_msi_en && !dma_active) ? msi_pending :   // 正常模式：pending位有效
                   (cfg_msi_en &&  dma_active) ? { {(MSI_NUM-1){1'b0}}, msi_pending[0] } :  // DMA模式：仅msi[0]有效
                   {MSI_NUM{1'b0}};  // MSI关闭时所有有效信号清零

/*---------------------------------------------------------------
固定优先级仲裁：msi[0] > msi_req[1] > ... > msi_req[MSI_NUM-1]
高优先级中断总是被优先选中，低优先级只有在高优先级无请求时才可能被选中
---------------------------------------------------------------*/
always @(*) begin
    msi_arb = {MSI_NUM{1'b0}};  // 默认全零
    if (msi_valid[0]) begin
        msi_arb = 5'b00001;     // 选中最高优先级msi[0]
    end 
    else if (msi_valid[1]) begin
        msi_arb = 5'b00010;     // 选中msi[1]
    end 
    else if (msi_valid[2]) begin
        msi_arb = 5'b00100;     // msi_req[2]
    end 
    else if (msi_valid[3]) begin
        msi_arb = 5'b01000;     // msi_req[3]
    end 
    else if (msi_valid[4]) begin
        msi_arb = 5'b10000;     // 选中最低优先级msi[4]
    end
end

/*---------------------------------------------------------------
ven_msi_vector_r寄存器：保存仲裁选中的中断向量
- 当有新的仲裁结果时更新
- grant后保持不变直到新的仲裁结果到来
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ven_msi_vector_r <= {MSI_NUM{1'b0}};  // 复位清零
    end
    else if (|msi_arb) begin
        ven_msi_vector_r <= msi_arb;           // 更新仲裁结果  //grant后此位清零不会影响后续仲裁
    end
end

/*---------------------------------------------------------------
ven_msi_req输出请求信号
- 有仲裁结果时拉高请求
- grant后拉低
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ven_msi_req <= 1'b0;                // 复位清零
    end 
    else if (ven_msi_grant) begin
        ven_msi_req <= 1'b0;                // grant后清零
    end 
    else if (|msi_arb) begin
        ven_msi_req <= 1'b1;                // 有仲裁结果时请求
    end
end

/*---------------------------------------------------------------
msi_grant输出：反映当前grant状态
ven_msi_grant到来时根据ven_msi_vector更新grant信号
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_grant <= {MSI_NUM{1'b0}};       // 复位清零
    end else if (ven_msi_grant) begin
        msi_grant <= ven_msi_vector_r;        // grant时将仲裁结果作为grant信号
    end else begin
        msi_grant <= {MSI_NUM{1'b0}};       // grant结束后清零
    end
end

/*---------------------------------------------------------------
cfg_msi_pending输出：反映所有待处理中断的状态
低5位对应5个MSI中断的pending状态
---------------------------------------------------------------*/
assign cfg_msi_pending = {27'b0, msi_pending};  // 扩展到32位寄存器宽度

endmodule