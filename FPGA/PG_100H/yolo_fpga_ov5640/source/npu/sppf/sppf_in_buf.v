module sppf_in_buf #(
    parameter CHA_PAR_IN = 16,                          //����ͨ�����ж�
              INT = 8,
              DATA_WIDTH = CHA_PAR_IN * INT,            //���ݴ���λ��    ���벢�ж� * INT8
              DATA_DEPTH = 512,                         //�������  ������ W*channal/���ж�  RAM������Ӧ�ô���һ�����������ֽڸ���
              ADDR_WIDTH = $clog2(DATA_DEPTH),          //��ַλ��
              READ_DELAY = 2                            //������������Ҫ���ӳ�
              
)
(
    input          clk,
    input          rst,

    //һ�ζ�ȡ���жȸ��ֽ��� ��Ҫ��ȡ���ٴβ��ܰ�һ�����ݶ��� read_num = col * channel / CHA_PAR_IN
    input  [ADDR_WIDTH : 0]   read_num, 

    //��ǰģ���������
    input  [DATA_WIDTH-1 : 0]   s_data,
    input                       s_valid,
    input                       s_last,
    output                      s_ready,

    //�¼�ģ���������
    input                       m_req,
    output [DATA_WIDTH-1 : 0]   m_data,
    output                      m_valid,
    output                      m_last
                                          
);


    reg [ADDR_WIDTH-1 : 0] waddr;
    reg [ADDR_WIDTH-1 : 0] raddr;
    reg r_last; 

    //״̬��
    localparam WRITE = 4'b0001, WAIT = 4'b0010, READ = 4'b0100, LAST = 4'b1000;
    reg [3 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= WRITE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            WRITE:begin
                if(s_valid & s_last) begin
                    next_state = WAIT;
                end
                else begin
                    next_state = WRITE;
                end
            end
            WAIT:begin
                if(m_req) begin
                    next_state = READ;
                end
                else begin
                    next_state = WAIT;
                end
            end
            READ:begin
                if(r_last) begin
                    next_state = LAST;
                end
                else begin
                    next_state = READ;
                end
            end
            LAST:begin
                if(m_last) begin
                    next_state = WRITE;
                end
                else begin
                    next_state = LAST;
                end
            end
            default:begin
                next_state = WRITE;
            end
        endcase
    end

    //дʱ��
    assign s_ready = (state == WRITE);
    wire wen = s_valid & s_ready;
    always @(posedge clk) begin                                        
        if(rst) begin
            waddr <= 0;
        end                                                                                                                                          
        else if(state == WRITE) begin
            if(wen) begin
                waddr <= waddr + 1'b1;
            end
        end
        else begin
            waddr <= 0;
        end                                   
    end

    //��ʱ��                                     
    wire ren = (state == READ);
    wire r_valid = ren;
    always @(posedge clk) begin                                        
        if(rst) begin
            raddr <= 0;
        end                                                                                                                                          
        else if(ren) begin
            raddr <= raddr + 1'b1;
        end
        else begin
            raddr <= 0;
        end                                   
    end
                                 
    always @(posedge clk) begin
        if(rst) begin
            r_last <= 1'b0;
        end
        else if(raddr == read_num - 2) begin    //���ĵ������-2�Ľ���
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
            m_valid_d <= 0;
            m_last_d <= 0;
        end
        else begin
            m_valid_d  <= {m_valid_d[READ_DELAY-1 : 0] , r_valid};
            m_last_d <= {m_last_d[READ_DELAY-1 : 0] , r_last};
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
        .wdata (s_data ),
        .wen   (wen   ),
        .waddr (waddr ),
        .ren   (ren   ),
        .raddr (raddr ),
        .rdata (m_data )
    );

endmodule