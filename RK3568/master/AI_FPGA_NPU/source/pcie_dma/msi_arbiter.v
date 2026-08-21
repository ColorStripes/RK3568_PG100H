/*===============================================================
MSI�ж��ٲ��� (msi_arbiter.v)
===============================================================
  ��������:
    - �������MSI�ж���������ȼ��ٲ�
    - ��dma_active=1ʱ������Ӧmsi[0]��DMA����ж�
    - cfg_msi_en���������ж�ʹ��
    - ͨ��ven_msi_req/ven_msi_grant�ӿ���PCIe����ͨ��
    - ven_msi_grant��1bit�����źţ��������ven_msi_vector��Ӧ��pendingλ
    - ven_msi_vector��ʾ��ǰ���������ж�������

  �������:
    - KISSԭ�򣺼�ֱ�ۣ�����ά���͵���
    - ���ȼ��̶����ж�0���ȼ���ߣ����εݼ�
===============================================================*/

module msi_arbiter #(
    parameter MSI_NUM = 5  // MSI�ж�����
)(
    input clk,              // ʱ���ź�
    input rst,              // �첽��λ������Ч

    input       cfg_msi_en/* synthesis PAP_MARK_DEBUG="true" */, // MSIʹ�ܼĴ�����Ϊ0ʱ���������ж�
    input       dma_active/* synthesis PAP_MARK_DEBUG="true" */, // DMA���־��Ϊ1ʱ������Ӧmsi[0]

    input      [MSI_NUM-1 : 0] msi_req      /* synthesis PAP_MARK_DEBUG="true" */,           // MSI�ж������źţ����Ը�����
    output reg [MSI_NUM-1 : 0] msi_grant    /* synthesis PAP_MARK_DEBUG="true" */,      // �ٲý��grant�ź�

    output reg                 ven_msi_req      /* synthesis PAP_MARK_DEBUG="true" */,   // ��PCIe�������͵��ж�����
    input                      ven_msi_grant    /* synthesis PAP_MARK_DEBUG="true" */, // PCIe����������Ӧ���ź�1bit����
    output reg     [4 : 0]     ven_msi_vector   /* synthesis PAP_MARK_DEBUG="true" */, // ��ǰ�ٲ�ѡ�е��ж�������
     
    output      [31 : 0]       cfg_msi_pending  /* synthesis PAP_MARK_DEBUG="true" */ // MSI�������ж�״̬�Ĵ���
);

    // �ж������Ĵ���
    reg [MSI_NUM-1 : 0] ven_msi_vector_r;
    // �ٲý������
    always @(*) begin
        case(ven_msi_vector_r)
            5'b00001:
                ven_msi_vector = 5'd0;         //DMA
            5'b00010:
                ven_msi_vector = 5'd1;         //CMA 
            5'b00100:
                ven_msi_vector = 5'd1;         //CAM
            5'b01000:
                ven_msi_vector = 5'd2;
            5'b10000:
                ven_msi_vector = 5'd3;
            default:
                ven_msi_vector = 5'd0;
        endcase
    end

/*---------------------------------------------------------------
�źŶ���
---------------------------------------------------------------*/
// msi_req��һ�����ڱ��ؼ��
reg [MSI_NUM-1 : 0] msi_d1;
// ���msi_req�������أ������жϵ���
wire [MSI_NUM-1 : 0] msi_rise;
// �ж�pendingλ���յ�������1��grant����0
reg  [MSI_NUM-1 : 0] msi_pending;
// ��Ч�ж��źţ�pending��ʹ���߼������õ�
wire [MSI_NUM-1 : 0] msi_valid;
// �ٲý����one-hot����
reg  [MSI_NUM-1 : 0] msi_arb;
/*-------------------------------------------------------------*/

