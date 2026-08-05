//øÁ ±÷””Ú
module ov5640_cdc #(
    parameter DATA_WIDTH = 24,
    parameter DEVICE = "PG"
)
(
    input         cam_clk    /*synthesis PAP_MARK_DEBUG="1"*/,          //???????
    input         cam_rst    /*synthesis PAP_MARK_DEBUG="1"*/,

    input [DATA_WIDTH-1 : 0]   s_data     /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_valid    /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_hsync    /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_vsync    /*synthesis PAP_MARK_DEBUG="1"*/,

    input                      video_clk  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      video_rst  /*synthesis PAP_MARK_DEBUG="1"*/,
    output [DATA_WIDTH-1 : 0]  video_data /*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_valid/*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_hsync/*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_vsync/*synthesis PAP_MARK_DEBUG="1"*/
);








    // reg s_vsync_d, s_hsync_d;
    // always @(posedge cam_clk) begin
    //     s_vsync_d <= s_vsync;
    //     s_hsync_d <= s_hsync;
    // end
    // wire vsync_rise = s_vsync & ~s_vsync_d;
    // wire hsync_rise = s_hsync & ~s_hsync_d;





    // reg [31 : 0] cnt_cdc_in/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         cnt_cdc_in <= 32'd0;
    //     end
    //     else if(vsync_rise)begin
    //         cnt_cdc_in <= 32'd0;
    //     end
    //     else if(s_valid)begin
    //         cnt_cdc_in <= cnt_cdc_in + 32'd1;
    //     end
    // end


    // reg [31 : 0] cnt_cdc_in_h/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         cnt_cdc_in_h <= 32'd0;
    //     end
    //     else if(hsync_rise)begin
    //         cnt_cdc_in_h <= 32'd0;
    //     end
    //     else if(s_valid)begin
    //         cnt_cdc_in_h <= cnt_cdc_in_h + 32'd1;
    //     end
    // end

    // reg not_1920/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         not_1920 <= 1'b0;
    //     end        
    //     else if(vsync_rise) begin
    //         not_1920 <= 1'b0;
    //     end
    //     else if(cnt_cdc_in_h != 32'd1920 && hsync_rise && cnt_cdc_in_h != 32'd0)begin
    //         not_1920 <= 1'b1;
    //     end
    // end



    wire rd_en_vhsync, empty_vhsync;
    assign rd_en_vhsync  = !empty_vhsync;

    wire [1 : 0] vhsync_in = {s_vsync, s_hsync};
    wire [1 : 0] vhsync_out;
    wire wr_en_vhsync;
    assign wr_en_vhsync = (|vhsync_in) | s_valid;
    ov5640_vhsync ov5640_vhsync (
      
      .wr_clk(cam_clk),                // input
      .wr_rst(cam_rst),                // input
      .wr_en(wr_en_vhsync),             // input
      .wr_data(vhsync_in),              // input [1:0]
      .full(),                    // output
      .almost_full(),      // output


      .rd_clk(video_clk),                // input
      .rd_rst(video_rst),                // input
      .rd_en(rd_en_vhsync),                  // input
      .rd_data(vhsync_out),              // output [1:0]
      .empty(empty_vhsync),                  // output
      .almost_empty()     // output

    );

    // reg vsync_d, hsync_d;
    // always @(posedge video_clk) begin
    //     hsync_d <= vhsync_out[0];
    //     vsync_d <= vhsync_out[1];
    // end

    // reg vsync_dd, hsync_dd;
    // always @(posedge video_clk) begin
    //     hsync_dd <= hsync_d;
    //     vsync_dd <= vsync_d;
    // end

    assign video_hsync = vhsync_out[0];
    assign video_vsync = vhsync_out[1];

















    wire empty;
    wire full ;
    wire rd_rst_busy;
    wire wr_rst_busy;
    wire data_valid ;
    wire wr_en;
    wire rd_en;

    wire [DATA_WIDTH-1 : 0] dout;


    wire [DATA_WIDTH-1 : 0] din = s_data;
    assign wr_en = !full & s_valid;

    assign rd_en       = !empty;
    assign video_data  = dout[DATA_WIDTH-1 : 0];




    reg video_valid_r;
    always @(posedge video_clk) begin
        video_valid_r <= rd_en;
    end
    assign video_valid = video_valid_r;
    ov5640_cdc_fifo ov5640_cdc_fifo (
      .wr_clk(cam_clk),                // input
      .wr_rst(cam_rst),                // input
      .wr_en(wr_en),                  // input
      .wr_data(din),              // input [24:0]
      .wr_full(full),              // output
    
      .rd_clk(video_clk),                // input
      .rd_en(rd_en),                  // input
      .rd_data(dout),              // output [24:0]
      .rd_empty(empty),            // output
      .rd_rst(video_rst),                // input
      .almost_full(),      // output
      .almost_empty()     // output
    );





    // wire video_vsync_rise = vsync_d & ~vsync_dd;
    // wire video_hsync_rise = hsync_d & ~hsync_dd;


    // reg [31 : 0] cnt_cdc_out/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge video_clk) begin   
    //     if(video_rst)begin
    //         cnt_cdc_out <= 32'd0;
    //     end
    //     else if(video_vsync_rise)begin
    //         cnt_cdc_out <= 32'd0;
    //     end
    //     else if(video_valid)begin
    //         cnt_cdc_out <= cnt_cdc_out + 32'd1;
    //     end
    // end


    // reg [31 : 0] cnt_cdc_out_h/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge video_clk) begin
    //     if(video_rst)begin
    //         cnt_cdc_out_h <= 32'd0;
    //     end
    //     else if(video_hsync_rise)begin
    //         cnt_cdc_out_h <= 32'd0;
    //     end
    //     else if(video_valid)begin
    //         cnt_cdc_out_h <= cnt_cdc_out_h + 32'd1;
    //     end
    // end


endmodule