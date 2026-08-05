module out_switch #(
    parameter CHA_PAR_OUT = 16,                                      //输出通道并行度
              INT = 8,                                              //每个数的位宽
              DATA_WIDTH = CHA_PAR_OUT * INT,                       //数据传输位宽    输出并行度 * INT8
              //conv
              CONV_CHA_PAR_OUT = 8,
              CONV_DATA_WIDTH = CONV_CHA_PAR_OUT * INT
)
(
    input          clk              ,
    input          rst              ,

    input  [4 : 0]   start            ,
    

    input  [CONV_DATA_WIDTH-1 : 0]  conv_s_data      ,
    input                           conv_s_valid     ,
    input                           conv_s_last      ,
    output                          conv_s_req       ,


    // input  [DATA_WIDTH-1 : 0]   cat_add_s_data      ,
    // input                       cat_add_s_valid     ,
    // input                       cat_add_s_last      ,
    // output                      cat_add_s_req       ,


    input  [DATA_WIDTH-1 : 0]   sppf_s_data      ,
    input                       sppf_s_valid     ,
    input                       sppf_s_last      ,
    output                      sppf_s_req       ,


    input  [DATA_WIDTH-1 : 0]   upsample_s_data      ,
    input                       upsample_s_valid     ,
    input                       upsample_s_last      ,
    output                      upsample_s_req       ,


    input  [DATA_WIDTH-1 : 0]   focus_s_data      ,
    input                       focus_s_valid     ,
    input                       focus_s_last      ,
    output                      focus_s_req       ,


    output reg [DATA_WIDTH-1 : 0]   s_data   ,
    output reg                      s_valid  ,
    output reg                      s_last   ,
    input                           s_req   

);







///////////////////////////////////////////////////////////////////////////////////////////
    always @(*) begin
        if(rst) begin
            s_data = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_data = {{(DATA_WIDTH - CONV_DATA_WIDTH){1'b0}}, conv_s_data};
                end
                // start[1]:begin
                //     s_data = cat_add_s_data;
                // end
                start[2]:begin
                    s_data = sppf_s_data;
                end
                start[3]:begin
                    s_data = upsample_s_data;
                end
                start[4]:begin
                    s_data = focus_s_data;
                end
                default:begin
                    s_data = 0;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            s_valid = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_valid = conv_s_valid;
                end
                // start[1]:begin
                //     s_valid = cat_add_s_valid;
                // end
                start[2]:begin
                    s_valid = sppf_s_valid;
                end
                start[3]:begin
                    s_valid = upsample_s_valid;
                end
                start[4]:begin
                    s_valid = focus_s_valid;
                end
                default:begin
                    s_valid = 0;
                end
            endcase
        end
    end


    always @(*) begin
        if(rst) begin
            s_last = 0;
        end
        else begin
            case(1'b1)
                start[0]:begin
                    s_last = conv_s_last;
                end
                // start[1]:begin
                //     s_last = cat_add_s_last;
                // end
                start[2]:begin
                    s_last = sppf_s_last;
                end
                start[3]:begin
                    s_last = upsample_s_last;
                end
                start[4]:begin
                    s_last = focus_s_last;
                end
                default:begin
                    s_last = 0;
                end
            endcase
        end
    end


    assign conv_s_req     = s_req & start[0];
    // assign cat_add_s_req  = s_req & start[1];
    assign sppf_s_req     = s_req & start[2];
    assign upsample_s_req = s_req & start[3];
    assign focus_s_req    = s_req & start[4];




endmodule