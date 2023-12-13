spritesheet_test:
	python3 ./spritesheet.py ./assets/fox_spritesheet.png 1 5 7

spritesheet:
	python3 ./spritesheet.py ./assets/spritesheet.png 12 2 14

sim_mouse:
	iverilog -g2012 -o mouse.out sim/mouse_tb.sv hdl/mouse.sv hdl/synchronizer.sv
	vvp mouse.out

assemble:
	python3 ./removewhitespace.py
	python3 ./assembler.py

build:
	./remote/r.py build.py build.tcl hdl/* xdc/top_level.xdc data/* obj/

flash:
	sudo openFPGALoader -b arty_s7_50 obj/final.bit

start: build flash
