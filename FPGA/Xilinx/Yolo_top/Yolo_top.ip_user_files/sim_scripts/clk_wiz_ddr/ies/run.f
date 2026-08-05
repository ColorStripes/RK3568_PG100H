-makelib ies_lib/xpm -sv \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib ies_lib/xpm \
  "E:/Vivado/Vivado/2020.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../../Yolo_top.gen/sources_1/ip/clk_wiz_ddr/clk_wiz_ddr_clk_wiz.v" \
  "../../../../Yolo_top.gen/sources_1/ip/clk_wiz_ddr/clk_wiz_ddr.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

