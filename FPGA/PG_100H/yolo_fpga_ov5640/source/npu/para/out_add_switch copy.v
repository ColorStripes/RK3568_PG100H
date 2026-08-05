module out_add_switch #(
    parameter AXI_DATA_WIDTH    = 32,
              AXI_ADDR_WIDTH    = 32,
    parameter CHA_PAR_OUT = 16,                                      //输入通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT                        //数据传输位宽    输入并行度 * INT8
)
(
    input          clk              ,
    input          rst              ,

    input   start_para ,


    input   [DATA_WIDTH-1 : 0]   s_data   ,
    input                        s_valid  ,
    input                        s_last   ,
    output  reg                  s_ready  , 

    //命令接口
    input  [AXI_ADDR_WIDTH-1 : 0]  s_cmd_addr  ,
    input  [AXI_DATA_WIDTH-1 : 0]  s_cmd_len   ,
    input                          s_cmd_valid ,
    output reg                     s_cmd_ready ,



///////////////////////////////////////////
    output     [DATA_WIDTH-1 : 0]   add_m_data      ,
    output                          add_m_valid     ,
    output                          add_m_last      ,
    input                           add_m_ready     ,

    output  [AXI_ADDR_WIDTH-1 : 0]  add_m_cmd_addr  ,
    output  [AXI_DATA_WIDTH-1 : 0]  add_m_cmd_len   ,
    output                          add_m_cmd_valid ,
    input                           add_m_cmd_ready ,


    output  [DATA_WIDTH-1 : 0]     m_data      ,
    output                         m_valid     ,
    output                         m_last      ,
    input                          m_ready     ,

    output [AXI_ADDR_WIDTH-1 : 0]  m_cmd_addr  ,
    output [AXI_DATA_WIDTH-1 : 0]  m_cmd_len   ,
    output                         m_cmd_valid ,
    input                          m_cmd_ready 


);


    wire  [DATA_WIDTH-1 : 0]     out_add_data      ;
    wire                         out_add_valid     ;
    wire                         out_add_last      ;
    wire                         out_add_ready     ;




    wire  [DATA_WIDTH-1 : 0]     out_m_data      ;
    wire                         out_m_valid     ;
    wire                         out_m_last      ;
    wire                         out_m_ready     ;





    wire start_m = !start_para;




///////////////////////////

    assign out_add_data  = s_data & {DATA_WIDTH{start_para}};
    assign out_m_data      = s_data & {DATA_WIDTH{start_m}};


    assign out_add_valid  = s_valid & start_para;
    assign out_m_valid      = s_valid & start_m;


    assign out_add_last  = s_last & start_para;
    assign out_m_last      = s_last & start_m;

    
    
    always @(*) begin
        if(rst) begin
            s_ready = 0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    s_ready = out_add_ready;
                end
                default:begin
                    s_ready = out_m_ready;
                end
            endcase
        end
    end


    assign add_m_cmd_addr = s_cmd_addr & {AXI_ADDR_WIDTH{start_para}};
    assign m_cmd_addr     = s_cmd_addr & {AXI_ADDR_WIDTH{start_m}};

    assign add_m_cmd_len = s_cmd_len & {AXI_DATA_WIDTH{start_para}};
    assign m_cmd_len     = s_cmd_len & {AXI_DATA_WIDTH{start_m}};

    assign add_m_cmd_valid = s_cmd_valid & {start_para};
    assign m_cmd_valid     = s_cmd_valid & {start_m};


    always @(*) begin
        if(rst) begin
            s_cmd_ready = 0;
        end
        else begin
            case(1'b1)
                start_para:begin
                    s_cmd_ready = add_m_cmd_ready;
                end
                default:begin
                    s_cmd_ready = m_cmd_ready;
                end
            endcase
        end
    end



    pipe #(
        .WIDTH(DATA_WIDTH+1)
    )
    pipe_out_add(
        .clk(clk),
        .rst(rst),

        .up_valid(out_add_valid),
        .up_ready(out_add_ready),
        .data_in ({out_add_last, out_add_data}),


        .down_valid(add_m_valid),
        .down_ready(add_m_ready),
        .data_out  ({add_m_last, add_m_data})
    );




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