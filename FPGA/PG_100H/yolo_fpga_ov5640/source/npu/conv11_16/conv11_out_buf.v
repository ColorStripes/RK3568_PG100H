module conv11_out_buf #(
    parameter CHA_PAR_OUT = 8,                          //���ͨ�����ж�
              CHA_IMG_OUT = 128,                        //ͼƬ������ͨ����
              MAX_CALULATE_NUM = (CHA_IMG_OUT / CHA_PAR_OUT),   //�������
              CALULATE_CNT_WIDTH = $clog2(MAX_CALULATE_NUM),
              INT = 8,                                  //ÿ������λ��
              DATA_WIDTH = CHA_PAR_OUT * INT,           //���ݴ���λ��    ������ж� * INT8
              DATA_DEPTH = 5120,                        //�������  ������ W*channal/���ж�  RAM������Ӧ�ô���һ�����������ֽڸ���
              ADDR_WIDTH = $clog2(DATA_DEPTH),          //��ַλ��
              READ_DELAY = 1                            //������������Ҫ���ӳ�
)
(
    input          clk,
    input          rst,

    input          start,
    input [CALULATE_CNT_WIDTH : 0]  calculate_cout_num,      //���������� 

    //��ǰģ���������
    //CHA_PAR_OUT�����
    input [DATA_WIDTH-1 : 0]    s_data ,
    input                       s_valid,
    input                       s_last ,
    output                      s_req,                  //req���������������������һ�� ready�������� �������һ�� �������һ��������              


    //�¼�ģ���������
    output [DATA_WIDTH-1 : 0]   m_data ,
    output                      m_last ,
    output                      m_valid,
    input                       m_req                   //������m_req ��Ϊ���¼�FIFO����

);


    reg [ADDR_WIDTH-1 : 0] waddr;
    reg [ADDR_WIDTH-1 : 0] raddr;
    reg r_last;


    //��ʼ����
    reg [CALULATE_CNT_WIDTH : 0]  calculate_cout_num_r;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cout_num_r <= 0;
        end
        else if(start) begin
            calculate_cout_num_r <= calculate_cout_num;
        end
    end

    //״̬��
    localparam IDLE = 5'b00001, WRITE = 5'b00010, W_WAIT = 5'b00100, R_WAIT = 5'b01000, READ = 5'b10000;
    reg [4 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE:begin
                next_state = WRITE;
            end
            WRITE:begin
                if(s_last & s_valid) begin
                    next_state = W_WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            W_WAIT:begin
                if(calculate_cnt == calculate_cout_num_r) begin
                    next_state = R_WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            R_WAIT:begin
                if(m_req) begin
                    next_state = READ;
                end
                else begin
                    next_state = R_WAIT;
                end
            end
            READ:begin
                if(m_valid & m_last) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = READ;
                end
            end
            default:begin
                next_state = IDLE;
            end
        endcase
    end

    //���������(��row_cntһ�� ���������� �������ж�)
    reg [CALULATE_CNT_WIDTH : 0] calculate_cnt;
    always @(posedge clk) begin
        if(rst) begin
            calculate_cnt <= 0;
        end
        else if(state == READ) begin
            calculate_cnt <= 0;
        end
        else if(s_last & s_valid) begin
            calculate_cnt <= calculate_cnt + 1;    //�ɹ����ǰ���жȸ�ͨ������һ��
        end 
    end




    //дʱ��
    wire wen = s_valid;                         //ֻҪ��Ч��д ��Ϊ��Ĭ�Ͻ���һ������
    //wire [DATA_WIDTH-1 : 0] wdata = {s_data_7, s_data_6, s_data_5, s_data_4, s_data_3, s_data_2, s_data_1, s_data_0};
    wire [DATA_WIDTH-1 : 0] wdata = s_data;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            waddr <= 0;
        end
        else if(state == WRITE) begin
            if(wen) begin
                waddr <= waddr + calculate_cout_num_r;         //���з�ʽ���� ǰ����ͨ�� ����ͨ��
            end
        end
        else begin
            waddr <= calculate_cnt;
        end                                  
    end
    

    //��д������
    reg [ADDR_WIDTH-1 : 0] w_r_cnt;
    always @(posedge clk) begin
        if(rst) begin
            w_r_cnt <= 0;
        end
        else if(wen) begin
            w_r_cnt <= w_r_cnt + 1;
        end
        else if(ren) begin
            w_r_cnt <= w_r_cnt - 1;
        end
    end

    //���ϼ���������
    reg s_req_r;
    always @(posedge clk ) begin
        if(rst) begin
            s_req_r <= 1'b0;
        end
        else if((state != WRITE) && (next_state == WRITE)) begin
            s_req_r <= 1'b1;
        end
        else if(s_valid) begin                                          //��������������
            s_req_r <= 1'b0; 
        end
    end
    assign s_req = s_req_r;

    //��ʱ��                                     
    wire ren = (w_r_cnt > 0) && (state == READ);
    wire r_valid = ren;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr <= 0;
        end                                                                                                                                          
        else if(state == READ) begin
            if(ren) begin
                raddr <= raddr + 1'b1;
            end
        end
        else begin
            raddr <= 0;
        end                                   
    end

                                
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if((w_r_cnt == 2) & ren) begin
            r_last <= 1'b1;
        end
        else begin
            r_last <= 1'b0;
        end
    end


    //�������ӳ�  �����´���ȫ����spram���ӳ��йأ�
    reg [READ_DELAY-1 : 0] m_valid_d, m_last_d; 
    always @(posedge clk ) begin
        if(rst) begin
            m_valid_d  <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d <= {m_valid_d[READ_DELAY-1 : 0], r_valid};
            m_last_d  <= {m_last_d[READ_DELAY-1 : 0], r_last};
        end
    end

    //���ʱ��
    assign m_valid = m_valid_d[READ_DELAY-1];
    assign m_last = m_last_d[READ_DELAY-1];

    spram #(.DP(DATA_DEPTH),    //�洢��Ԫ���
            .DW(DATA_WIDTH),    //����λ��
            .PIPE(READ_DELAY)  
    ) spram_inst
    (
        .clk   (clk   ),
        .wdata (wdata ),
        .wen   (wen   ),
        .waddr (waddr ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (m_data)
    );




endmodule