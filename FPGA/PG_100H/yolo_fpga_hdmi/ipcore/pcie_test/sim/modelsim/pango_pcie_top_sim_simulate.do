vopt +acc +nospecify +define+IPS2L_PCIE_SPEEDUP_SIM +define+IPM_HSST_SPEEDUP_SIM +define+DWC_DISABLE_CDC_METHOD_REPORTING work.pango_pcie_top_tb -o voptsim
vsim -c +nospecify +define+IPS2L_PCIE_SPEEDUP_SIM +define+IPM_HSST_SPEEDUP_SIM +define+DWC_DISABLE_CDC_METHOD_REPORTING voptsim -l vsim.log
do pango_pcie_top_wave.do
run -all
