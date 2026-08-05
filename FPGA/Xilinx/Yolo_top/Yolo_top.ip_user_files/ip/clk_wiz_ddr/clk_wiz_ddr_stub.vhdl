-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
-- Date        : Tue Mar 10 10:39:41 2026
-- Host        : LAPTOP-8FN33LQG running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               F:/FPGA/Yolo_top/Yolo_top.srcs/sources_1/ip/clk_wiz_ddr/clk_wiz_ddr_stub.vhdl
-- Design      : clk_wiz_ddr
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xczu15eg-ffvb1156-2-i
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_wiz_ddr is
  Port ( 
    clk_out1 : out STD_LOGIC;
    clk_out2 : out STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end clk_wiz_ddr;

architecture stub of clk_wiz_ddr is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_out1,clk_out2,clk_in1";
begin
end;
