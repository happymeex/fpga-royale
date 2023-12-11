#!/bin/bash
python3 removewhitespace.py
python3 assembler.py
#iverilog -g2012 -o sim/sim.out sim/processor_tb.sv hdl/singleprocessor.sv hdl/xilinx_single_port_ram_read_first.v
iverilog -g2012 -o sim/sim.out sim/processor_tb.sv hdl/singleprocessor.sv hdl/xilinx_single_port_ram_read_first.v hdl/xilinx_true_dual_port_read_first_2_clock_ram.v hdl/uart_rx.sv hdl/ram_bridge_rx.sv 
vvp sim/sim.out 
open dump.vcd  