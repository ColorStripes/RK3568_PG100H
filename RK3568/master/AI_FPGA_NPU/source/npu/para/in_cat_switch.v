module in_cat_switch #(
    // parameter START_NUM = 2,
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_IN = 16,                          //输入通道并行度
              INT = 8,                                  //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT            //数据传输位宽    并行度 * INT8
)
(
    input clk,
    input rst,


    input  start_para  ,

    input  [DATA_WIDTH-1 : 0]      s_data      ,
    input                          s_valid     ,
    input                          s_last      ,
    output                         s_ready     ,

    output [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  s_cmd_len   ,
    output                         s_cmd_valid ,
    input                          s_cmd_ready ,

    input  [DATA_WIDTH-1 : 0]     para_data      ,
    input                         para_valid     ,
    input                         para_last      ,
    output                        para_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  para_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  para_cmd_len   ,
    input                         para_cmd_valid ,
    output                        para_cmd_ready ,





    //////////////////////////////////////////////////
    output reg [DATA_WIDTH-1 : 0] m_data      ,
    output reg                    m_valid     ,
    output reg                    m_last      ,
    input                         m_ready     ,   

    input [AXI_ADDR_WIDTH-1 : 0]  m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  m_cmd_len   ,
    input                         m_cmd_valid ,
    output reg                    m_cmd_ready 


);


    always @(*) begin
        if(rst) begin
            m_data = {DATA_WIDTH{1'b0}};
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_data = para_data;
                end
                default:begin
                    m_data = s_data;
                end
            endcase
        end
    end

    always @(*) begin
        if(rst) begin
            m_valid = 1'b0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_valid = para_valid;
                end
                default:begin
                    m_valid = s_valid;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            m_last = 1'b0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_last = para_last;
                end
                default:begin
                    m_last = s_last;
                end
            endcase
        end
    end

    wire start_m = !start_para;

    assign s_ready    = m_ready & start_m;
    assign para_ready = m_ready & start_para;


    ///////////////////////////////////////////////////////////
    assign s_cmd_addr = m_cmd_addr & {AXI_ADDR_WIDTH{start_m}};
    assign s_cmd_len  = m_cmd_len  & {AXI_DATA_WIDTH{start_m}};
    assign s_cmd_valid = m_cmd_valid & start_m;
    
    wire cmd_ready;
    always @(*) begin
        if(rst) begin
            m_cmd_ready = 1'b0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_cmd_ready = cmd_ready;
                end
                default:begin
                    m_cmd_ready = s_cmd_ready;
                end
            endcase
        end
    end

    /////////////////////////////////////////////////////////////
    //状态机
    localparam CMD = 3'b001, CONSTRAST = 3'b010, DATA = 3'b100;
    reg [2 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= CMD;
        end
        else begin
            state <= next_state;
        end
    end


    always @(*) begin
        case(state)
        //要请求读取的地址
            CMD:begin
                if(m_cmd_valid & cmd_ready) begin
                    next_state = CONSTRAST;
                end
                else begin
                    next_state = CMD;
                end
            end
            //对比要输出的地址
            CONSTRAST:begin
                if(para_cmd_valid & para_cmd_ready) begin
                    next_state = DATA;
                end
                else begin
                    next_state = CONSTRAST;
                end
            end
            DATA:begin
                if(para_valid & para_ready & para_last) begin
                    next_state = CMD;
                end
                else begin
                    next_state = DATA;
                end
            end
            default:begin
                next_state = CMD;
            end
        endcase
    end


    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr_reg;
    reg [AXI_DATA_WIDTH-1 : 0] cmd_len_reg ;
    always @(posedge clk) begin
        if((state == CMD) && (next_state == CONSTRAST)) begin
            cmd_addr_reg <= m_cmd_addr;
            cmd_len_reg  <= m_cmd_len ;
        end
    end

    assign cmd_ready = (state == CMD) & start_para;

    assign para_cmd_ready = (cmd_addr_reg == para_cmd_addr) && (cmd_len_reg == para_cmd_len) && (state == CONSTRAST);
    
endmodule