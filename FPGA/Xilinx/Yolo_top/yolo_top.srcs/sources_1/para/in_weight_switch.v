module in_weight_switch #(
    parameter START_NUM = 2,
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_IN = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input  [START_NUM-1 : 0]        start ,


    input   [DATA_WIDTH-1 : 0]   s_data_2   ,
    input                        s_valid_2  ,
    input                        s_last_2   ,
    output  reg                  s_ready_2  , 

    //命令接口
    output reg [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_2  ,
    output reg [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_2   ,
    output reg                         s_cmd_valid_2 ,
    input                              s_cmd_ready_2 ,



///////////////////////////////////////////
    output  [DATA_WIDTH-1 : 0]    conv_weight1_data      ,
    output                        conv_weight1_valid     ,
    output                        conv_weight1_last      ,
    input                         conv_weight1_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_weight1_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_weight1_cmd_len   ,
    input                         conv_weight1_cmd_valid ,
    output                        conv_weight1_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]    conv_weight2_data      ,
    output                        conv_weight2_valid     ,
    output                        conv_weight2_last      ,
    input                         conv_weight2_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_weight2_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_weight2_cmd_len   ,
    input                         conv_weight2_cmd_valid ,
    output                        conv_weight2_cmd_ready 


);

/////////////CMD//////////

    always @(*) begin
        if(rst) begin
            s_cmd_addr_2 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_addr_2 = conv_weight1_cmd_addr;
                end
                start[1]:begin
                    s_cmd_addr_2 = conv_weight2_cmd_addr;
                end
                default:begin
                    s_cmd_addr_2 = 0;
                end
            endcase
        end
    end

    always @(*) begin
        if(rst) begin
            s_cmd_len_2 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_len_2 = conv_weight1_cmd_len;
                end
                start[1]:begin
                    s_cmd_len_2 = conv_weight2_cmd_len;
                end
                default:begin
                    s_cmd_len_2 = 0;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            s_cmd_valid_2 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_valid_2 = conv_weight1_cmd_valid;
                end
                start[1]:begin
                    s_cmd_valid_2 = conv_weight2_cmd_valid;
                end
                default:begin
                    s_cmd_valid_2 = 0;
                end
            endcase
        end
    end

    assign conv_weight1_cmd_ready  = s_cmd_ready_2 & start[0];
    assign conv_weight2_cmd_ready  = s_cmd_ready_2 & start[1];


///////////////////////////

    assign conv_weight1_data = s_data_2 & {DATA_WIDTH{start[0]}};
    assign conv_weight2_data = s_data_2 & {DATA_WIDTH{start[1]}};

    assign conv_weight1_valid = s_valid_2 & start[0];
    assign conv_weight2_valid = s_valid_2 & start[1];

    assign conv_weight1_last  = s_last_2 & start[0];
    assign conv_weight2_last  = s_last_2 & start[1];

    always @(*) begin
        if(rst) begin
            s_ready_2 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_ready_2 = conv_weight1_ready;
                end
                start[1]:begin
                    s_ready_2 = conv_weight2_ready;
                end
                default:begin
                    s_ready_2 = 0;
                end
            endcase
        end
    end


endmodule