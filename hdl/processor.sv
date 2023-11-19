`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module processor #( parameter CANVAS_WIDTH,parameter CANVAS_HEIGHT, parameter NUM_FRAMES,
  parameter INSTRUCTIONS_SIZE, parameter MAX_SPRITES, parameter MEMORY_SIZE, parameter INSTRUCTION_WIDTH, parameter ROW_SIZE) (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire new_frame,
  output wire[$clog2(CANVAS_WIDTH)-1:0] x,
  output wire [$clog2(CANVAS_HEIGHT)-1:0] y,
  output wire [$clog2(NUM_FRAMES)-1:0] frame,
  output wire sprite_valid
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
  
  logic [31:0] regs[31:0];
  logic[6:0] state;
  initial state=0;
  
  //elixir count
  logic [3:0] elixir;
  //all sprites
  logic[31:0] sprites[63:0][7:0];
  initial begin
    for (int i = 0 ; i < 64; i++) begin
        sprites[i][0] = 0;
    end
  end
  logic [31:0] count;
  logic done;
  logic [INSTRUCTION_WIDTH-1:0] instruction;
  logic [2:0] nop;
  logic[31:0] val;
  initial nop=1;
  initial count=0;
  initial done=0;
  //DECODER/ALU
  logic jmp;
  logic [31:0] res;
  logic [5:0] rd;
  logic [31:0] write;
  logic rdvalid;
  logic rb;
  logic wb;
  logic [6:0] instr;
  initial rb=0;
  initial wb=0;
  initial rdvalid=0;
  initial jmp=0;
  logic sprite;
  logic[2:0] sindex;
  //MEM
  logic spritem;
  logic[2:0] sindexm;
  logic [5:0] rdm;
  logic [31:0] resm;
  logic [31:0]memout;
  logic rdmvalid;
  logic routem;//whether resm should be routed from memory
  initial routem=0;
  initial rdmvalid=0;
  logic jmpm;
  initial jmpm=0;
  //memory
   xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(32),                       // Specify RAM data width
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
    .INIT_FILE(`FPATH(instructions.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) instructions (
    .addra(count),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(instruction)      // RAM output data, width determined from RAM_WIDTH
  );
