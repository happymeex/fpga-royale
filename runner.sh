#!/bin/bash
python3 removewhitespace.py
python3 assembler.py
iverilog -g2012 -o sim/sim.out sim/processor_tb.sv hdl/processor.sv hdl/xilinx_single_port_ram_read_first.v
vvp sim/sim.out 
open processor.vcd  