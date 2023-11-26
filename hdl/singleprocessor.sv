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
  logic [31:0] nop;
  logic[31:0] val;
  initial nop=1;
  initial count=0;
  initial done=0;
  logic [31:0] res;
  logic [5:0] rd;
  logic [31:0] write;
  logic rb;
  logic wb;
  logic [6:0] instr;
  initial rb=0;
  initial wb=0;
  logic [31:0]memout;
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
                wb<=0;
                rb<=0;
                if (rb) begin
                    regs[rd]<=memout;
                end;
                count<=count+1;
            end
        nop<=nop-1;
    end else begin
        count<=count+1;
        case ((count>INSTRUCTIONS_SIZE) ? 0:{instruction[32],instruction[6:0]})

            8'b01101111: begin //JAL
                count<=instruction[31:12];
                nop<=2;
                regs[instruction[11:7]]<=count;
                rd<=instruction[11:7];
                rb<=0;
                wb<=0;
            end
            8'b01100001: begin //JMP
                count<=instruction[31:7];
                nop<=2;
                rb<=0;
                wb<=0;
            end
            8'b01100011: begin //branches register
                case (instruction[14:12])
                3'b000: begin //BEQ
                    if (regs[instruction[24:20]]==regs[instruction[19:15]]) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end

                    rb<=0;
                    wb<=0;
                end
                3'b001: begin //BNE
                    if (regs[instruction[24:20]]!=regs[instruction[19:15]]) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    rb<=0;
                    wb<=0;
                end
                3'b101: begin //BGE
                    if (regs[instruction[24:20]]>=regs[instruction[19:15]]) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    rb<=0;
                    wb<=0;
                end
                //BLT
                3'b100: begin
                    if (regs[instruction[24:20]]<regs[instruction[19:15]]) begin
                        count<={instruction[31:25],instruction[11:7]};
                        nop<=2;
                    end
                    rb<=0;
                    wb<=0;
                end
                endcase
            end
            // 8'b00000011: begin //LW
            //     res<=instruction[31:20]+regs[instruction[19:15]];
            //     rd<=instruction[11:7];
            //     rb<=1;
            //     wb<=0;
            //     count<=count;
            //     nop<=3;
            // end
            // 8'b00100011: begin //SW
            //     res<=instruction[31:20]+regs[instruction[19:15]];
            //     rb<=0;
            //     write<=regs[instruction[11:7]];
            //     wb<=1;
            //     count<=count;
            //     nop<=3;
            // end
            8'b01111111: begin //wait
                rb<=0;
                wb<=0;
                count<=count;
                nop<=instruction[31:7];
            end
            8'b10110111: begin  //SPLI
                sprites[instruction[12:7]][instruction[35:33]]<=instruction[31:13];
                rb<=0;
                wb<=0;
            end
            8'b10000001: begin  //SPLREG
                sprites[instruction[17:12]][instruction[35:33]]<=regs[instruction[11:7]];
                rb<=0;
                wb<=0;
            end
            8'b00110111: begin //LI
                regs[instruction[11:7]]<=instruction[31:12];
                rb<=0;
                wb<=0;
            end
            8'b10111111: begin //LISP
                regs[instruction[11:7]]<=sprites[instruction[19:14]][instruction[35:33]];
                    rb<=0;
                    wb<=0;
                
            end
            // 8'b10010011: begin // Sprite IMM
            //     case (instruction[14:13])
            //         3'b0:begin //SPADDI
            //                 sprites[instruction[12:7]][instruction[35:33]]<=regs[instruction[19:15]]+instruction[31:20];
            //                 rb<=0;
            //                 wb<=0;
            //             end
            //         3'b01: begin //SPSUBI 0 floored
            //             sprites[instruction[12:7]][instruction[35:33]]<=regs[instruction[19:15]]>=instruction[31:20]?
            //                     regs[instruction[19:15]]-instruction[31:20]:0;
            //             rb<=0;
            //             wb<=0;
            //         end
            //     endcase
                
            // end
            8'b00010011: begin //REG IMM
                case (instruction[14:12])
                    3'b0:begin //ADDI
                            regs[instruction[11:7]]<=regs[instruction[19:15]]+instruction[31:20];
                            rb<=0;
                            wb<=0;
                        end
                    3'b001: begin //SUBI not 0 floored
                        regs[instruction[11:7]]<=regs[instruction[19:15]]>=instruction[31:20] ? 
                                                regs[instruction[19:15]]>=instruction[31:20]:0;
                        rb<=0;
                        wb<=0;
                    end
                    3'b010:begin //Shift left
                            regs[instruction[11:7]]<=regs[instruction[19:15]]<<instruction[31:20];
                            rb<=0;
                            wb<=0;
                        end
                    // 3'b011:begin //mult
                    //         regs[instruction[11:7]]<=regs[instruction[19:15]]*instruction[31:20];
                    //         rb<=0;
                    //         wb<=0;
                    //     end
                    3'b101:begin //shift right
                            regs[instruction[11:7]]<=regs[instruction[19:15]]>>instruction[31:20];
                            rb<=0;
                            wb<=0;
                        end
                endcase
            end
            8'b10111011: begin //attack
                    sprites[instruction[12:7]][instruction[31:29]]<=
                        sprites[instruction[12:7]][instruction[31:29]]>=sprites[instruction[19:14]][instruction[28:26]]?
                        sprites[instruction[12:7]][instruction[31:29]]-sprites[instruction[19:14]][instruction[28:26]]:0;
                    rb<=0;
                    wb<=0;
                end
            8'b11111111: begin //dist
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
            // 8'b10110011: begin //SPSUB SPADD ADDSP SUBSP
            //     case (instruction[31:25]) 
            //     7'b0100000: begin //SPSUB (destination is sprite)
            //         sprites[instruction[12:7]][instruction[35:33]]<=sprites[instruction[12:7]][instruction[35:33]]>=regs[instruction[19:15]]?
            //                                                     sprites[instruction[12:7]][instruction[35:33]]-regs[instruction[19:15]]:0;
            //         rb<=0;
            //         wb<=0;
            //     end
            //     // 7'b0100001: begin //SUBSP (destination is register)
            //     // regs[instruction[11:7]]<=regs[instruction[11:7]]>=sprites[instruction[19:14]][instruction[35:33]]?
            //     //                                                 regs[instruction[11:7]]-sprites[instruction[19:14]][instruction[35:33]]:0;
            //     //     rb<=0;
            //     //     wb<=0;
            //     // end
            //     // 7'b0000001: begin //ADDSP (destination is register)
            //     //     regs[instruction[11:7]]<=
            //     //                                                 sprites[instruction[19:14]][instruction[35:33]]+regs[instruction[11:7]];
            //     //     rb<=0;
            //     //     wb<=0;
            //     // end
            //     7'b0: begin //SPADD (desination is sprite)
            //         sprites[instruction[12:7]][instruction[35:33]]<=
            //                                                     sprites[instruction[12:7]][instruction[35:33]]+regs[instruction[19:15]];
            //         rb<=0;
            //         wb<=0;
            //     end
            //     endcase
            // end
            8'b00110011: begin //SUB ADD MULT SLL 
                val<=12;
                case (instruction[31:25]) 
                7'b0000001: begin //SUB
                    regs[instruction[11:7]]<=regs[instruction[19:15]]>=regs[instruction[24:20]] ? 
                                                regs[instruction[19:15]]-regs[instruction[24:20]]:0;
                    rb<=0;
                    wb<=0;
                end

                7'b0: begin //ADD
                    regs[instruction[11:7]]<=regs[instruction[19:15]]+regs[instruction[24:20]];
                    rb<=0;
                    wb<=0;
                end
                // 7'b0000010: begin //SLL NOT DONE
                //     res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                //         << ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                //     jmp<=0;
                //     instr<=1;
                //     rdvalid<=1;
                //     rb<=0;
                //     wb<=0;
                // //    rd <=instruction[11:7];
              //      sprite<=0;
           //     end
                // 7'b0000011: begin //MULT NOT DONE
                //     res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                //         * ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                //     jmp<=0;
                //     rdvalid<=1;
                //     rb<=0;
                //     wb<=0;
                //     rd <=instruction[11:7];
                //     sprite<=0;
                // end
                // 7'b0000100: begin //SRL NOT DONE
                //     res<= ((!sprite && rdvalid && rd==instruction[19:15]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[19:15]) ? resm : regs[instruction[19:15]])
                //         >> ((!sprite && rdvalid && rd==instruction[24:20]) ? (rb ? memout : res):
                //         (!spritem && rdmvalid && rdm==instruction[24:20]) ? resm : regs[instruction[24:20]]);
                //     jmp<=0;
                //     instr<=2;
                //     rdvalid<=1;
                //     rb<=0;
                //     wb<=0;
                //     rd <=instruction[11:7];
                //     sprite<=0;
                // end
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

 
endmodule






`default_nettype none
