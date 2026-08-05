module in_switch_main1 #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_IN = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input         clk              ,
    input         rst              ,

    input  [2 : 0]     start ,

    //1
    input   [DATA_WIDTH-1 : 0]   s_data_1   ,
    input                        s_valid_1  ,
    input                        s_last_1   ,
    output  reg                  s_ready_1  , 

    //命令接口
    output reg [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_1  ,
    output reg [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_1   ,
    output reg                         s_cmd_valid_1 ,
    input                              s_cmd_ready_1 ,


///////////////////////////////////////////
    output  [DATA_WIDTH-1 : 0]   conv_weight_data      ,
    output                       conv_weight_valid     ,
    output                       conv_weight_last      ,
    input                        conv_weight_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_weight_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_weight_cmd_len   ,
    input                         conv_weight_cmd_valid ,
    output                        conv_weight_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]   focus_m_data      ,
    output                       focus_m_valid     ,
    output                       focus_m_last      ,
    input                        focus_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  focus_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  focus_m_cmd_len   ,
    input                         focus_m_cmd_valid ,
    output                        focus_m_cmd_ready 


);

/////////////CMD//////////
    always @(*) begin
        if(rst) begin
            s_cmd_addr_1 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_addr_1 = conv_weight_cmd_addr;
                end
                start[2]:begin
                    s_cmd_addr_1 = focus_m_cmd_addr;
                end
                default:begin
                    s_cmd_addr_1 = 0;
                end
            endcase
        end
    end

    always @(*) begin
        if(rst) begin
            s_cmd_len_1 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_len_1 = conv_weight_cmd_len;
                end
                start[2]:begin
                    s_cmd_len_1 = focus_m_cmd_len;
                end
                default:begin
                    s_cmd_len_1 = 0;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            s_cmd_valid_1 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_valid_1 = conv_weight_cmd_valid;
                end
                start[2]:begin
                    s_cmd_valid_1 = focus_m_cmd_valid;
                end
                default:begin
                    s_cmd_valid_1 = 0;
                end
            endcase
        end
    end

    assign conv_weight_cmd_ready  = s_cmd_ready_1 & start[0];
    assign focus_m_cmd_ready      = s_cmd_ready_1 & start[2];

///////////////////////////
    assign conv_weight_data  = s_data_1  & {DATA_WIDTH{start[0]}};
    assign conv_weight_valid = s_valid_1 & start[0];
    assign conv_weight_last  = s_last_1  & start[0];

    assign focus_m_data  = s_data_1 & {DATA_WIDTH{start[2]}};
    assign focus_m_valid = s_valid_1 & start[2];
    assign focus_m_last  = s_last_1 & start[2];


    always @(*) begin
        if(rst) begin
            s_ready_1 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_ready_1 = conv_weight_ready;
                end
                start[2]:begin
                    s_ready_1 = focus_m_ready;
                end
                default:begin
                    s_ready_1 = 0;
                end
            endcase
        end
    end


endmodule