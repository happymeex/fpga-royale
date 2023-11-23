`timescale 1ns / 1ps
`default_nettype none

module processor_tb;

    //make logics for inputs and outputs!
  localparam  INSTRUCTIONS_SIZE=13;
  logic pixel_clk_in;
  logic rst_in;
  logic new_frame;
  initial new_frame=0;
  localparam CANVAS_WIDTH=100;
  localparam CANVAS_HEIGHT=100;
  localparam NUM_FRAMES=100;
  logic[$clog2(CANVAS_WIDTH)-1:0] x;
  logic[$clog2(CANVAS_HEIGHT)-1:0] y;
  logic [$clog2(NUM_FRAMES)-1:0] frame;
  logic sprite_valid;
  processor #(.CANVAS_WIDTH(CANVAS_WIDTH),.CANVAS_HEIGHT(CANVAS_HEIGHT), .NUM_FRAMES(NUM_FRAMES),
    .INSTRUCTIONS_SIZE(INSTRUCTIONS_SIZE), .MAX_SPRITES(2),.MEMORY_SIZE(256),.INSTRUCTION_WIDTH(36),.ROW_SIZE(1720))
            uut
            ( .pixel_clk_in(pixel_clk_in),
              .rst_in(rst_in),
              .new_frame(new_frame),
              .x(x),
              .y(y),
              .frame(frame),
              .sprite_valid(sprite_valid)
            );
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        pixel_clk_in = !pixel_clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("processor.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,processor_tb); //store everything at the current level and below
        $dumpvars(0, uut.regs[0], uut.regs[1],uut.regs[2],uut.regs[3],uut.regs[4],uut.regs[5]
        ,uut.regs[6],uut.regs[7],uut.regs[8]);
        //s0
        $dumpvars(0, uut.sprites[0][0],uut.sprites[0][1], uut.sprites[0][2],uut.sprites[0][3]);
        //s1
        $dumpvars(0, uut.sprites[1][0],uut.sprites[1][1], uut.sprites[1][2],uut.sprites[1][3]);
         $dumpvars(0, uut.sprites[32][0],uut.sprites[32][1], uut.sprites[32][2],uut.sprites[32][3]);
        //memory
        $dumpvars(0,uut.memory.BRAM[0],uut.memory.BRAM[1]);
        $display("Starting Sim"); //print nice message
        pixel_clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        for (int i=0;i<INSTRUCTIONS_SIZE*1000;i++)begin
          #10;
        end
        #100;
        $display("Finishing Sim"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire

