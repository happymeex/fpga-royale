`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module singleprocessor #( parameter CANVAS_WIDTH,parameter CANVAS_HEIGHT, parameter NUM_FRAMES,
  parameter INSTRUCTIONS_SIZE, parameter MAX_SPRITES, parameter MEMORY_SIZE, parameter INSTRUCTION_WIDTH, parameter ROW_SIZE) (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire new_frame,
  output wire[$clog2(CANVAS_WIDTH)-1:0] x,
  output wire [$clog2(CANVAS_HEIGHT)-1:0] y,
  output wire [$clog2(NUM_FRAMES)-1:0] frame,
  output wire sprite_valid,
  input wire[31:0] mouse1x,
  input wire[31:0] mouse1y,
  input wire[31:0] mouse2x,
  input wire[31:0] mouse2y,
  input wire isClicked1,
  input wire isClicked2,
  input wire isOn,
  input wire go,
  output logic [7:0] hp00,
  output logic [7:0] hp01,
  output logic [7:0] hp10,
  output logic [7:0] hp11
  );
  //register file
  /*
   x0=0;
   x1=1;
   ...
   x31=31;

   sprites
   s0=0
   ...
   s63=63
  */
  logic [$clog2(CANVAS_WIDTH)-1:0] x_;
  logic  [$clog2(CANVAS_HEIGHT)-1:0] y_;
  logic  [$clog2(NUM_FRAMES)-1:0] frame_;
  logic sprite_valid_;
  assign x = x_;
  assign y = y_;
  assign frame = frame_;
  assign sprite_valid = sprite_valid_;
  logic [INSTRUCTION_WIDTH-1:0] oldinstruction;
  logic [31:0] r1;
  logic [31:0] r2;
  logic [31:0] r3;
  logic [31:0] r4;
  logic [31:0] regs[31:0];
  logic[31:0] state;
  initial state=0;
  
  //elixir count
  logic [3:0] elixir;
  //all sprites
  logic[12:0] sprites[511:0];
  initial begin
    for (int i = 0 ; i < 64; i++) begin
        sprites[i<<3] = 0;
    end
  end
  logic [31:0] count;
  logic done;
  logic [INSTRUCTION_WIDTH-1:0] instruction;
  logic [31:0] nop;
  logic[31:0] val;
  initial nop=1;
  initial count=0;
  initial done=0;
  logic [31:0] res;
  logic [2:0] sindex;
  logic wsprite;
  logic rdvalid;
  logic [8:0] rd;
  logic [31:0] write;
  logic rb;
  logic wb;
  logic [6:0] instr;
  initial rb=0;
  initial wb=0;

  logic [31:0]memout;
  logic readstage;
  //memory
   xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(16),                       // Specify RAM data width
    .RAM_DEPTH(MEMORY_SIZE),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("LOW LATENCY"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()          // Specify name/location of RAM initialization file if using one (leave blank if not)
   ) memory (
    .addra((rb|wb) ? res:0),     // Address bus, width determined from RAM_DEPTH
    .dina(write),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(wb),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(memout)      // RAM output data, width determined from RAM_WIDTH
  );
  //instructions
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(INSTRUCTION_WIDTH),                       // Specify RAM data width
    .RAM_DEPTH(INSTRUCTIONS_SIZE+1),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("LOW_LATENCY"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  //  .INIT_FILE() 
    .INIT_FILE(`FPATH(instructions.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) instructions (
    .addra(count),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(oldinstruction)      // RAM output data, width determined from RAM_WIDTH
  );
