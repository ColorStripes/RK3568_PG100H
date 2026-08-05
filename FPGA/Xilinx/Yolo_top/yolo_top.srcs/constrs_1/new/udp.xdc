create_clock -period 8.000 -name rgmii_rx_clk [get_ports rgmii_rx_clk]
create_clock -period 8.000 -name rgmii_tx_clk [get_ports rgmii_tx_clk]

# ---------------- Input Delays (PHY -> FPGA)
# PHY 内部延迟 ~1.2ns，需要扣除 FPGA 内部时钟路径
set_input_delay -clock rgmii_rx_clk -max 2.600 [get_ports {{rgmii_rx_data[*]} rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min 1.000 [get_ports {{rgmii_rx_data[*]} rgmii_rx_ctl}]

## ---------------- Output Delays (FPGA -> PHY)
## FPGA 输出延迟，PHY 内部采样时钟 0ns
#set_output_delay -clock rgmii_tx_clk -max 0.500 [get_ports {{rgmii_tx_data[*]} rgmii_tx_ctl}]
#set_output_delay -clock rgmii_tx_clk -min -0.500 [get_ports {{rgmii_tx_data[*]} rgmii_tx_ctl}]

set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rx_data[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rx_data[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rx_data[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rx_data[0]}]
set_property PACKAGE_PIN U4 [get_ports {rgmii_rx_data[0]}]
set_property PACKAGE_PIN U5 [get_ports {rgmii_rx_data[1]}]
set_property PACKAGE_PIN Y9 [get_ports {rgmii_rx_data[2]}]
set_property PACKAGE_PIN Y10 [get_ports {rgmii_rx_data[3]}]
set_property PACKAGE_PIN AC9 [get_ports {rgmii_tx_data[0]}]
set_property PACKAGE_PIN AB9 [get_ports {rgmii_tx_data[1]}]
set_property PACKAGE_PIN AB5 [get_ports {rgmii_tx_data[2]}]
set_property PACKAGE_PIN AB6 [get_ports {rgmii_tx_data[3]}]
set_property PACKAGE_PIN R9 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_tx_data[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_tx_data[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_tx_data[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_tx_data[0]}]
set_property PACKAGE_PIN AA7 [get_ports rgmii_rx_clk]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_clk]
set_property PACKAGE_PIN AA6 [get_ports rgmii_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_ctl]
set_property PACKAGE_PIN V3 [get_ports rgmii_tx_clk]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_clk]
set_property PACKAGE_PIN V4 [get_ports rgmii_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_ctl]
set_property PACKAGE_PIN AN12 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]



















# 确认该端口在校准期间不可用，消除 DRC
set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {rgmii_tx_data[1]}]
set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {rgmii_tx_data[3]}]






























































































































































































































