always_ff @(posedge pixel_clk_in) begin
    if(new_frame) begin
        state<=0;
    end
    if (state<64) begin
        sprite_valid_ <= sprites[state][0] > 0;
        if (sprites[state][0]>0) begin
            x_<=sprites[state][1];
            y_<=sprites[state][2];
            frame_<=sprites[state][3];
        end
        state<=state+1;
    end
    if (rst_in) begin
        count<=0;
    end else if (nop) begin
            if (nop==1) begin
            // if (rb | wb) begin
                count<=count+1;
        //         resm<=memout;
            //  end
            end
    //    else begin
            //   nop<=0;
    //        rb<=0;
        //      wb<=0;
        //  end
        nop<=nop-1;
    end else begin
        count<=count+1;
        case ((count>INSTRUCTIONS_SIZE && !jmp) ? 0:{instruction[32],instruction[6:0]})

            8'b01100111: begin //JALR
                res<=instruction[31:20]+((rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                rd<=instruction[11:7];
                jmp<=1;
                rdvalid<=1;
                rb<=1;
                wb<=0;
                nop<=2;
                sprite<=0;
            end
            8'b01100001: begin //JMP
                res<=instruction[31:7];
                jmp<=1;
                rdvalid<=0;
                rb<=0;
                wb<=0;
                sprite<=0;
            end
            8'b01100011: begin //branches register
                case (instruction[14:12])
                3'b000: begin //BEQ
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])==
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        instr<=((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                        val<=((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                3'b001: begin //BNE
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])!=
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                3'b101: begin //BGE
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])>=
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                //BLT
                3'b100: begin
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                            (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])<
                            ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                            (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                                res<={instruction[31:25],instruction[11:7]};
                                jmp<=1;
                        end
                        else begin
                            res<= 0;
                            jmp<=0;
                        end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                endcase
            end
            8'b11100011: begin //branches sprite NOT DONE
                case (instruction[13:12])
                3'b000: begin //SPBEQ
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])==
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        instr<=((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                        val<=((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                3'b001: begin //SPBNE
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])!=
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                3'b101: begin //SPBGE
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])>=
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                            res<={instruction[31:25],instruction[11:7]};
                            jmp<=1;
                    end
                    else begin
                        res<= 0;
                        jmp<=0;
                    end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                //SPBLT
                3'b100: begin
                    if (((!sprite && rdvalid && rd==instruction[24:20]) ?  (rb ? memout : res):
                            (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])<
                            ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                            (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin //take it
                                res<={instruction[31:25],instruction[11:7]};
                                jmp<=1;
                        end
                        else begin
                            res<= 0;
                            jmp<=0;
                        end
                    rdvalid<=0;
                    rb<=0;
                    wb<=0;
                    sprite<=0;
                end
                endcase
            end
            8'b10000011: begin //SPLW
                res<=instruction[31:20]+((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                rd<=instruction[12:7];
                jmp<=0;
                rdvalid<=1;
                rb<=1;
                wb<=0;
                count<=count;
                nop<=2;
                sprite<=1;
                sindex<=instruction[35:33];
            end
            8'b00000011: begin //LW
                res<=instruction[31:20]+((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                rd<=instruction[11:7];
                jmp<=0;
                rdvalid<=1;
                rb<=1;
                wb<=0;
                count<=count;
                nop<=2;
                sprite<=0;
            end
            8'b10100011: begin //SPSW
                res<=instruction[31:20]+((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                rd<=instruction[12:7];
                jmp<=0;
                rdvalid<=0;
                rb<=0;
                wb<=1;
                write<=((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[12:7] && sindexm==instruction[35:33]) 
                        ? resm : sprites[instruction[12:7]][instruction[35:33]]);
                count<=count;
                nop<=2;
                sprite<=1;
                sindex<=instruction[35:33];
            end
            8'b00100011: begin //SW
                res<=instruction[31:20]+((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                jmp<=0;
                rdvalid<=0;
                rb<=0;
                write<=((!sprite && rdvalid && rd==instruction[11:7]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[11:7]) ? resm : regs[instruction[11:7]]);
                wb<=1;
                count<=count;
                nop<=2;
                sprite<=0;
            end
            8'b10110111: begin  //SPLI
                res<=instruction[31:13];
                rd <=instruction[12:7];
                jmp<=0;
                rdvalid<=1;
                rb<=0;
                wb<=0;
                sprite<=1;
                sindex<=instruction[35:33];
            end
            8'b00110111: begin //LI
                res<=instruction[31:12];
                rd <=instruction[11:7];
                jmp<=0;
                rdvalid<=1;
                rb<=0;
                wb<=0;
                sprite<=0;
            end
            8'b10111111: begin //LISP
                res<= ((sprite && rdvalid && rd==instruction[19:14] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[19:14]&& sindexm==instruction[35:33])
                            ? resm : sprites[instruction[19:14]][instruction[35:33]]);
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                
            end
            8'b10010011: begin // Sprite IMM
                case (instruction[14:13])
                    3'b0:begin //SPADDI
                            if (!sprite && rdvalid && rd==instruction[19:15]) begin
                                res<=(rb ? memout : res)+instruction[31:20];
                            end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                                instr<=2;
                                res<=resm+instruction[31:20];
                            end else begin
                                
                                val<=instruction[31:20];
                                res<=regs[instruction[19:15]]+instruction[31:20];
                            end
                            jmp<=0;
                            rdvalid<=1;
                            rb<=0;
                            wb<=0;
                            rd <=instruction[12:7];
                            sprite<=1;
                            sindex<=instruction[35:33];
                        end
                    3'b01: begin //SUBI not 0 floored
                        if (!sprite && rdvalid && rd==instruction[19:15]) begin
                            res<=(rb ? memout : res)-instruction[31:20];
                        end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                            res<=resm-instruction[31:20];
                        end else begin
                            res<=regs[instruction[19:15]]-instruction[31:20];
                        end
                        jmp<=0;
                        rdvalid<=1;
                        rb<=0;
                        wb<=0;
                        rd <=instruction[12:7];
                        sprite<=1;
                        sindex<=instruction[35:33];
                    end
                endcase
                
            end
            8'b00010011: begin //REG IMM
                case (instruction[14:12])
                    3'b0:begin //ADDI
                            if (!sprite && rdvalid && rd==instruction[19:15]) begin
                                res<=(rb ? memout : res)+instruction[31:20];
                            end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                                res<=resm+instruction[31:20];
                            end else begin
                                
                                val<=instruction[31:20];
                                res<=regs[instruction[19:15]]+instruction[31:20];
                            end
                            jmp<=0;
                            rdvalid<=1;
                            rb<=0;
                            wb<=0;
                            rd <=instruction[11:7];
                            sprite<=0;
                        end
                    3'b001: begin //SUBI not 0 floored
                        if (!sprite && rdvalid && rd==instruction[19:15]) begin
                            res<=(rb ? memout : res)-instruction[31:20];
                        end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                            res<=resm-instruction[31:20];
                        end else begin
                            res<=regs[instruction[19:15]]-instruction[31:20];
                        end
                        jmp<=0;
                        rdvalid<=1;
                        rb<=0;
                        wb<=0;
                        rd <=instruction[11:7];
                        sprite<=0;
                    end
                    3'b010:begin //Shift left
                            if (!sprite && rdvalid && rd==instruction[19:15]) begin
                                res<=(rb ? memout : res)>>instruction[31:20];
                            end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                                res<=resm>>instruction[31:20];
                            end else begin
                                
                                val<=instruction[31:20];
                                res<=regs[instruction[19:15]]>>instruction[31:20];
                            end
                            jmp<=0;
                            rdvalid<=1;
                            rb<=0;
                            wb<=0;
                            rd <=instruction[11:7];
                            sprite<=0;
                        end
                    3'b011:begin //mult
                            if (!sprite && rdvalid && rd==instruction[19:15]) begin
                                res<=(rb ? memout : res)*instruction[31:20];
                            end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                                res<=resm*instruction[31:20];
                            end else begin
                                
                                val<=instruction[31:20];
                                res<=regs[instruction[19:15]]*instruction[31:20];
                            end
                            jmp<=0;
                            rdvalid<=1;
                            rb<=0;
                            wb<=0;
                            rd <=instruction[11:7];
                            sprite<=0;
                        end
                    3'b101:begin //shift right
                            if (!sprite && rdvalid && rd==instruction[19:15]) begin
                                res<=(rb ? memout : res)<<instruction[31:20];
                            end else if (!spritem && rdmvalid && rdm==instruction[19:15]) begin
                                res<=resm<<instruction[31:20];
                            end else begin
                                
                                val<=instruction[31:20];
                                res<=regs[instruction[19:15]]<<instruction[31:20];
                            end
                            jmp<=0;
                            rdvalid<=1;
                            rb<=0;
                            wb<=0;
                            rd <=instruction[11:7];
                            sprite<=0;
                        end
                endcase
            end
            8'b10111011: begin //attack
                    if (((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[12:7] && sindexm==instruction[31:29]) ? resm : sprites[instruction[12:7]][instruction[31:29]])<
                        ((sprite && rdvalid && rd==instruction[19:14] && sindex==instruction[28:26]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[19:14] && sindexm==instruction[28:26]) ? resm : sprites[instruction[19:14]][instruction[28:26]])) begin
                            res<=0;
                    end
                    else begin
                        res<= ((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[31:29]) ? (rb ? memout : res):
                                (spritem && rdmvalid && rdm==instruction[12:7] && sindexm==instruction[31:29]) ? resm : sprites[instruction[12:7]][instruction[31:29]])
                                - ((sprite && rdvalid && rd==instruction[19:14] && sindex==instruction[28:26]) ? (rb ? memout : res):
                                (spritem && rdmvalid && rdm==instruction[19:14] && sindex==instruction[28:26]) ? resm : sprites[instruction[19:14]][instruction[28:26]]);
                    end
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[12:7];
                    sprite<=1;
                    sindex<=instruction[31:29];
                end
            8'b11111111: begin //dist
                    res<=(((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])>=
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]) ? 
                        ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])-
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]]):
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[35:33]) ? resm : sprites[instruction[24:19]][instruction[35:33]])-
                        ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[35:33]) ? resm : sprites[instruction[18:13]][instruction[35:33]])
                        
                        ) +
                        (((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])>=
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]) ? 
                        ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])-
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]]):
                        ((sprite && rdvalid && rd==instruction[24:19] && sindex==instruction[31:29]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[24:19] && sindexm==instruction[31:29]) ? resm : sprites[instruction[24:19]][instruction[31:29]])-
                        ((sprite && rdvalid && rd==instruction[18:13] && sindex==instruction[31:29]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[18:13] && sindexm==instruction[31:29]) ? resm : sprites[instruction[18:13]][instruction[31:29]])
                        );
                    instr<=rdm;
                    val<=spritem;
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
            8'b10110011: begin //SPSUB SPADD ADDSP SUBSP
                case (instruction[31:25]) 
                7'b0100000: begin //SPSUB (destination is sprite)
                    if (((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[35:33]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[12:7] && sindexm==instruction[35:33]) ? resm : sprites[instruction[12:7]][instruction[35:33]])<
                        ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])) begin
                            res<=0;
                    end
                    else begin
                        res<= ((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[35:33]) ? (rb ? memout : res):
                                (spritem && rdmvalid && rdm==instruction[12:7] && sindexm==instruction[35:33]) ? resm : sprites[instruction[12:7]][instruction[35:33]])
                                - ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                                (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                    end
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[12:7];
                    sprite<=1;
                    sindex<=instruction[35:33];
                end
                7'b0100001: begin //SUBSP (destination is register)
                    if (((!sprite && rdvalid && rd==instruction[11:7]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[11:7]) ? resm : regs[instruction[11:7]])<
                        ((sprite && rdvalid && rd==instruction[19:14]&& sindex==instruction[35:33]) ?  (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[19:14] && sindexm==instruction[35:33]) ? resm : sprites[instruction[19:14]][instruction[35:33]])
                        ) begin
                            res<=0;
                    end
                    else begin
                        res<= ((!sprite && rdvalid && rd==instruction[11:7]) ? (rb ? memout : res):
                                (!spritem && rdmvalid && rdm==instruction[11:7]) ? resm : regs[instruction[11:7]])
                            -((sprite && rdvalid && rd==instruction[19:14] && sindex==instruction[35:33]) ? (rb ? memout : res):
                                (spritem && rdmvalid && rdm==instruction[19:14] && sindexm==instruction[35:33]) ? resm : sprites[instruction[19:14]][instruction[35:33]]);
                    end
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                7'b0000001: begin //ADDSP (destination is register)
                    res<= ((sprite && rdvalid && rd==instruction[19:14] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[19:14]&& sindexm==instruction[35:33]) ? resm : sprites[instruction[19:14]][instruction[35:33]])
                        + ((!sprite && rdvalid && rd==instruction[11:7]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[11:7]) ? resm : regs[instruction[11:7]]);
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                7'b0: begin //SPADD (desination is sprite)
                    res<= ((sprite && rdvalid && rd==instruction[12:7] && sindex==instruction[35:33]) ? (rb ? memout : res):
                        (spritem && rdmvalid && rdm==instruction[12:7]&& sindexm==instruction[35:33]) ? resm : sprites[instruction[12:7]][instruction[35:33]])
                        + ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]]);
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[12:7];
                    sprite<=1;
                    sindex<=instruction[35:33];
                end
                endcase
            end
            8'b00110011: begin //SUB ADD MULT SLL 
                val<=12;
                case (instruction[31:25]) 
                7'b0000001: begin //SUB
                    if (((!sprite && rdvalid && rd==instruction[19:15]) ?  (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])<
                        ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]])) begin
                            res<=0;
                    end
                    else begin
                        res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                                (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                                - ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                                (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                    end
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end

                7'b0: begin //ADD
                    res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                        + ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                7'b0000010: begin //SLL
                    res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                        << ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                    jmp<=0;
                    instr<=1;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                7'b0000011: begin //MULT
                    res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                        * ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                    jmp<=0;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                7'b0000100: begin //SRL
                    res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                        >> ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                        (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                    jmp<=0;
                    instr<=2;
                    rdvalid<=1;
                    rb<=0;
                    wb<=0;
                    rd <=instruction[11:7];
                    sprite<=0;
                end
                endcase
            end
            default: begin //if everything is done
                rd<=0;
                val<={instruction[32],instruction[6:0]};
                rb<=0;
                wb<=0;
                jmp<=0;
                rdvalid<=0;
                sprite<=0;
            end
        endcase
        //Mem
        rdmvalid<=rdvalid;
        spritem<=sprite;
        if (rdvalid) begin
            if (sprite) begin
                sindexm<=sindex;
            end
            rdm<=rd;
            if (!rb) begin
                resm<=res;
            end else begin
                resm<=memout;
            end
        end
        if (jmp) begin
            
            if (!rb) begin
                count<=res;
                rd<=0;
                
            end else begin
                count<=memout;
                resm<=memout+1; //link register to nxt instructino
            end
            jmp<=0;
            rb<=0;    
            nop<=2;
            rd<=0;
            wb<=0;
            rdvalid<=0;
        end
        //Writeback
        if (rdmvalid) begin
            if (spritem) begin
                sprites[rdm][sindexm]<=resm;
            end
            else begin
                regs[rdm]<=resm;
            end
        end
        
    end
end

 
endmodule






`default_nettype none
