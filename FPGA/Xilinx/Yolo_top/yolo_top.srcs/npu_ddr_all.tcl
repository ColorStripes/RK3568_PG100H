
################################################################
# This is a generated script based on design: npu_ddr
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source npu_ddr_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu15eg-ffvb1156-2-i
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name npu_ddr

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_datamover:5.1\
xilinx.com:user:cmd_mm2s:2.0\
xilinx.com:user:cmd_s2mm:2.0\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:xlconstant:1.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set C0_DDR4_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 C0_DDR4_0 ]

  set C0_SYS_CLK_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 C0_SYS_CLK_0 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $C0_SYS_CLK_0


  # Create ports
  set clk [ create_bd_port -dir O -type clk clk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] $clk
  set read_cmd_addr_0 [ create_bd_port -dir I -from 31 -to 0 read_cmd_addr_0 ]
  set read_cmd_addr_1 [ create_bd_port -dir I -from 31 -to 0 read_cmd_addr_1 ]
  set read_cmd_addr_2 [ create_bd_port -dir I -from 31 -to 0 read_cmd_addr_2 ]
  set read_cmd_len_0 [ create_bd_port -dir I -from 31 -to 0 read_cmd_len_0 ]
  set read_cmd_len_1 [ create_bd_port -dir I -from 31 -to 0 read_cmd_len_1 ]
  set read_cmd_len_2 [ create_bd_port -dir I -from 31 -to 0 read_cmd_len_2 ]
  set read_cmd_ready_0 [ create_bd_port -dir O read_cmd_ready_0 ]
  set read_cmd_ready_1 [ create_bd_port -dir O read_cmd_ready_1 ]
  set read_cmd_ready_2 [ create_bd_port -dir O read_cmd_ready_2 ]
  set read_cmd_valid_0 [ create_bd_port -dir I read_cmd_valid_0 ]
  set read_cmd_valid_1 [ create_bd_port -dir I read_cmd_valid_1 ]
  set read_cmd_valid_2 [ create_bd_port -dir I read_cmd_valid_2 ]
  set read_data_0 [ create_bd_port -dir O -from 127 -to 0 read_data_0 ]
  set read_data_1 [ create_bd_port -dir O -from 127 -to 0 read_data_1 ]
  set read_data_2 [ create_bd_port -dir O -from 127 -to 0 read_data_2 ]
  set read_keep_0 [ create_bd_port -dir O -from 15 -to 0 read_keep_0 ]
  set read_keep_1 [ create_bd_port -dir O -from 15 -to 0 read_keep_1 ]
  set read_keep_2 [ create_bd_port -dir O -from 15 -to 0 read_keep_2 ]
  set read_last_0 [ create_bd_port -dir O read_last_0 ]
  set read_last_1 [ create_bd_port -dir O read_last_1 ]
  set read_last_2 [ create_bd_port -dir O read_last_2 ]
  set read_ready_0 [ create_bd_port -dir I read_ready_0 ]
  set read_ready_1 [ create_bd_port -dir I read_ready_1 ]
  set read_ready_2 [ create_bd_port -dir I read_ready_2 ]
  set read_valid_0 [ create_bd_port -dir O read_valid_0 ]
  set read_valid_1 [ create_bd_port -dir O read_valid_1 ]
  set read_valid_2 [ create_bd_port -dir O read_valid_2 ]
  set rst [ create_bd_port -dir O -type rst rst ]
  set sys_rst [ create_bd_port -dir I -type rst sys_rst ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $sys_rst
  set write_cmd_addr_0 [ create_bd_port -dir I -from 31 -to 0 write_cmd_addr_0 ]
  set write_cmd_addr_1 [ create_bd_port -dir I -from 31 -to 0 write_cmd_addr_1 ]
  set write_cmd_addr_2 [ create_bd_port -dir I -from 31 -to 0 write_cmd_addr_2 ]
  set write_cmd_len_0 [ create_bd_port -dir I -from 31 -to 0 write_cmd_len_0 ]
  set write_cmd_len_1 [ create_bd_port -dir I -from 31 -to 0 write_cmd_len_1 ]
  set write_cmd_len_2 [ create_bd_port -dir I -from 31 -to 0 write_cmd_len_2 ]
  set write_cmd_ready_0 [ create_bd_port -dir O write_cmd_ready_0 ]
  set write_cmd_ready_1 [ create_bd_port -dir O write_cmd_ready_1 ]
  set write_cmd_ready_2 [ create_bd_port -dir O write_cmd_ready_2 ]
  set write_cmd_valid_0 [ create_bd_port -dir I write_cmd_valid_0 ]
  set write_cmd_valid_1 [ create_bd_port -dir I write_cmd_valid_1 ]
  set write_cmd_valid_2 [ create_bd_port -dir I write_cmd_valid_2 ]
  set write_data_0 [ create_bd_port -dir I -from 127 -to 0 write_data_0 ]
  set write_data_1 [ create_bd_port -dir I -from 127 -to 0 write_data_1 ]
  set write_data_2 [ create_bd_port -dir I -from 127 -to 0 write_data_2 ]
  set write_keep_0 [ create_bd_port -dir I -from 15 -to 0 write_keep_0 ]
  set write_keep_1 [ create_bd_port -dir I -from 15 -to 0 write_keep_1 ]
  set write_keep_2 [ create_bd_port -dir I -from 15 -to 0 write_keep_2 ]
  set write_last_0 [ create_bd_port -dir I write_last_0 ]
  set write_last_1 [ create_bd_port -dir I write_last_1 ]
  set write_last_2 [ create_bd_port -dir I write_last_2 ]
  set write_ready_0 [ create_bd_port -dir O write_ready_0 ]
  set write_ready_1 [ create_bd_port -dir O write_ready_1 ]
  set write_ready_2 [ create_bd_port -dir O write_ready_2 ]
  set write_valid_0 [ create_bd_port -dir I write_valid_0 ]
  set write_valid_1 [ create_bd_port -dir I write_valid_1 ]
  set write_valid_2 [ create_bd_port -dir I write_valid_2 ]

  # Create instance: axi_datamover_0, and set properties
  set axi_datamover_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_0 ]
  set_property -dict [ list \
   CONFIG.c_dummy {1} \
   CONFIG.c_enable_cache_user {false} \
   CONFIG.c_include_mm2s_dre {true} \
   CONFIG.c_include_s2mm_dre {true} \
   CONFIG.c_m_axi_mm2s_data_width {128} \
   CONFIG.c_m_axi_s2mm_awid {1} \
   CONFIG.c_m_axi_s2mm_data_width {128} \
   CONFIG.c_m_axis_mm2s_tdata_width {128} \
   CONFIG.c_mm2s_btt_used {23} \
   CONFIG.c_mm2s_burst_size {64} \
   CONFIG.c_mm2s_include_sf {false} \
   CONFIG.c_s2mm_btt_used {23} \
   CONFIG.c_s2mm_burst_size {64} \
   CONFIG.c_s_axis_s2mm_tdata_width {128} \
   CONFIG.c_single_interface {1} \
 ] $axi_datamover_0

  # Create instance: axi_datamover_1, and set properties
  set axi_datamover_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_1 ]
  set_property -dict [ list \
   CONFIG.c_dummy {1} \
   CONFIG.c_enable_cache_user {false} \
   CONFIG.c_include_mm2s_dre {true} \
   CONFIG.c_include_s2mm_dre {true} \
   CONFIG.c_m_axi_mm2s_arid {2} \
   CONFIG.c_m_axi_mm2s_data_width {128} \
   CONFIG.c_m_axi_s2mm_awid {3} \
   CONFIG.c_m_axi_s2mm_data_width {128} \
   CONFIG.c_m_axis_mm2s_tdata_width {128} \
   CONFIG.c_mm2s_btt_used {23} \
   CONFIG.c_mm2s_burst_size {64} \
   CONFIG.c_mm2s_include_sf {false} \
   CONFIG.c_s2mm_btt_used {23} \
   CONFIG.c_s2mm_burst_size {64} \
   CONFIG.c_s_axis_s2mm_tdata_width {128} \
   CONFIG.c_single_interface {1} \
 ] $axi_datamover_1

  # Create instance: axi_datamover_2, and set properties
  set axi_datamover_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_2 ]
  set_property -dict [ list \
   CONFIG.c_dummy {1} \
   CONFIG.c_enable_cache_user {false} \
   CONFIG.c_include_mm2s_dre {true} \
   CONFIG.c_include_s2mm_dre {true} \
   CONFIG.c_m_axi_mm2s_arid {4} \
   CONFIG.c_m_axi_mm2s_data_width {128} \
   CONFIG.c_m_axi_s2mm_awid {5} \
   CONFIG.c_m_axi_s2mm_data_width {128} \
   CONFIG.c_m_axis_mm2s_tdata_width {128} \
   CONFIG.c_mm2s_btt_used {23} \
   CONFIG.c_mm2s_burst_size {64} \
   CONFIG.c_mm2s_include_sf {false} \
   CONFIG.c_s2mm_btt_used {23} \
   CONFIG.c_s2mm_burst_size {64} \
   CONFIG.c_s_axis_s2mm_tdata_width {128} \
   CONFIG.c_single_interface {1} \
 ] $axi_datamover_2

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {3} \
 ] $axi_interconnect_0

  # Create instance: cmd_mm2s_0, and set properties
  set cmd_mm2s_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_mm2s:2.0 cmd_mm2s_0 ]

  # Create instance: cmd_mm2s_1, and set properties
  set cmd_mm2s_1 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_mm2s:2.0 cmd_mm2s_1 ]

  # Create instance: cmd_mm2s_2, and set properties
  set cmd_mm2s_2 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_mm2s:2.0 cmd_mm2s_2 ]

  # Create instance: cmd_s2mm_0, and set properties
  set cmd_s2mm_0 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_s2mm:2.0 cmd_s2mm_0 ]

  # Create instance: cmd_s2mm_1, and set properties
  set cmd_s2mm_1 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_s2mm:2.0 cmd_s2mm_1 ]

  # Create instance: cmd_s2mm_2, and set properties
  set cmd_s2mm_2 [ create_bd_cell -type ip -vlnv xilinx.com:user:cmd_s2mm:2.0 cmd_s2mm_2 ]

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [ list \
   CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {250} \
   CONFIG.C0.BANK_GROUP_WIDTH {1} \
   CONFIG.C0.DDR4_AxiAddressWidth {31} \
   CONFIG.C0.DDR4_AxiDataWidth {256} \
   CONFIG.C0.DDR4_CLKOUT0_DIVIDE {5} \
   CONFIG.C0.DDR4_CasWriteLatency {12} \
   CONFIG.C0.DDR4_DataWidth {32} \
   CONFIG.C0.DDR4_InputClockPeriod {4998} \
   CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-083E} \
   CONFIG.C0.DDR4_TimePeriod {833} \
   CONFIG.System_Clock {Differential} \
 ] $ddr4_0

  # Create instance: rst_250M, and set properties
  set rst_250M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_250M ]

  # Create instance: rst_ddr4_0_300M, and set properties
  set rst_ddr4_0_300M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ddr4_0_300M ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net C0_SYS_CLK_0_1 [get_bd_intf_ports C0_SYS_CLK_0] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI [get_bd_intf_pins axi_datamover_0/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S] [get_bd_intf_pins cmd_mm2s_0/m_axis_mm2s]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S_STS [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S_STS] [get_bd_intf_pins cmd_mm2s_0/m_axis_mm2s_sts]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_S2MM_STS [get_bd_intf_pins axi_datamover_0/M_AXIS_S2MM_STS] [get_bd_intf_pins cmd_s2mm_0/m_axis_s2mm_sts]
  connect_bd_intf_net -intf_net axi_datamover_1_M_AXI [get_bd_intf_pins axi_datamover_1/M_AXI] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axi_datamover_1_M_AXIS_MM2S [get_bd_intf_pins axi_datamover_1/M_AXIS_MM2S] [get_bd_intf_pins cmd_mm2s_1/m_axis_mm2s]
  connect_bd_intf_net -intf_net axi_datamover_1_M_AXIS_MM2S_STS [get_bd_intf_pins axi_datamover_1/M_AXIS_MM2S_STS] [get_bd_intf_pins cmd_mm2s_1/m_axis_mm2s_sts]
  connect_bd_intf_net -intf_net axi_datamover_1_M_AXIS_S2MM_STS [get_bd_intf_pins axi_datamover_1/M_AXIS_S2MM_STS] [get_bd_intf_pins cmd_s2mm_1/m_axis_s2mm_sts]
  connect_bd_intf_net -intf_net axi_datamover_2_M_AXI [get_bd_intf_pins axi_datamover_2/M_AXI] [get_bd_intf_pins axi_interconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net axi_datamover_2_M_AXIS_MM2S [get_bd_intf_pins axi_datamover_2/M_AXIS_MM2S] [get_bd_intf_pins cmd_mm2s_2/m_axis_mm2s]
  connect_bd_intf_net -intf_net axi_datamover_2_M_AXIS_MM2S_STS [get_bd_intf_pins axi_datamover_2/M_AXIS_MM2S_STS] [get_bd_intf_pins cmd_mm2s_2/m_axis_mm2s_sts]
  connect_bd_intf_net -intf_net axi_datamover_2_M_AXIS_S2MM_STS [get_bd_intf_pins axi_datamover_2/M_AXIS_S2MM_STS] [get_bd_intf_pins cmd_s2mm_2/m_axis_s2mm_sts]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net cmd_mm2s_0_s_axis_mm2s_cmd [get_bd_intf_pins axi_datamover_0/S_AXIS_MM2S_CMD] [get_bd_intf_pins cmd_mm2s_0/s_axis_mm2s_cmd]
  connect_bd_intf_net -intf_net cmd_mm2s_1_s_axis_mm2s_cmd [get_bd_intf_pins axi_datamover_1/S_AXIS_MM2S_CMD] [get_bd_intf_pins cmd_mm2s_1/s_axis_mm2s_cmd]
  connect_bd_intf_net -intf_net cmd_mm2s_2_s_axis_mm2s_cmd [get_bd_intf_pins axi_datamover_2/S_AXIS_MM2S_CMD] [get_bd_intf_pins cmd_mm2s_2/s_axis_mm2s_cmd]
  connect_bd_intf_net -intf_net cmd_s2mm_0_s_axis_s2mm [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM] [get_bd_intf_pins cmd_s2mm_0/s_axis_s2mm]
  connect_bd_intf_net -intf_net cmd_s2mm_0_s_axis_s2mm_cmd [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM_CMD] [get_bd_intf_pins cmd_s2mm_0/s_axis_s2mm_cmd]
  connect_bd_intf_net -intf_net cmd_s2mm_1_s_axis_s2mm [get_bd_intf_pins axi_datamover_1/S_AXIS_S2MM] [get_bd_intf_pins cmd_s2mm_1/s_axis_s2mm]
  connect_bd_intf_net -intf_net cmd_s2mm_1_s_axis_s2mm_cmd [get_bd_intf_pins axi_datamover_1/S_AXIS_S2MM_CMD] [get_bd_intf_pins cmd_s2mm_1/s_axis_s2mm_cmd]
  connect_bd_intf_net -intf_net cmd_s2mm_2_s_axis_s2mm [get_bd_intf_pins axi_datamover_2/S_AXIS_S2MM] [get_bd_intf_pins cmd_s2mm_2/s_axis_s2mm]
  connect_bd_intf_net -intf_net cmd_s2mm_2_s_axis_s2mm_cmd [get_bd_intf_pins axi_datamover_2/S_AXIS_S2MM_CMD] [get_bd_intf_pins cmd_s2mm_2/s_axis_s2mm_cmd]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports C0_DDR4_0] [get_bd_intf_pins ddr4_0/C0_DDR4]

  # Create port connections
  connect_bd_net -net cmd_mm2s_0_read_cmd_ready [get_bd_ports read_cmd_ready_0] [get_bd_pins cmd_mm2s_0/read_cmd_ready]
  connect_bd_net -net cmd_mm2s_0_read_data [get_bd_ports read_data_0] [get_bd_pins cmd_mm2s_0/read_data]
  connect_bd_net -net cmd_mm2s_0_read_keep [get_bd_ports read_keep_0] [get_bd_pins cmd_mm2s_0/read_keep]
  connect_bd_net -net cmd_mm2s_0_read_last [get_bd_ports read_last_0] [get_bd_pins cmd_mm2s_0/read_last]
  connect_bd_net -net cmd_mm2s_0_read_valid [get_bd_ports read_valid_0] [get_bd_pins cmd_mm2s_0/read_valid]
  connect_bd_net -net cmd_mm2s_1_read_cmd_ready [get_bd_ports read_cmd_ready_1] [get_bd_pins cmd_mm2s_1/read_cmd_ready]
  connect_bd_net -net cmd_mm2s_1_read_data [get_bd_ports read_data_1] [get_bd_pins cmd_mm2s_1/read_data]
  connect_bd_net -net cmd_mm2s_1_read_keep [get_bd_ports read_keep_1] [get_bd_pins cmd_mm2s_1/read_keep]
  connect_bd_net -net cmd_mm2s_1_read_last [get_bd_ports read_last_1] [get_bd_pins cmd_mm2s_1/read_last]
  connect_bd_net -net cmd_mm2s_1_read_valid [get_bd_ports read_valid_1] [get_bd_pins cmd_mm2s_1/read_valid]
  connect_bd_net -net cmd_mm2s_2_read_cmd_ready [get_bd_ports read_cmd_ready_2] [get_bd_pins cmd_mm2s_2/read_cmd_ready]
  connect_bd_net -net cmd_mm2s_2_read_data [get_bd_ports read_data_2] [get_bd_pins cmd_mm2s_2/read_data]
  connect_bd_net -net cmd_mm2s_2_read_keep [get_bd_ports read_keep_2] [get_bd_pins cmd_mm2s_2/read_keep]
  connect_bd_net -net cmd_mm2s_2_read_last [get_bd_ports read_last_2] [get_bd_pins cmd_mm2s_2/read_last]
  connect_bd_net -net cmd_mm2s_2_read_valid [get_bd_ports read_valid_2] [get_bd_pins cmd_mm2s_2/read_valid]
  connect_bd_net -net cmd_s2mm_0_write_cmd_ready [get_bd_ports write_cmd_ready_0] [get_bd_pins cmd_s2mm_0/write_cmd_ready]
  connect_bd_net -net cmd_s2mm_0_write_ready [get_bd_ports write_ready_0] [get_bd_pins cmd_s2mm_0/write_ready]
  connect_bd_net -net cmd_s2mm_1_write_cmd_ready [get_bd_ports write_cmd_ready_1] [get_bd_pins cmd_s2mm_1/write_cmd_ready]
  connect_bd_net -net cmd_s2mm_1_write_ready [get_bd_ports write_ready_1] [get_bd_pins cmd_s2mm_1/write_ready]
  connect_bd_net -net cmd_s2mm_2_write_cmd_ready [get_bd_ports write_cmd_ready_2] [get_bd_pins cmd_s2mm_2/write_cmd_ready]
  connect_bd_net -net cmd_s2mm_2_write_ready [get_bd_ports write_ready_2] [get_bd_pins cmd_s2mm_2/write_ready]
  connect_bd_net -net ddr4_0_addn_ui_clkout1 [get_bd_ports clk] [get_bd_pins axi_datamover_0/m_axi_mm2s_aclk] [get_bd_pins axi_datamover_0/m_axi_s2mm_aclk] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aclk] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_awclk] [get_bd_pins axi_datamover_1/m_axi_mm2s_aclk] [get_bd_pins axi_datamover_1/m_axi_s2mm_aclk] [get_bd_pins axi_datamover_1/m_axis_mm2s_cmdsts_aclk] [get_bd_pins axi_datamover_1/m_axis_s2mm_cmdsts_awclk] [get_bd_pins axi_datamover_2/m_axi_mm2s_aclk] [get_bd_pins axi_datamover_2/m_axi_s2mm_aclk] [get_bd_pins axi_datamover_2/m_axis_mm2s_cmdsts_aclk] [get_bd_pins axi_datamover_2/m_axis_s2mm_cmdsts_awclk] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_0/S02_ACLK] [get_bd_pins cmd_mm2s_0/clk] [get_bd_pins cmd_mm2s_1/clk] [get_bd_pins cmd_mm2s_2/clk] [get_bd_pins cmd_s2mm_0/clk] [get_bd_pins cmd_s2mm_1/clk] [get_bd_pins cmd_s2mm_2/clk] [get_bd_pins ddr4_0/addn_ui_clkout1] [get_bd_pins rst_250M/slowest_sync_clk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins rst_ddr4_0_300M/slowest_sync_clk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_ports rst] [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins rst_250M/ext_reset_in] [get_bd_pins rst_ddr4_0_300M/ext_reset_in]
  connect_bd_net -net read_cmd_addr_0_1 [get_bd_ports read_cmd_addr_0] [get_bd_pins cmd_mm2s_0/read_cmd_addr]
  connect_bd_net -net read_cmd_addr_1_1 [get_bd_ports read_cmd_addr_1] [get_bd_pins cmd_mm2s_1/read_cmd_addr]
  connect_bd_net -net read_cmd_addr_2_1 [get_bd_ports read_cmd_addr_2] [get_bd_pins cmd_mm2s_2/read_cmd_addr]
  connect_bd_net -net read_cmd_len_0_1 [get_bd_ports read_cmd_len_0] [get_bd_pins cmd_mm2s_0/read_cmd_len]
  connect_bd_net -net read_cmd_len_1_1 [get_bd_ports read_cmd_len_1] [get_bd_pins cmd_mm2s_1/read_cmd_len]
  connect_bd_net -net read_cmd_len_2_1 [get_bd_ports read_cmd_len_2] [get_bd_pins cmd_mm2s_2/read_cmd_len]
  connect_bd_net -net read_cmd_valid_0_1 [get_bd_ports read_cmd_valid_0] [get_bd_pins cmd_mm2s_0/read_cmd_valid]
  connect_bd_net -net read_cmd_valid_1_1 [get_bd_ports read_cmd_valid_1] [get_bd_pins cmd_mm2s_1/read_cmd_valid]
  connect_bd_net -net read_cmd_valid_2_1 [get_bd_ports read_cmd_valid_2] [get_bd_pins cmd_mm2s_2/read_cmd_valid]
  connect_bd_net -net read_ready_0_1 [get_bd_ports read_ready_0] [get_bd_pins cmd_mm2s_0/read_ready]
  connect_bd_net -net read_ready_1_1 [get_bd_ports read_ready_1] [get_bd_pins cmd_mm2s_1/read_ready]
  connect_bd_net -net read_ready_2_1 [get_bd_ports read_ready_2] [get_bd_pins cmd_mm2s_2/read_ready]
  connect_bd_net -net reset_rtl_0_1 [get_bd_ports sys_rst] [get_bd_pins ddr4_0/sys_rst]
  connect_bd_net -net rst_250M_peripheral_aresetn [get_bd_pins axi_datamover_0/m_axi_mm2s_aresetn] [get_bd_pins axi_datamover_0/m_axi_s2mm_aresetn] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aresetn] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_aresetn] [get_bd_pins axi_datamover_1/m_axi_mm2s_aresetn] [get_bd_pins axi_datamover_1/m_axi_s2mm_aresetn] [get_bd_pins axi_datamover_1/m_axis_mm2s_cmdsts_aresetn] [get_bd_pins axi_datamover_1/m_axis_s2mm_cmdsts_aresetn] [get_bd_pins axi_datamover_2/m_axi_mm2s_aresetn] [get_bd_pins axi_datamover_2/m_axi_s2mm_aresetn] [get_bd_pins axi_datamover_2/m_axis_mm2s_cmdsts_aresetn] [get_bd_pins axi_datamover_2/m_axis_s2mm_cmdsts_aresetn] [get_bd_pins rst_250M/peripheral_aresetn]
  connect_bd_net -net rst_250M_peripheral_reset [get_bd_pins cmd_mm2s_0/rst] [get_bd_pins cmd_mm2s_1/rst] [get_bd_pins cmd_mm2s_2/rst] [get_bd_pins cmd_s2mm_0/rst] [get_bd_pins cmd_s2mm_1/rst] [get_bd_pins cmd_s2mm_2/rst] [get_bd_pins rst_250M/peripheral_reset]
  connect_bd_net -net rst_ddr4_0_250M1_interconnect_aresetn [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_interconnect_0/S02_ARESETN] [get_bd_pins rst_250M/interconnect_aresetn]
  connect_bd_net -net rst_ddr4_0_300M_interconnect_aresetn [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins rst_ddr4_0_300M/interconnect_aresetn]
  connect_bd_net -net write_cmd_addr_0_1 [get_bd_ports write_cmd_addr_0] [get_bd_pins cmd_s2mm_0/write_cmd_addr]
  connect_bd_net -net write_cmd_addr_1_1 [get_bd_ports write_cmd_addr_1] [get_bd_pins cmd_s2mm_1/write_cmd_addr]
  connect_bd_net -net write_cmd_addr_2_1 [get_bd_ports write_cmd_addr_2] [get_bd_pins cmd_s2mm_2/write_cmd_addr]
  connect_bd_net -net write_cmd_len_0_1 [get_bd_ports write_cmd_len_0] [get_bd_pins cmd_s2mm_0/write_cmd_len]
  connect_bd_net -net write_cmd_len_1_1 [get_bd_ports write_cmd_len_1] [get_bd_pins cmd_s2mm_1/write_cmd_len]
  connect_bd_net -net write_cmd_len_2_1 [get_bd_ports write_cmd_len_2] [get_bd_pins cmd_s2mm_2/write_cmd_len]
  connect_bd_net -net write_cmd_valid_0_1 [get_bd_ports write_cmd_valid_0] [get_bd_pins cmd_s2mm_0/write_cmd_valid]
  connect_bd_net -net write_cmd_valid_1_1 [get_bd_ports write_cmd_valid_1] [get_bd_pins cmd_s2mm_1/write_cmd_valid]
  connect_bd_net -net write_cmd_valid_2_1 [get_bd_ports write_cmd_valid_2] [get_bd_pins cmd_s2mm_2/write_cmd_valid]
  connect_bd_net -net write_data_0_1 [get_bd_ports write_data_0] [get_bd_pins cmd_s2mm_0/write_data]
  connect_bd_net -net write_data_1_1 [get_bd_ports write_data_1] [get_bd_pins cmd_s2mm_1/write_data]
  connect_bd_net -net write_data_2_1 [get_bd_ports write_data_2] [get_bd_pins cmd_s2mm_2/write_data]
  connect_bd_net -net write_keep_0_1 [get_bd_ports write_keep_0] [get_bd_pins cmd_s2mm_0/write_keep]
  connect_bd_net -net write_keep_1_1 [get_bd_ports write_keep_1] [get_bd_pins cmd_s2mm_1/write_keep]
  connect_bd_net -net write_keep_2_1 [get_bd_ports write_keep_2] [get_bd_pins cmd_s2mm_2/write_keep]
  connect_bd_net -net write_last_0_1 [get_bd_ports write_last_0] [get_bd_pins cmd_s2mm_0/write_last]
  connect_bd_net -net write_last_1_1 [get_bd_ports write_last_1] [get_bd_pins cmd_s2mm_1/write_last]
  connect_bd_net -net write_last_2_1 [get_bd_ports write_last_2] [get_bd_pins cmd_s2mm_2/write_last]
  connect_bd_net -net write_valid_0_1 [get_bd_ports write_valid_0] [get_bd_pins cmd_s2mm_0/write_valid]
  connect_bd_net -net write_valid_1_1 [get_bd_ports write_valid_1] [get_bd_pins cmd_s2mm_1/write_valid]
  connect_bd_net -net write_valid_2_1 [get_bd_ports write_valid_2] [get_bd_pins cmd_s2mm_2/write_valid]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins xlconstant_0/dout]

  # Create address segments
  assign_bd_address -offset 0x80000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x80000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_datamover_1/Data] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x80000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_datamover_2/Data] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


