-makelib xcelium_lib/xpm -sv \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/microblaze_v11_0_4 \
  "../../../ipstatic/hdl/microblaze_v11_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_0/sim/bd_c703_microblaze_I_0.vhd" \
-endlib
-makelib xcelium_lib/lib_cdc_v1_0_2 \
  "../../../ipstatic/hdl/lib_cdc_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/proc_sys_reset_v5_0_13 \
  "../../../ipstatic/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_1/sim/bd_c703_rst_0_0.vhd" \
-endlib
-makelib xcelium_lib/lmb_v10_v3_0_11 \
  "../../../ipstatic/hdl/lmb_v10_v3_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_2/sim/bd_c703_ilmb_0.vhd" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_3/sim/bd_c703_dlmb_0.vhd" \
-endlib
-makelib xcelium_lib/lmb_bram_if_cntlr_v4_0_19 \
  "../../../ipstatic/hdl/lmb_bram_if_cntlr_v4_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_4/sim/bd_c703_dlmb_cntlr_0.vhd" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_5/sim/bd_c703_ilmb_cntlr_0.vhd" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_4_4 \
  "../../../ipstatic/simulation/blk_mem_gen_v8_4.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_6/sim/bd_c703_lmb_bram_I_0.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_7/sim/bd_c703_second_dlmb_cntlr_0.vhd" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_8/sim/bd_c703_second_ilmb_cntlr_0.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_9/sim/bd_c703_second_lmb_bram_I_0.v" \
-endlib
-makelib xcelium_lib/iomodule_v3_1_6 \
  "../../../ipstatic/hdl/iomodule_v3_1_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/ip/ip_10/sim/bd_c703_iomodule_0_0.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/bd_0/sim/bd_c703.v" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_0/sim/ddr4_microblaze_mcs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/phy/ddr4_phy_ddr4.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy_behav.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/iob/ddr4_phy_v2_2_iob_byte.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/iob/ddr4_phy_v2_2_iob.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/clocking/ddr4_phy_v2_2_pll.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_tristate_wrapper.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_riuor_wrapper.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_control_wrapper.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_byte_wrapper.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_bitslice_wrapper.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/ip_1/rtl/ip_top/ddr4_phy.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_wtr.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ref.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_rd_wr.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_periodic.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_group.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc_merge_enc.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc_gen.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc_fi_xor.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc_dec_fix.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc_buf.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ecc.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_ctl.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_cmd_mux_c.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_cmd_mux_ap.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_arb_p.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_arb_mux_p.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_arb_c.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_arb_a.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_act_timer.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc_act_rank.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/controller/ddr4_v2_2_mc.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ui/ddr4_v2_2_ui_wr_data.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ui/ddr4_v2_2_ui_rd_data.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ui/ddr4_v2_2_ui_cmd.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ui/ddr4_v2_2_ui.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_ar_channel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_aw_channel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_b_channel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_cmd_arbiter.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_cmd_fsm.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_cmd_translator.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_fifo.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_incr_cmd.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_r_channel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_w_channel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_wr_cmd_fsm.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_wrap_cmd.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_a_upsizer.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_register_slice.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axi_upsizer.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_axic_register_slice.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_carry_and.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_carry_latch_and.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_carry_latch_or.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_carry_or.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_command_fifo.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_comparator.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_comparator_sel.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_comparator_sel_static.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_r_upsizer.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi/ddr4_v2_2_w_upsizer.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_addr_decode.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_read.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg_bank.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_top.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_write.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/clocking/ddr4_v2_2_infrastructure.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_xsdb_bram.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_write.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_wr_byte.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_wr_bit.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_sync.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_read.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_rd_en.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_pi.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_mc_odt.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_debug_microblaze.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_cplx_data.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_cplx.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_config_rom.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_addr_decode.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_top.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal_xsdb_arbiter.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_cal.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_chipscope_xsdb_slave.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_v2_2_dp_AB9.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ip_top/ddr4_ddr4.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ip_top/ddr4_ddr4_mem_intfc.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/cal/ddr4_ddr4_cal_riu.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/rtl/ip_top/ddr4.sv" \
  "../../../../../Yolo_top_rk/Yolo_top_rk.gen/sources_1/ip/ddr4/tb/microblaze_mcs_0.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

