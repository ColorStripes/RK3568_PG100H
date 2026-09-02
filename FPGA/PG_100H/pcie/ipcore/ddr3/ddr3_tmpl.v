// Created by IP Generator (Version 2022.2-SP6.4 build 146967)
// Instantiation Template
//
// Insert the following codes into your Verilog file.
//   * Change the_instance_name to your own instance name.
//   * Change the signal names in the port associations


ddr3 the_instance_name (
  .resetn(resetn),                                      // input
  .core_clk(core_clk),                                  // output
  .pll_lock(pll_lock),                                  // output
  .phy_pll_lock(phy_pll_lock),                          // output
  .gpll_lock(gpll_lock),                                // output
  .rst_gpll_lock(rst_gpll_lock),                        // output
  .ddrphy_cpd_lock(ddrphy_cpd_lock),                    // output
  .ddr_init_done(ddr_init_done),                        // output
  .axi_awaddr(axi_awaddr),                              // input [27:0]
  .axi_awuser_ap(axi_awuser_ap),                        // input
  .axi_awuser_id(axi_awuser_id),                        // input [3:0]
  .axi_awlen(axi_awlen),                                // input [3:0]
  .axi_awready(axi_awready),                            // output
  .axi_awvalid(axi_awvalid),                            // input
  .axi_wdata(axi_wdata),                                // input [127:0]
  .axi_wstrb(axi_wstrb),                                // input [15:0]
  .axi_wready(axi_wready),                              // output
  .axi_wusero_id(axi_wusero_id),                        // output [3:0]
  .axi_wusero_last(axi_wusero_last),                    // output
  .axi_araddr(axi_araddr),                              // input [27:0]
  .axi_aruser_ap(axi_aruser_ap),                        // input
  .axi_aruser_id(axi_aruser_id),                        // input [3:0]
  .axi_arlen(axi_arlen),                                // input [3:0]
  .axi_arready(axi_arready),                            // output
  .axi_arvalid(axi_arvalid),                            // input
  .axi_rdata(axi_rdata),                                // output [127:0]
  .axi_rid(axi_rid),                                    // output [3:0]
  .axi_rlast(axi_rlast),                                // output
  .axi_rvalid(axi_rvalid),                              // output
  .apb_clk(apb_clk),                                    // input
  .apb_rst_n(apb_rst_n),                                // input
  .apb_sel(apb_sel),                                    // input
  .apb_enable(apb_enable),                              // input
  .apb_addr(apb_addr),                                  // input [7:0]
  .apb_write(apb_write),                                // input
  .apb_ready(apb_ready),                                // output
  .apb_wdata(apb_wdata),                                // input [15:0]
  .apb_rdata(apb_rdata),                                // output [15:0]
  .mem_cs_n(mem_cs_n),                                  // output
  .mem_rst_n(mem_rst_n),                                // output
  .mem_ck(mem_ck),                                      // output
  .mem_ck_n(mem_ck_n),                                  // output
  .mem_cke(mem_cke),                                    // output
  .mem_ras_n(mem_ras_n),                                // output
  .mem_cas_n(mem_cas_n),                                // output
  .mem_we_n(mem_we_n),                                  // output
  .mem_odt(mem_odt),                                    // output
  .mem_a(mem_a),                                        // output [14:0]
  .mem_ba(mem_ba),                                      // output [2:0]
  .mem_dqs(mem_dqs),                                    // inout [1:0]
  .mem_dqs_n(mem_dqs_n),                                // inout [1:0]
  .mem_dq(mem_dq),                                      // inout [15:0]
  .mem_dm(mem_dm),                                      // output [1:0]
  .dbg_gate_start(dbg_gate_start),                      // input
  .dbg_cpd_start(dbg_cpd_start),                        // input
  .dbg_ddrphy_rst_n(dbg_ddrphy_rst_n),                  // input
  .dbg_gpll_scan_rst(dbg_gpll_scan_rst),                // input
  .samp_position_dyn_adj(samp_position_dyn_adj),        // input
  .init_samp_position_even(init_samp_position_even),    // input [15:0]
  .init_samp_position_odd(init_samp_position_odd),      // input [15:0]
  .wrcal_position_dyn_adj(wrcal_position_dyn_adj),      // input
  .init_wrcal_position(init_wrcal_position),            // input [15:0]
  .force_read_clk_ctrl(force_read_clk_ctrl),            // input
  .init_slip_step(init_slip_step),                      // input [7:0]
  .init_read_clk_ctrl(init_read_clk_ctrl),              // input [5:0]
  .debug_calib_ctrl(debug_calib_ctrl),                  // output [33:0]
  .dbg_slice_status(dbg_slice_status),                  // output [33:0]
  .dbg_slice_state(dbg_slice_state),                    // output [43:0]
  .debug_data(debug_data),                              // output [137:0]
  .dbg_dll_upd_state(dbg_dll_upd_state),                // output [1:0]
  .debug_gpll_dps_phase(debug_gpll_dps_phase),          // output [8:0]
  .dbg_rst_dps_state(dbg_rst_dps_state),                // output [2:0]
  .dbg_tran_err_rst_cnt(dbg_tran_err_rst_cnt),          // output [5:0]
  .dbg_ddrphy_init_fail(dbg_ddrphy_init_fail),          // output
  .debug_cpd_offset_adj(debug_cpd_offset_adj),          // input
  .debug_cpd_offset_dir(debug_cpd_offset_dir),          // input
  .debug_cpd_offset(debug_cpd_offset),                  // input [9:0]
  .debug_dps_cnt_dir0(debug_dps_cnt_dir0),              // output [9:0]
  .debug_dps_cnt_dir1(debug_dps_cnt_dir1),              // output [9:0]
  .ck_dly_en(ck_dly_en),                                // input
  .init_ck_dly_step(init_ck_dly_step),                  // input [7:0]
  .ck_dly_set_bin(ck_dly_set_bin),                      // output [7:0]
  .align_error(align_error),                            // output
  .debug_rst_state(debug_rst_state),                    // output [3:0]
  .debug_cpd_state(debug_cpd_state)                     // output [3:0]
);
