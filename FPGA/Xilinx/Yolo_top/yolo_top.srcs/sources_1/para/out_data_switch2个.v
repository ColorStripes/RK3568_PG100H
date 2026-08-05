module out_data_switch #(
    parameter AXI_DATA_WIDTH = 32,
              AXI_ADDR_WIDTH = 32,
    parameter CHA_PAR_OUT = 16,                          //输入通道并行度
              INT = 8,                                  //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT            //数据传输位宽    并行度 * INT8
)
(
    input clk,
    input rst,


    input  start_para  ,

    input  [DATA_WIDTH-1 : 0]      s_data      ,
    input                          s_valid     ,
    input                          s_last      ,
    output                         s_ready     ,

    input  [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr  ,
    input  [AXI_DATA_WIDTH-1 : 0]  s_cmd_len   ,
    input                          s_cmd_valid ,
    output                         s_cmd_ready ,

    input                          s_calculate_end         ,
    output                         s_calculate_end_receive , 

    input  [DATA_WIDTH-1 : 0]     para_data      ,
    input                         para_valid     ,
    input                         para_last      ,
    output                        para_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  para_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  para_cmd_len   ,
    input                         para_cmd_valid ,
    output                        para_cmd_ready ,

    input                         para_calculate_end         ,
    output                        para_calculate_end_receive , 


    //////////////////////////////////////////////////
    output reg [DATA_WIDTH-1 : 0]      m_data      ,
    output reg                         m_valid     ,
    output reg                         m_last      ,
    input                              m_ready     ,   

    output reg [AXI_ADDR_WIDTH-1 : 0]  m_cmd_addr  ,
    output reg [AXI_DATA_WIDTH-1 : 0]  m_cmd_len   ,
    output reg                         m_cmd_valid ,
    input                              m_cmd_ready ,


    output reg                         m_calculate_end          ,
    input                              m_calculate_end_receive


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


///////////////////////////////////////////////////////////////////////////////
    always @(*) begin
        if(rst) begin
            m_cmd_addr = {AXI_ADDR_WIDTH{1'b0}};
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_cmd_addr = para_cmd_addr;
                end
                default:begin
                    m_cmd_addr = s_cmd_addr;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            m_cmd_len = {AXI_DATA_WIDTH{1'b0}};
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_cmd_len = para_cmd_len;
                end
                default:begin
                    m_cmd_len = s_cmd_len;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            m_cmd_valid = 1'b0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_cmd_valid = para_cmd_valid;
                end
                default:begin
                    m_cmd_valid = s_cmd_valid;
                end
            endcase
        end
    end


    assign s_cmd_ready    = m_cmd_ready & start_m;
    assign para_cmd_ready = m_cmd_ready & start_para;




    always @(*) begin
        if(rst) begin
            m_calculate_end = 1'b0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    m_calculate_end = para_calculate_end;
                end
                default:begin
                    m_calculate_end = s_calculate_end;
                end
            endcase
        end
    end


    // assign s_calculate_end_receive    = m_calculate_end_receive & start_m;
    // assign para_calculate_end_receive = m_calculate_end_receive & start_para;


    assign s_calculate_end_receive    = m_calculate_end_receive ;
    assign para_calculate_end_receive = m_calculate_end_receive & start_para;

    
endmodule