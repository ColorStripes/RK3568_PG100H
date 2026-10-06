
# Loading additional proc with user specified bodies to compute parameter values.
source [file join [file dirname [file dirname [info script]]] gui/cmd_s2mm_v1_0.gtcl]

# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BTT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_WIDTH" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "KEEP_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TYPE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USER_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USER_LEN_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH PARAM_VALUE.USER_ADDR_WIDTH } {
	# Procedure called to update ADDR_WIDTH when any of the dependent parameters in the arguments change
	
	set ADDR_WIDTH ${PARAM_VALUE.ADDR_WIDTH}
	set USER_ADDR_WIDTH ${PARAM_VALUE.USER_ADDR_WIDTH}
	set values(USER_ADDR_WIDTH) [get_property value $USER_ADDR_WIDTH]
	set_property value [gen_USERPARAMETER_ADDR_WIDTH_VALUE $values(USER_ADDR_WIDTH)] $ADDR_WIDTH
}

proc validate_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to validate ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update KEEP_WIDTH when any of the dependent parameters in the arguments change
	
	set KEEP_WIDTH ${PARAM_VALUE.KEEP_WIDTH}
	set DATA_WIDTH ${PARAM_VALUE.DATA_WIDTH}
	set values(DATA_WIDTH) [get_property value $DATA_WIDTH]
	set_property value [gen_USERPARAMETER_KEEP_WIDTH_VALUE $values(DATA_WIDTH)] $KEEP_WIDTH
}

proc validate_PARAM_VALUE.KEEP_WIDTH { PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to validate KEEP_WIDTH
	return true
}

proc update_PARAM_VALUE.BTT_WIDTH { PARAM_VALUE.BTT_WIDTH } {
	# Procedure called to update BTT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BTT_WIDTH { PARAM_VALUE.BTT_WIDTH } {
	# Procedure called to validate BTT_WIDTH
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.TYPE { PARAM_VALUE.TYPE } {
	# Procedure called to update TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TYPE { PARAM_VALUE.TYPE } {
	# Procedure called to validate TYPE
	return true
}

proc update_PARAM_VALUE.USER_ADDR_WIDTH { PARAM_VALUE.USER_ADDR_WIDTH } {
	# Procedure called to update USER_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USER_ADDR_WIDTH { PARAM_VALUE.USER_ADDR_WIDTH } {
	# Procedure called to validate USER_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.USER_LEN_WIDTH { PARAM_VALUE.USER_LEN_WIDTH } {
	# Procedure called to update USER_LEN_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USER_LEN_WIDTH { PARAM_VALUE.USER_LEN_WIDTH } {
	# Procedure called to validate USER_LEN_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.USER_ADDR_WIDTH { MODELPARAM_VALUE.USER_ADDR_WIDTH PARAM_VALUE.USER_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USER_ADDR_WIDTH}] ${MODELPARAM_VALUE.USER_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.USER_LEN_WIDTH { MODELPARAM_VALUE.USER_LEN_WIDTH PARAM_VALUE.USER_LEN_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USER_LEN_WIDTH}] ${MODELPARAM_VALUE.USER_LEN_WIDTH}
}

proc update_MODELPARAM_VALUE.ADDR_WIDTH { MODELPARAM_VALUE.ADDR_WIDTH PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_WIDTH}] ${MODELPARAM_VALUE.ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.BTT_WIDTH { MODELPARAM_VALUE.BTT_WIDTH PARAM_VALUE.BTT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BTT_WIDTH}] ${MODELPARAM_VALUE.BTT_WIDTH}
}

proc update_MODELPARAM_VALUE.TYPE { MODELPARAM_VALUE.TYPE PARAM_VALUE.TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TYPE}] ${MODELPARAM_VALUE.TYPE}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.KEEP_WIDTH { MODELPARAM_VALUE.KEEP_WIDTH PARAM_VALUE.KEEP_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.KEEP_WIDTH}] ${MODELPARAM_VALUE.KEEP_WIDTH}
}

