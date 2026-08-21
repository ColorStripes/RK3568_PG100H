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


    input [1 : 0] start_para  ,

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

    input  [DATA_WIDTH-1 : 0]     para1_data      ,
    input                         para1_valid     ,
    input                         para1_last      ,
    output                        para1_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  para1_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  para1_cmd_len   ,
    input                         para1_cmd_valid ,
    output                        para1_cmd_ready ,

    input                         para1_calculate_end         ,
    output                        para1_calculate_end_receive , 


    input  [DATA_WIDTH-1 : 0]     para2_data      ,
    input                         para2_valid     ,
    input                         para2_last      ,
    output                        para2_ready     ,

    input [AXI_ADDR_WIDTH-1 : 0]  para2_cmd_addr  ,
    input [AXI_DATA_WIDTH-1 : 0]  para2_cmd_len   ,
    input                         para2_cmd_valid ,
    output                        para2_cmd_ready ,

    input                         para2_calculate_end         ,
    output                        para2_calculate_end_receive , 


    //////////////////////////////////////////////////
    output  [DATA_WIDTH-1 : 0]      m_data      ,
    output                          m_valid     ,
    output                          m_last      ,
    input                           m_ready     ,   

    output reg [AXI_ADDR_WIDTH-1 : 0]  m_cmd_addr  ,
    output reg [AXI_DATA_WIDTH-1 : 0]  m_cmd_len   ,
    output reg                         m_cmd_valid ,
    input                              m_cmd_ready ,


    output reg                         m_calculate_end          ,
    input                              m_calculate_end_receive


);

reg [DATA_WIDTH-1 : 0]      out_m_data     ;
reg                         out_m_valid    ;
reg                         out_m_last     ;
wire                        out_m_ready    ;

// wire [AXI_ADDR_WIDTH-1 : 0]  out_cmd_addr   ;
// wire [AXI_DATA_WIDTH-1 : 0]  out_cmd_len    ;
// wire                         out_cmd_valid  ;
// wire                         out_cmd_ready  ;

//////////////////////

    always @(*) begin
        if(rst) begin
            out_m_data = {DATA_WIDTH{1'b0}};
        end
        else begin
            case(1'b1)
                start_para[0]:begin
                    out_m_data = para1_data;
                end
                start_para[1]:begin
                    out_m_data = para2_data;
                end
                default:begin
                    out_m_data = s_data;
                end
            endcase
        end
    end

    always @(*) begin
        if(rst) begin
            out_m_valid = 1'b0;
        end
        else begin
            case(1'b1)
                start_para[0]:begin
                    out_m_valid = para1_valid;
                end
                start_para[1]:begin
                    out_m_valid = para2_valid;
                end
                default:begin
                    out_m_valid = s_valid;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            out_m_last = 1'b0;
        end
        else begin
            case(1'b1)
                start_para[0]:begin
                    out_m_last = para1_last;
                end
                start_para[1]:begin
                    out_m_last = para2_last;
                end
                default:begin
                    out_m_last = s_last;
                end
            endcase
        end
    end

    wire start_m = !(|start_para);

    assign s_ready    = out_m_ready & start_m;
    assign para1_ready = out_m_ready & start_para[0];
    assign para2_ready = out_m_ready & start_para[1];


///////////////////////////////////////////////////////////////////////////////
    always @(*) begin
        if(rst) begin
            m_cmd_addr = {AXI_ADDR_WIDTH{1'b0}};
        end
        else begin
            case(1'b1)
                start_para[0]:begin
                    m_cmd_addr = para1_cmd_addr;
                end
                start_para[1]:begin
                    m_cmd_addr = para2_cmd_addr;
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
                start_para[0]:begin
                    m_cmd_len = para1_cmd_len;
                end
                start_para[1]:begin
                    m_cmd_len = para2_cmd_len;
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
                start_para[0]:begin
                    m_cmd_valid = para1_cmd_valid;
                end
                start_para[1]:begin
                    m_cmd_valid = para2_cmd_valid;
                end
                default:begin
                    m_cmd_valid = s_cmd_valid;
                end
            endcase
        end
    end


    assign s_cmd_ready    = m_cmd_ready & start_m;
    assign para1_cmd_ready = m_cmd_ready & start_para[0];
    assign para2_cmd_ready = m_cmd_ready & start_para[1];




    always @(*) begin
        if(rst) begin
            m_calculate_end = 1'b0;
        end
        else begin
            case(1'b1)
                start_para[0]:begin
                    m_calculate_end = para1_calculate_end;
                end
                start_para[1]:begin
                    m_calculate_end = para2_calculate_end;
                end
                default:begin
                    m_calculate_end = s_calculate_end;
                end
            endcase
        end
    end



    assign s_calculate_end_receive     = m_calculate_end_receive ;
    assign para1_calculate_end_receive = m_calculate_end_receive & start_para[0];
    assign para2_calculate_end_receive = start_para[1] ? m_calculate_end_receive : 1'b1;

    
    pipe #(
        .WIDTH(DATA_WIDTH+1)
    )
    pipe_out(
        .clk(clk),
        .rst(rst),

        .up_valid(out_m_valid),
        .up_ready(out_m_ready),
        .data_in ({out_m_last, out_m_data}),


        .down_valid(m_valid),
        .down_ready(m_ready),
        .data_out  ({m_last, m_data})
    );




endmodule