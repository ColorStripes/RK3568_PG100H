// Created by IP Generator (Version 2022.2-SP6.4 build 146967)
// Instantiation Template
//
// Insert the following codes into your Verilog file.
//   * Change the_instance_name to your own instance name.
//   * Change the signal names in the port associations


ddr_fifo16_w the_instance_name (
  .wr_data(wr_data),                  // input [143:0]
  .wr_en(wr_en),                      // input
  .full(full),                        // output
  .almost_full(almost_full),          // output
  .wr_water_level(wr_water_level),    // output [4:0]
  .rd_data(rd_data),                  // output [143:0]
  .rd_en(rd_en),                      // input
  .empty(empty),                      // output
  .almost_empty(almost_empty),        // output
  .clk(clk),                          // input
  .rst(rst)                           // input
);
