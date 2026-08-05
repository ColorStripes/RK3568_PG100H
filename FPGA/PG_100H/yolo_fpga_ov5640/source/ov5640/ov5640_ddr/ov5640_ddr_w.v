module ov5640_ddr_w #(
    parameter DATA_WIDTH = 24,
    parameter AXI_DATA_WIDTH = 128,
    parameter CAM_DATA_LEN  = 172800, //1280*720*3/16
    parameter DEVICE = "PG"
)(
    input          axi_clk        ,
    input          axi_rst        ,

    input  [$clog2(CAM_DATA_LEN) : 0]  data_len       /*synthesis PAP_MARK_DEBUG="1"*/, //以16字节为单位

    input  [DATA_WIDTH-1 :0]       s_data       ,
    input                          s_data_valid ,
    input                          s_vsync      ,
    input                          s_hsync      ,       //没用

    output [AXI_DATA_WIDTH-1 : 0]  axi_data       /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         axi_data_valid /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         axi_data_last  /*synthesis PAP_MARK_DEBUG="1"*/, 
    input                          axi_data_ready /*synthesis PAP_MARK_DEBUG="1"*/  
);




    reg             wr_en;
    reg  [31 : 0]   din  ;
    wire            rd_en;
    wire [AXI_DATA_WIDTH-1 : 0] dout ;

    wire                        empty;
    wire                        full /*synthesis PAP_MARK_DEBUG="1"*/;



    reg [1 : 0] cnt;
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            cnt <= 2'd0;
        end
        else if(s_data_valid)begin
            cnt <= cnt + 2'd1;
        end
    end
generate
    if(DATA_WIDTH == 24) begin    
    
        reg [23 : 0]  cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                case (cnt)
                    2'b00:begin
                        cam_data_temp <= s_data;
                    end
                    2'b01:begin
                        cam_data_temp <= {8'd0, s_data[23:8]};
                    end
                    2'b10:begin
                        cam_data_temp <= {16'd0, s_data[23:16]};
                    end
                    2'b11:begin
                        cam_data_temp <= 24'd0;
                    end
                endcase
            end
        end

        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                case (cnt)
                    2'b01:begin
                        din <= {s_data[7:0], cam_data_temp[23:0]};
                    end
                    2'b10:begin
                        din <= {s_data[15:0], cam_data_temp[15:0]};
                    end
                    2'b11:begin
                        din <= {s_data, cam_data_temp[7:0]};
                    end
                endcase
            end
        end

        always @(posedge axi_clk) begin
            if(axi_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & (cnt != 2'b00))begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
    else if(DATA_WIDTH == 16) begin

        reg [15 : 0] cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid) begin
                cam_data_temp <= s_data;
            end
        end


        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                if(cnt[0]) begin
                    din <= {s_data, cam_data_temp};
                end
            end
        end

        always @(posedge axi_clk) begin
            if(axi_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & cnt[0])begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
    else if(DATA_WIDTH == 8) begin

        reg [23 : 0] cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid) begin
                cam_data_temp <= {s_data, cam_data_temp[23:8]};
            end
        end

        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                if(&cnt) begin
                    din <= {s_data, cam_data_temp};
                end
            end
        end


        always @(posedge axi_clk) begin
            if(axi_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & &cnt)begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
endgenerate






        reg [$clog2(CAM_DATA_LEN) : 0] axi_num/*synthesis PAP_MARK_DEBUG="1"*/;
        reg [$clog2(CAM_DATA_LEN) : 0] axi_cnt/*synthesis PAP_MARK_DEBUG="1"*/;

        always @(posedge axi_clk) begin
            if(axi_rst)begin
                axi_num <= 20'd0;
            end
            else begin
                axi_num <= data_len - 20'd1;
            end
        end

        always @(posedge axi_clk) begin
            if(axi_rst)begin
                axi_cnt <= 20'd0;
            end
            else if(s_vsync)begin
                axi_cnt <= 20'd0;
            end
            else if(axi_data_valid & axi_data_ready)begin
                if(axi_data_last)begin
                    axi_cnt <= 20'd0;
                end
                else begin
                    axi_cnt <= axi_cnt + 20'd1;
                end
            end
        end

    // reg test1/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge axi_clk) begin
    //     if(axi_rst) begin
    //         test1 <= 1'b0;
    //     end
    //     else if(s_vsync && (axi_cnt != 0)) begin
    //         test1 <= 1'b1;
    //     end
    // end


    assign rd_en = axi_data_valid & axi_data_ready;
    assign axi_data_last = (axi_cnt == axi_num);
    assign axi_data = dout;
    assign axi_data_valid = !empty;




        wire [AXI_DATA_WIDTH-1 : 0] dout_drm;
        wire                        empty_drm/*synthesis PAP_MARK_DEBUG="1"*/;  
        wire                        almost_full;   
        wire rd_en_drm = !(almost_full | empty_drm);
        ov5640_ddr_fifo_DRM ov5640_ddr_fifo_DRM (
          .clk(axi_clk),                      // input
          .rst(axi_rst),                      // input
          .wr_en(wr_en),                  // input
          .wr_data(din),              // input [31:0]
          .wr_full(full),              // output
          
          .rd_en(rd_en_drm),                  // input
          .rd_data(dout_drm),              // output [127:0]
          .rd_empty(empty_drm),            // output

          .almost_full(),      // output
          .almost_empty()     // output
        );


        // reg rd_en_drm_d;
        // always @(posedge axi_clk) begin
        //     if(axi_rst) begin
        //         rd_en_drm_d <= 1'b0;
        //     end
        //     else begin
        //         rd_en_drm_d <= rd_en_drm;  
        //     end
        // end

        reg wr_en_drm;
        always @(posedge axi_clk) begin
            wr_en_drm <= rd_en_drm;
        end

        ov5640_ddr_fifo ov5640_ddr_fifo (
          .clk(axi_clk),                      // input
          .rst(axi_rst),                      // input
          .wr_en  (wr_en_drm),                  // input
          .wr_data(dout_drm ),              // input [127:0]
          .full(),              // output
          

          .rd_en(rd_en),                  // input
          .rd_data(dout),              // output [127:0]
          .empty(empty),            // output

          .almost_full(almost_full),      // output
          .almost_empty()     // output
        );





    
endmodule