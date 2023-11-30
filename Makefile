spritesheet:
	python3 ./spritesheet.py ./assets/fox_spritesheet.png 1 5

assemble:
	python3 ./removewhitespace.py
	python3 ./assembler.py

build:
	./remote/r.py build.py build.tcl hdl/* xdc/top_level.xdc data/* obj/

flash:
	sudo openFPGALoader -b arty_s7_50 obj/final.bit

start: build flash
