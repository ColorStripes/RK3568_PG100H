module out_switch #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_OUT = 16,                                      //输出通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT                        //数据传输位宽    输出并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input  [1 : 0]   start            ,

    input  [DATA_WIDTH-1 : 0]     out_s_data      ,
    input                         out_s_valid     ,
    input                         out_s_last      ,
    output reg                    out_s_ready     ,


    input [AXI_ADDR_WIDTH-1 : 0]  out_s_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  out_s_cmd_len   ,
    input                         out_s_cmd_valid ,
    output reg                    out_s_cmd_ready ,

/////////////////////////////////////////////////////////////

    output [DATA_WIDTH-1 : 0]      out_m_data       ,
    output                         out_m_last       ,
    output                         out_m_valid      ,
    input                          out_m_ready      , 

    output [AXI_ADDR_WIDTH-1 : 0]  out_cmd_addr     ,
    output [AXI_DATA_WIDTH-1 : 0]  out_cmd_len      ,
    output                         out_cmd_valid    ,
    input                          out_cmd_ready    ,


    output [DATA_WIDTH-1 : 0]      para_m_data       ,
    output                         para_m_last       ,
    output                         para_m_valid      ,
    input                          para_m_ready      ,


    input [AXI_ADDR_WIDTH-1 : 0]  para_cmd_addr     ,
    input [AXI_DATA_WIDTH-1 : 0]  para_cmd_len      ,
    input                         para_cmd_valid    ,
    output                        para_cmd_ready    


);


    assign out_m_data  = out_s_data  & {DATA_WIDTH{start[0]}};
    assign out_m_last  = out_s_last  & start[0];
    assign out_m_valid = out_s_valid & start[0];

    assign para_m_data  = out_s_data  & {DATA_WIDTH{start[1]}};
    assign para_m_last  = out_s_last  & start[1];
    assign para_m_valid = out_s_valid & start[1];

    always @(*) begin
        if(rst) begin
            out_s_ready = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    out_s_ready = out_m_ready;
                end
                start[1]:begin
                    out_s_ready = para_m_ready;
                end
                default:begin
                    out_s_ready = 0;
                end
            endcase
        end
    end



/////////////////////////////////////////////////////////////
    //状态机
    localparam CMD_PAR = 3'b001, CONSTRAST = 3'b010, DATA = 3'b100;
    reg [2 : 0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= CMD_PAR;
        end
        else begin
            state <= next_state;
        end
    end


    always @(*) begin
        case(state)
            CMD_PAR:begin
                if(para_cmd_valid & para_cmd_ready) begin
                    next_state = CONSTRAST;
                end
                else begin
                    next_state = CMD_PAR;
                end
            end
            CONSTRAST:begin
                if(out_s_cmd_valid & cmd_ready) begin
                    next_state = DATA;
                end
                else begin
                    next_state = CONSTRAST;
                end
            end
            DATA:begin
                if(para_m_valid & para_m_ready & para_m_last) begin
                    next_state = CMD_PAR;
                end
                else begin
                    next_state = DATA;
                end
            end
            default:begin
                next_state = CMD_PAR;
            end
        endcase
    end

    assign para_cmd_ready = (state == CMD_PAR);

    reg [AXI_ADDR_WIDTH-1 : 0]  cmd_addr_reg  ;
    reg [AXI_DATA_WIDTH-1 : 0]  cmd_len_reg   ;
    always @(posedge clk) begin
        if(next_state == CONSTRAST) begin
            cmd_addr_reg <= para_cmd_addr;
            cmd_len_reg  <= para_cmd_len;
        end
    end

    wire cmd_ready = (cmd_addr_reg == out_s_cmd_addr) && (cmd_len_reg == out_s_cmd_len);




/////////////////////////////////////////////////////////////////////////////////////////


    assign out_cmd_addr  = out_s_cmd_addr  & {AXI_ADDR_WIDTH{start[0]}};
    assign out_cmd_len   = out_s_cmd_len   & {AXI_DATA_WIDTH{start[0]}};
    assign out_cmd_valid = out_s_cmd_valid & start[0];

    
    always @(*) begin
        if(rst) begin
            out_s_cmd_ready = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    out_s_cmd_ready = out_cmd_ready;
                end
                start[1]:begin
                    out_s_cmd_ready = cmd_ready;
                end
                default:begin
                    out_s_cmd_ready = 0;
                end
            endcase
        end
    end

endmodule