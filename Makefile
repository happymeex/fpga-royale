build:
	./remote/r.py build.py build.tcl hdl/* xdc/top_level.xdc data/* obj/

flash:
	sudo openFPGALoader -b arty_s7_50 obj/final.bit

start: build flash