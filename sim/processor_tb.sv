`timescale 1ns / 1ps
`default_nettype none

module processor_tb;

    //make logics for inputs and outputs!
  localparam  INSTRUCTIONS_SIZE=400;
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
  logic [31:0]m1x;
  logic[31:0] m1y;
  logic m1c;
  logic [31:0]m2x;
  logic[31:0] m2y;
  logic m2c;
  singleprocessor #(.CANVAS_WIDTH(CANVAS_WIDTH),.CANVAS_HEIGHT(CANVAS_HEIGHT), .NUM_FRAMES(NUM_FRAMES),
    .INSTRUCTIONS_SIZE(INSTRUCTIONS_SIZE), .MAX_SPRITES(2),.MEMORY_SIZE(512),.INSTRUCTION_WIDTH(36),.ROW_SIZE(1720))
            uut
            ( .pixel_clk_in(pixel_clk_in),
              .rst_in(rst_in),
              .new_frame(new_frame),
              .x(x),
              .y(y),
              .frame(frame),
              .sprite_valid(sprite_valid),
              .mouse1x(m1x),
              .mouse1y(m1y),
              .isClicked1(m1c),
              .mouse2x(m2x),
              .mouse2y(m2y),
              .isClicked2(m2c),
              .isOn(1)
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
        ,uut.regs[6],uut.regs[7],uut.regs[8],uut.regs[9],uut.regs[10],uut.regs[11]
        ,uut.regs[12],uut.regs[13],uut.regs[14],uut.regs[15],uut.regs[16],uut.regs[17]
        ,uut.regs[18],uut.regs[19],uut.regs[20],uut.regs[21],uut.regs[22],uut.regs[23]);
        //s0
        $dumpvars(0, uut.sprites[0],uut.sprites[1], uut.sprites[2],uut.sprites[3],
        uut.sprites[4],uut.sprites[5], uut.sprites[6],uut.sprites[7]);
        //s1
        $dumpvars(0, uut.sprites[8],uut.sprites[9], uut.sprites[10],uut.sprites[11],
        uut.sprites[12],uut.sprites[13], uut.sprites[14],uut.sprites[15]);
        $dumpvars(0, uut.sprites[16],uut.sprites[17], uut.sprites[18],uut.sprites[19],
        uut.sprites[20],uut.sprites[21], uut.sprites[22],uut.sprites[23]);
 //        uut.sprites[24],uut.sprites[25], uut.sprites[26],uut.sprites[27],
   //       uut.sprites[28],uut.sprites[29], uut.sprites[30],uut.sprites[31]);
        $dumpvars(0,uut.sprites[16]);
        $dumpvars(0,uut.sprites[24]);
        // $dumpvars(0,uut.sprites[32]);
        // $dumpvars(0,uut.sprites[48]);
        // $dumpvars(0,uut.sprites[64]);
        // $dumpvars(0,uut.sprites[80]);
        // $dumpvars(0,uut.sprites[96]);
        // $dumpvars(0,uut.sprites[112]);
        // $dumpvars(0,uut.sprites[128]);
        // $dumpvars(0,uut.sprites[144]);
        // $dumpvars(0,uut.sprites[160]);
        // $dumpvars(0,uut.sprites[176]);


       //  $dumpvars(0, uut.sprites[31],uut.sprites[31][1], uut.sprites[31][2],uut.sprites[31][3]);
        //memory
        $dumpvars(0,uut.memory.BRAM[0],uut.memory.BRAM[1],uut.memory.BRAM[2],uut.memory.BRAM[3],uut.memory.BRAM[5],
        uut.memory.BRAM[6],uut.memory.BRAM[7],
          uut.memory.BRAM[65],uut.memory.BRAM[67],uut.memory.BRAM[69],uut.memory.BRAM[66],uut.memory.BRAM[70],
          uut.memory.BRAM[72],uut.memory.BRAM[73]);
        $display("Starting Sim"); //print nice message
        pixel_clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        for (int i=0;i<INSTRUCTIONS_SIZE*2000;i++)begin
          $display("Sim",i); //print nice message
          new_frame=1;
          #10
          new_frame=0;
          #10;
        end
        #100;
        $display("Finishing Sim"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire

