module in_switch_main0 #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_IN = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input  [3 : 0]    start ,


    input  [DATA_WIDTH-1 : 0]   s_data_0   ,
    input                       s_valid_0  ,
    input                       s_last_0   ,
    output  reg                 s_ready_0  , 

    //命令接口
    output reg [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr_0  ,
    output reg [AXI_DATA_WIDTH-1 : 0]  s_cmd_len_0   ,
    output reg                         s_cmd_valid_0 ,
    input                              s_cmd_ready_0 ,



///////////////////////////////////////////
    output  [DATA_WIDTH-1 : 0]    conv_m_data      ,
    output                        conv_m_valid     ,
    output                        conv_m_last      ,
    input                         conv_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  conv_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  conv_m_cmd_len   ,
    input                         conv_m_cmd_valid ,
    output                        conv_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]    sppf_m_data      ,
    output                        sppf_m_valid     ,
    output                        sppf_m_last      ,
    input                         sppf_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  sppf_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  sppf_m_cmd_len   ,
    input                         sppf_m_cmd_valid ,
    output                        sppf_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]    upsample_m_data      ,
    output                        upsample_m_valid     ,
    output                        upsample_m_last      ,
    input                         upsample_m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  upsample_m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  upsample_m_cmd_len   ,
    input                         upsample_m_cmd_valid ,
    output                        upsample_m_cmd_ready 


);

/////////////CMD//////////

    always @(*) begin
        if(rst) begin
            s_cmd_addr_0 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_addr_0 = conv_m_cmd_addr;
                end
                start[2]:begin
                    s_cmd_addr_0 = sppf_m_cmd_addr;
                end
                start[3]:begin
                    s_cmd_addr_0 = upsample_m_cmd_addr;
                end
                default:begin
                    s_cmd_addr_0 = 0;
                end
            endcase
        end
    end

    always @(*) begin
        if(rst) begin
            s_cmd_len_0 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_len_0 = conv_m_cmd_len;
                end
                start[2]:begin
                    s_cmd_len_0 = sppf_m_cmd_len;
                end
                start[3]:begin
                    s_cmd_len_0 = upsample_m_cmd_len;
                end
                default:begin
                    s_cmd_len_0 = 0;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            s_cmd_valid_0 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_cmd_valid_0 = conv_m_cmd_valid;
                end
                start[2]:begin
                    s_cmd_valid_0 = sppf_m_cmd_valid;
                end
                start[3]:begin
                    s_cmd_valid_0 = upsample_m_cmd_valid;
                end
                default:begin
                    s_cmd_valid_0 = 0;
                end
            endcase
        end
    end

    assign conv_m_cmd_ready       = s_cmd_ready_0 & start[0];
    assign sppf_m_cmd_ready       = s_cmd_ready_0 & start[2];
    assign upsample_m_cmd_ready   = s_cmd_ready_0 & start[3];


///////////////////////////

    assign conv_m_data      = s_data_0 & {DATA_WIDTH{start[0]}};
    assign sppf_m_data      = s_data_0 & {DATA_WIDTH{start[2]}};
    assign upsample_m_data  = s_data_0 & {DATA_WIDTH{start[3]}};

    assign conv_m_valid      = s_valid_0 & start[0];
    assign sppf_m_valid      = s_valid_0 & start[2];
    assign upsample_m_valid  = s_valid_0 & start[3];

    assign conv_m_last       = s_last_0 & start[0];
    assign sppf_m_last       = s_last_0 & start[2];
    assign upsample_m_last   = s_last_0 & start[3];
    
    
    

    always @(*) begin
        if(rst) begin
            s_ready_0 = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_ready_0 = conv_m_ready;
                end
                start[2]:begin
                    s_ready_0 = sppf_m_ready;
                end
                start[3]:begin
                    s_ready_0 = upsample_m_ready;
                end
                default:begin
                    s_ready_0 = 0;
                end
            endcase
        end
    end


endmodule