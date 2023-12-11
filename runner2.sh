#!/bin/bash
openFPGALoader -b arty_s7_50 obj/final.bit
python3 removewhitespace.py
python3 assembler.py
python3 flash.py data/instructions.mem 
# iverilog -g2012 -o sim/sim.out sim/top_level_tb.sv hdl/graphics.sv hdl/singleprocessor.sv hdl/top_level.sv hdl/video_sig_gen.sv hdl/xilinx_single_port_ram_read_first.v
# vvp sim/sim.out 
# open processor.vcd  