// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
// Date        : Fri Dec  6 16:26:13 2019
// Host        : DESKTOP-D3911JL running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/Fernando/Documents/Universidad/TFG_VHDL/MIDI_Soc-Versions/MIDI_Soc-0.8/MIDI_Soc/MIDI_Soc.srcs/sources_1/ip/ClkGen/ClkGen_stub.v
// Design      : ClkGen
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module ClkGen(clk_200MHz_o, resetn, locked, clk_100MHz_i)
/* synthesis syn_black_box black_box_pad_pin="clk_200MHz_o,resetn,locked,clk_100MHz_i" */;
  output clk_200MHz_o;
  input resetn;
  output locked;
  input clk_100MHz_i;
endmodule