/*---------------------------------------------------------------
��msi_req��һ�����ڱ��ؼ��
msi_rise[i] = 1 ��ʾmsi[i]���µ������ص���
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_d1 <= {MSI_NUM{1'b0}};  // ��λ����
    end else begin
        msi_d1 <= msi_req;              // ��һ���ӳ�
    end
end

// �����ؼ�⣺��ǰΪ1����һ����Ϊ0
assign msi_rise = msi_req & ~msi_d1;

/*---------------------------------------------------------------
ά��pending״̬λ
- ���µ�������ʱ��1��ʾ�жϴ�����
- ven_msi_grantʱ����ven_msi_vector�����Ӧλ
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_pending <= {MSI_NUM{1'b0}};  // ��λ����
    end else if (ven_msi_grant) begin
        msi_pending <= msi_pending & ~ven_msi_vector_r;  // grant�������Ӧpendingλ
    end else begin
        msi_pending <= msi_pending | msi_rise;         // ���жϵ�������λpending
    end
end

/*---------------------------------------------------------------
�ٲ�ʹ���߼�
- cfg_msi_en=1 �� msi_pending=1 ʱ���������ٲ�
- dma_active=1ʱ��·�ٲ�ֱ����Ӧmsi[0]��DMA����ж�
---------------------------------------------------------------*/
assign msi_valid = (cfg_msi_en && !dma_active) ? msi_pending :   // ����ģʽ��pendingλ��Ч
                   (cfg_msi_en &&  dma_active) ? { {(MSI_NUM-1){1'b0}}, msi_pending[0] } :  // DMAģʽ����msi[0]��Ч
                   {MSI_NUM{1'b0}};  // MSI�ر�ʱ������Ч�ź�����

/*---------------------------------------------------------------
�̶����ȼ��ٲã�msi[0] > msi_req[1] > ... > msi_req[MSI_NUM-1]
�����ȼ��ж����Ǳ�����ѡ�У������ȼ�ֻ���ڸ����ȼ�������ʱ�ſ��ܱ�ѡ��
---------------------------------------------------------------*/
always @(*) begin
    msi_arb = {MSI_NUM{1'b0}};  // Ĭ��ȫ��
    if (msi_valid[0]) begin
        msi_arb = 5'b00001;     // ѡ��������ȼ�msi[0]
    end 
    else if (msi_valid[1]) begin
        msi_arb = 5'b00010;     // ѡ��msi[1]
    end 
    else if (msi_valid[2]) begin
        msi_arb = 5'b00100;     // msi_req[2]
    end 
    else if (msi_valid[3]) begin
        msi_arb = 5'b01000;     // msi_req[3]
    end 
    else if (msi_valid[4]) begin
        msi_arb = 5'b10000;     // ѡ��������ȼ�msi[4]
    end
end

/*---------------------------------------------------------------
ven_msi_vector_r�Ĵ����������ٲ�ѡ�е��ж�����
- �����µ��ٲý��ʱ����
- grant�󱣳ֲ���ֱ���µ��ٲý������
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ven_msi_vector_r <= {MSI_NUM{1'b0}};  // ��λ����
    end
    else if (|msi_arb) begin
        ven_msi_vector_r <= msi_arb;           // �����ٲý��  //grant���λ���㲻��Ӱ������ٲ�
    end
end

/*---------------------------------------------------------------
ven_msi_req��������ź�
- ���ٲý��ʱ��������
- grant������
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ven_msi_req <= 1'b0;                // ��λ����
    end 
    else if (ven_msi_grant) begin
        ven_msi_req <= 1'b0;                // grant������
    end 
    else if (|msi_arb) begin
        ven_msi_req <= 1'b1;                // ���ٲý��ʱ����
    end
end

/*---------------------------------------------------------------
msi_grant�������ӳ��ǰgrant״̬
ven_msi_grant����ʱ����ven_msi_vector����grant�ź�
---------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        msi_grant <= {MSI_NUM{1'b0}};       // ��λ����
    end else if (ven_msi_grant) begin
        msi_grant <= ven_msi_vector_r;        // grantʱ���ٲý����Ϊgrant�ź�
    end else begin
        msi_grant <= {MSI_NUM{1'b0}};       // grant����������
    end
end

/*---------------------------------------------------------------
cfg_msi_pending�������ӳ���д������жϵ�״̬
��5λ��Ӧ5��MSI�жϵ�pending״̬
---------------------------------------------------------------*/
assign cfg_msi_pending = {27'b0, msi_pending};  // ��չ��32λ�Ĵ�������

endmodule