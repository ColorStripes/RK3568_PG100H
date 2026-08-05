module in_conv_switch #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_IN = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_IN * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input  start_para ,


    input   [DATA_WIDTH-1 : 0]   s_data_0   ,
    input                        s_valid_0  ,
    input                        s_last_0   ,
    output  reg                  s_ready_0  , 

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


    output  [DATA_WIDTH-1 : 0]    m_data      ,
    output                        m_valid     ,
    output                        m_last      ,
    input                         m_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  m_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  m_cmd_len   ,
    input                         m_cmd_valid ,
    output                        m_cmd_ready 


);

    wire start_m = !start_para;

/////////////CMD//////////

    always @(*) begin
        if(rst) begin
            s_cmd_addr_0 = 0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    s_cmd_addr_0 = conv_m_cmd_addr;
                end
                default:begin
                    s_cmd_addr_0 = m_cmd_addr;
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
                start_para:begin
                    s_cmd_len_0 = conv_m_cmd_len;
                end
                default:begin
                    s_cmd_len_0 = m_cmd_len;
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
                start_para:begin
                    s_cmd_valid_0 = conv_m_cmd_valid;
                end
                default:begin
                    s_cmd_valid_0 = m_cmd_valid;
                end
            endcase
        end
    end

    assign conv_m_cmd_ready  = s_cmd_ready_0 & start_para;
    assign m_cmd_ready       = s_cmd_ready_0 & start_m;
 


///////////////////////////

    assign conv_m_data  = s_data_0 & {DATA_WIDTH{start_para}};
    assign m_data       = s_data_0 & {DATA_WIDTH{start_m}};


    assign conv_m_valid  = s_valid_0 & start_para;
    assign m_valid       = s_valid_0 & start_m;


    assign conv_m_last  = s_last_0 & start_para;
    assign m_last       = s_last_0 & start_m;

    
    
    always @(*) begin
        if(rst) begin
            s_ready_0 = 0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    s_ready_0 = conv_m_ready;
                end
                default:begin
                    s_ready_0 = m_ready;
                end
            endcase
        end
    end


endmodule