logic [31:0] counter;
logic [3:0] elixir0;
logic [3:0] elixir1; 
always_ff @(posedge pixel_clk_in) begin
    if (isOn) begin
        sprites[496]<=6;
        sprites[497]<=mouse1x;
        sprites[498]<=mouse1y;
        sprites[500]<=isClicked1;
        sprites[504]<=6;
        sprites[505]<=mouse2x;
        sprites[506]<=mouse2y;
        sprites[508]<=isClicked2;
        hp00<=sprites[4];
        hp01<=sprites[12];
        hp10<=sprites[484];
        hp11<=sprites[492];
    // sprites[64]<=6;
    // sprites[65]<=mouse1x;
    // sprites[66]<=mouse1y;
    // sprites[68]<=isClicked1;
    // sprites[72]<=6;
    // sprites[73]<=mouse2x;
    // sprites[74]<=mouse2y;
    // sprites[76]<=isClicked2;
    // sprites[496]<=6;
    // sprites[497]<=mouse1x;
    // sprites[498]<=mouse1y;
    // sprites[500]<=sprites[500]? 1:isClicked1;
   // sprites[504]<=6;
   // sprites[505]<=mouse2x;
   // sprites[506]<=mouse2y;
   // sprites[508]<=sprites[508] ? 1:isClicked2;
    if(new_frame) begin
        state<=0;
        elixir0<=0;
        elixir1<=1;
        counter<=0;
    end
    if (state<64) begin
        if (state==63) begin
            if (elixir0==0) begin
                if (sprites[state<<3]>0) begin
                // if (state==0) begin
                    x_<=sprites[(state<<3)+1];
                    y_<=sprites[(state<<3)+2];
                    //   x_<=100;
                    //  y_<=500;
                    frame_<=sprites[(state<<3)+3];
                    sprite_valid_<=1;
                end else begin
                    sprite_valid_<=0;
                end
            end else if (elixir0<=8) begin
                if (regs[30]>=elixir0) begin
                    x_<=elixir0*40-40;
                    y_<=0;
                    frame_<=18;
                    sprite_valid_<=1;
                end else begin
                    sprite_valid_<=0;
                end
            end else if (elixir1<=8) begin
                if (regs[31]>=elixir1) begin
                    x_<=elixir1*40-40;
                    y_<=CANVAS_HEIGHT-20;
                    frame_<=18;
                    sprite_valid_<=1;
                end else begin
                    sprite_valid_<=0;
                end
            end
            counter<=counter+1;
            if (counter>2500) begin
                counter<=0;
                if (elixir0<=8) begin
                    elixir0<=elixir0+1;
                end else if (elixir1<8)begin
                    elixir1<=elixir1+1;
                end
                else begin
                    state<=state+1;
                end
            end
        end
        else begin
        // sprite_valid_ <= sprites[state<<3] != 0 && state==0;
            if (sprites[state<<3]>0) begin
        // if (state==0) begin
                x_<=sprites[(state<<3)+1];
                y_<=sprites[(state<<3)+2];
            //   x_<=100;
            //  y_<=500;
                frame_<=sprites[(state<<3)+3];
                sprite_valid_<=1;
            end else begin
                sprite_valid_<=0;
            end
            counter<=counter+1;
            if (counter>2500) begin
            counter<=0;
            state<=state+1;
            end
        end
    end
    else begin
        sprite_valid_<=0;
    end
    if (rst_in) begin
        count<=0;
        nop<=1;
    end else if (nop) begin
            if (nop==1) begin
                wb<=0;
                rb<=0;
                readstage<=1;
                if (rb) begin
                    regs[rd]<=memout;
                end else if (wsprite) begin
                    sprites[(rd<<3)+sindex]<=res;
                end else if (rdvalid) begin
                    regs[rd]<=res;
                end
                count<=count+1;
            end
        nop<=nop-1;
    //READ
    end else if (readstage) begin
        instruction<=oldinstruction;
        readstage<=0;
        case ((count>INSTRUCTIONS_SIZE) ? 0:{oldinstruction[32],oldinstruction[6:0]})
            8'b01101111: begin //JAL
                res<=count;
                rd<=oldinstruction[11:7];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=1;
            end
            8'b01100001: begin //JMP
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=0;
            end
            8'b01100011: begin //branches register BNE BEQ BLT BGE
                r1<=regs[oldinstruction[24:20]];
                r2<=regs[oldinstruction[19:15]];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=0;
            end
            8'b00000011: begin //LW
                r1<=regs[oldinstruction[19:15]];
                r2<=oldinstruction[31:20];
                rd<=oldinstruction[11:7];
                wsprite<=0;
                rdvalid<=1;
            end
            8'b00100011: begin //SW
                r1<=regs[oldinstruction[19:15]];
                r2<=oldinstruction[31:20];
                rd<=oldinstruction[11:7];
                wsprite<=0;
                rdvalid<=0;
            end
            8'b01111111: begin //wait
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=0;
            end
            8'b10110111: begin  //SPLI
                rd<=regs[oldinstruction[11:7]];
                r1<=oldinstruction[31:12];
                rb<=0;
                wb<=0;
                wsprite<=1;
                rdvalid<=0;
            end
            8'b10000001: begin  //SPLREG
                rd<=regs[oldinstruction[16:12]];
                r1<=regs[oldinstruction[11:7]];
                rb<=0;
                wb<=0;
                wsprite<=1;
                rdvalid<=0;
            end
            8'b00110111: begin //LI
                rd<=oldinstruction[11:7];
                r1<=oldinstruction[31:12];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=1;
            end
            8'b10111111: begin //LISP
                rd<=oldinstruction[11:7];
                r1<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[35:33]];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=1;
            end
            8'b10010011: begin // Sprite IMM
                case (instruction[14:12])
                    3'b0:begin //SPADDI
                            rd<=regs[oldinstruction[11:7]];
                            r1<=regs[oldinstruction[19:15]];
                            r2<=oldinstruction[31:20];
                            rb<=0;
                            wb<=0;
                            wsprite<=1;
                            rdvalid<=0;
                        end
                    3'b01: begin //SPSUBI 0 floored
                        rd<=regs[oldinstruction[11:7]];
                            r1<=regs[oldinstruction[19:15]];
                            r2<=oldinstruction[31:20];
                        rb<=0;
                        wb<=0;
                        wsprite<=1;
                        rdvalid<=0;
                    end
                endcase
                
            end
            8'b00010011: begin //REG IMM ADDI SUBI MULTI
                rd<=oldinstruction[11:7];
                r1<=regs[oldinstruction[19:15]];
                r2<=oldinstruction[31:20];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=1;
            end
            8'b10111011: begin //attack
                    rd<=regs[oldinstruction[11:7]];
                    sindex<=oldinstruction[31:29];
                    
                    r1<=sprites[(regs[oldinstruction[11:7]]<<3)+oldinstruction[31:29]];
                    r2<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[28:26]];
                    rb<=0;
                    wb<=0;
                    wsprite<=1;
                    rdvalid<=0;
                end
            8'b11111111: begin //dist
                    rd<=oldinstruction[11:7];
                    r1<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[35:33]];
                    r2<=sprites[(regs[oldinstruction[24:20]]<<3)+oldinstruction[35:33]];
                    r3<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[31:29]];
                    r4<=sprites[(regs[oldinstruction[24:20]]<<3)+oldinstruction[31:29]];
                    rb<=0;
                    wb<=0;
                    wsprite<=0;
                    rdvalid<=1;
                    // regs[instruction[11:7]]<=(sprites[instruction[18:13]][instruction[35:33]]>=sprites[instruction[24:19]][instruction[35:33]]?
                    //                             sprites[instruction[18:13]][instruction[35:33]]-sprites[instruction[24:19]][instruction[35:33]]:
                    //                             sprites[instruction[24:19]][instruction[35:33]]-sprites[instruction[18:13]][instruction[35:33]])+
                    //                             (sprites[18:13][31:29]>=sprites[24:19][31:29]]?
                    //                             sprites[18:13][31:29]-sprites[24:19][31:29]]:
                    //                             sprites[24:19][31:29]-sprites[18:13][31:29]]);
                    // res<=(((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])>=
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]) ? 
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])-
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]):
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]])-
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])
                        
                    //     ) +
                    //     (((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])>=
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]) ? 
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])-
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]):
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]])-
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])
                    //     );
             //       jmp<=0;
                  //  rdvalid<=1;
         //           rb<=0;
           //         wb<=0;
                end
            8'b10110011: begin //SPSUB SPADD ADDSP SUBSP
                val<=oldinstruction[31:25];
                case (oldinstruction[31:25]) 
                7'b0100000: begin //SPSUB (destination is sprite)
                    
                    rd<=regs[oldinstruction[11:7]];
                    sindex<=oldinstruction[35:33];
                    r1<=sprites[(regs[oldinstruction[11:7]]<<3)+oldinstruction[35:33]];
                    r2<=regs[oldinstruction[19:15]];
                    rb<=0;
                    wb<=0;
                    wsprite<=1;
                    rdvalid<=0;
                end
                7'b0100001: begin //SUBSP (destination is register)
                    rd<=oldinstruction[11:7];
                    r1<=regs[oldinstruction[11:7]];
                    r2<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[35:33]];
                    rb<=0;
                    wb<=0;
                    wsprite<=0;
                    rdvalid<=1;
                end
                7'b0000001: begin //ADDSP (destination is register)
                    rd<=oldinstruction[11:7];
                    r1<=regs[oldinstruction[11:7]];
                    r2<=sprites[(regs[oldinstruction[19:15]]<<3)+oldinstruction[35:33]];
                    rb<=0;
                    wb<=0;
                    wsprite<=0;
                    rdvalid<=1;
                end
                7'b0: begin //SPADD (desination is sprite)
                    rd<=regs[oldinstruction[11:7]];
                    sindex<=oldinstruction[35:33];
                    r1<=sprites[(regs[oldinstruction[11:7]]<<3)+oldinstruction[35:33]];
                    r2<=regs[oldinstruction[19:15]];
                    rb<=0;
                    wb<=0;
                    wsprite<=1;
                    rdvalid<=0;
                end
                endcase
            end
            8'b00110011: begin //SUB ADD MULT SLL ABS
                rd<=oldinstruction[11:7];
                    
                r1<=regs[oldinstruction[19:15]];
                r2<=regs[oldinstruction[24:20]];
                rb<=0;
                wb<=0;
                wsprite<=0;
                rdvalid<=1;
            end
            default: begin //if everything is done
                rd<=0;
                rb<=0;
                wb<=0;
            end
        endcase
    end else begin
        case ((count>INSTRUCTIONS_SIZE) ? 0:{instruction[32],instruction[6:0]})
            
            8'b01101111: begin //JAL
                count<=instruction[31:12];
                nop<=2;
            end
            8'b01100001: begin //JMP
                count<=instruction[31:7];
                nop<=2;
            end
            8'b01100011: begin //branches register
                case (instruction[14:12])
                3'b000: begin //BEQ
                    if (r1==r2) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end else begin
                        readstage<=1;
                        count<=count+1;
                    end
                end
                3'b001: begin //BNE
                    if (r1!=r2) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    else begin
                        count<=count+1;
                        readstage<=1;
                    end
                end
                3'b101: begin //BGE
                    if (r1>=r2) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    else begin
                        count<=count+1;
                        readstage<=1;
                    end
                end
                //BLT
                3'b100: begin
                    if (r1<r2) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    else begin
                        count<=count+1;
                        readstage<=1;
                    end
                end
                endcase
            end
            8'b00000011: begin //LW
                res<=r1+r2;
                nop<=3;
                rb<=1;
                wb<=0;
            end
            8'b00100011: begin //SW
                res<=r1+r2;
                write<=regs[instruction[11:7]];
                nop<=3;
                rb<=0;
                wb<=1;
            end
            8'b01111111: begin //wait
                rb<=0;
                wb<=0;
                count<=count;
                nop<=instruction[31:7];
            end
            8'b10110111: begin  //SPLI
                res<=r1;
                nop<=1;
                sindex<=instruction[35:33];
            end
            8'b10000001: begin  //SPLREG
                res<=r1;
                nop<=1;
                sindex<=instruction[35:33];
            end
            8'b00110111: begin //LI
                res<=r1;
                nop<=1;
            end
            8'b10111111: begin //LISP
                res<=r1;
                nop<=1;
            end
            8'b10010011: begin // Sprite IMM
                case (instruction[14:12])
                    3'b0:begin //SPADDI
                            res<=r1+r2;
                            sindex<=instruction[35:33];
                            nop<=1;
                        end
                    3'b01: begin //SPSUBI 0 floored
                        res<=r1>=r2? r1-r2:0;
                        sindex<=instruction[35:33];
                        nop<=1;
                    end
                endcase
                
            end
            8'b00010011: begin //REG IMM
                case (instruction[14:12])
                    3'b0:begin //ADDI
                            nop<=1;
                            res<=r1+r2;
                        end
                    3'b001: begin //SUBI not 0 floored
                        res<=r1>=r2? r1-r2:0;
                        nop<=1;
                    end
                    3'b010:begin //Shift left
                            nop<=1;
                            res<=r1<<r2;
                        end
                    // 3'b011:begin //multi
                    //         nop<=1;
                    //         res<=r1*r2;
                    //     end
                    3'b101:begin //shift right
                            nop<=1;
                            res<=r1>>r2;
                        end
                endcase
            end
            8'b10111011: begin //attack
                    res<=r1>=r2 ? r1-r2:0;
                    nop<=1;
                end
            8'b11111111: begin //dist
                res<=(r1>=r2 ? r1-r2: r2-r1) +(r3>=r4 ? r3-r4: r4-r3);
                nop<=1;
                    // regs[instruction[11:7]]<=(sprites[instruction[18:13]][instruction[35:33]]>=sprites[instruction[24:19]][instruction[35:33]]?
                    //                             sprites[instruction[18:13]][instruction[35:33]]-sprites[instruction[24:19]][instruction[35:33]]:
                    //                             sprites[instruction[24:19]][instruction[35:33]]-sprites[instruction[18:13]][instruction[35:33]])+
                    //                             (sprites[18:13][31:29]>=sprites[24:19][31:29]]?
                    //                             sprites[18:13][31:29]-sprites[24:19][31:29]]:
                    //                             sprites[24:19][31:29]-sprites[18:13][31:29]]);
                    // res<=(((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])>=
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]) ? 
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])-
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]):
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]])-
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])
                        
                    //     ) +
                    //     (((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])>=
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]) ? 
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])-
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]):
                    //     ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]])-
                    //     ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                    //     (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])
                    //     );
             //       jmp<=0;
                  //  rdvalid<=1;
                    rb<=0;
                    wb<=0;
                end
            8'b10110011: begin //SPSUB SPADD ADDSP SUBSP
                case (instruction[31:25]) 
                7'b0100000: begin //SPSUB (destination is sprite)
                    res<=r1>=r2? r1-r2:0;
                    nop<=1;
                end
                7'b0100001: begin //SUBSP (destination is register)
                    res<=r1>=r2? r1-r2:0;
                    nop<=1;
                end
                7'b0000001: begin //ADDSP (destination is register)
                    res<=r1+r2;
                    nop<=1;
                end
                7'b0: begin //SPADD (desination is sprite)
                    res<=r1+r2;
                    nop<=1;
                end
                endcase
            end
            8'b00110011: begin //SUB ADD MULT SLL ABS
                val<=12;
                case (instruction[31:25]) 
                7'b0000001: begin //SUB
                    res<=r1>r2? r1-r2:0;
                    nop<=1;
                end

                7'b0: begin //ADD
                    res<=r1+r2;
                    nop<=1;
                end
                7'b0000010: begin //SLL
                    res<=r1<<r2;
                    nop<=1;
               end
                // 7'b0000011: begin //MULT
                //     res<=r1*r2;
                //     nop<=1;
                // end
                7'b0000100: begin //SRL 
                    res<=r1>>r2;
                    nop<=1;
                end
                7'b0000101: begin //ABS 
                    res<=r1>r2? r1-r2: r2-r1;
                    nop<=1;
                end
                endcase
            end
            default: begin //if everything is done
                rd<=0;
                rb<=0;
                wb<=0;
            end
        endcase
    end
    end
end

 
endmodule






`default_nettype none
