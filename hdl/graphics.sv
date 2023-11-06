`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module graphics #(
  parameter SPRITE_FRAME_WIDTH = 64, // width and height of single frame
  parameter SPRITE_FRAME_HEIGHT = 64,
  parameter NUM_FRAMES = 512, // total number of frames across all sprites
  parameter WIDTH = 1280,
  parameter HEIGHT = 720
)(
  input wire sys_rst,
  input wire clk_pixel, clk_5x,
  input wire active_draw,
  input wire sprite_valid,
  input wire [$clog2(WIDTH)-1:0] sprite_x,
  input wire [$clog2(HEIGHT)-1:0] sprite_y,
  input wire [$clog2(NUM_FRAMES)-1:0] sprite_frame_number,
  input wire [$clog2(WIDTH)-1:0] hcount,
  input wire [$clog2(HEIGHT)-1:0] vcount,
  input wire vert_sync, hor_sync,
  output logic [2:0] hdmi_tx_p,
  output logic [2:0] hdmi_tx_n,
  output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);

  localparam PIXELS_PER_FRAME = SPRITE_FRAME_WIDTH * SPRITE_FRAME_HEIGHT;
  localparam SPRITE_MEM_DEPTH = NUM_FRAMES * SPRITE_FRAME_WIDTH * SPRITE_FRAME_HEIGHT;
  logic [$clog2(SPRITE_MEM_DEPTH)-1:0] spritesheet_addr;

  logic [7:0] red, green, blue; // values sent to HDMI during drawing period
  logic [31:0] color_out;
  assign red = active_draw ? color_out [31:24] : 0;
  assign blue = active_draw ? color_out[23:16] : 0;
  assign green = active_draw ? color_out[15:8] : 0;

  logic in_sprite = ((hcount >= sprite_x && hcount < (sprite_x + SPRITE_FRAME_WIDTH)) &&
                     (vcount >= sprite_y && vcount < (sprite_y + SPRITE_FRAME_HEIGHT)));

  assign spritesheet_addr = sprite_frame_number * PIXELS_PER_FRAME
    + (hcount - sprite_x) + (vcount - sprite_y) * SPRITE_FRAME_WIDTH;

  logic [31:0] color_read;
  //logic transparent_pixel;
  //logic reading;
  //assign transparent_pixel = ~color_read[0]
  //always_ff @(posedge clk_pixel) begin
  //  if (active_draw) begin
  //    //
  //  end else begin
  //    // buffer period: read from sprite mem and write to frame mem
  //    if (sprite_valid && ~reading) begin
  //      spritesheet_addr <= sprite_frame_number * PIXELS_PER_FRAME;
  //      reading <= 1;
  //    end else if (sprite_valid) begin
  //      spritesheet_addr <= spritesheet_addr + 1;
  //    end
  //  end
  //end

  assign color_out = color_read; // temporary: for testing

  // BROM containing spritesheet
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(32),                       // ROM data width: R,B,G,A
    .RAM_DEPTH(SPRITE_MEM_DEPTH),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(spritesheet.mem))
  ) sprite_mem (
    .addra(spritesheet_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(),
    .clka(clk_pixel),
    .wea(1'b0),         // writing disabled
    .ena(1'b1),         // RAM Enable, for additional power savings, consider disabling during active draw
    .rsta(sys_rst),       // Output reset (does not affect memory contents)
    .regcea(1'b1),   // Output register enable
    .douta(color_read)      // RAM output data, width determined from RAM_WIDTH
  );

  // BRAM for upcoming frame, hidden for now (testing)
  //xilinx_single_port_ram_read_first #(
  //  .RAM_WIDTH(32),                       // RAM data width: R,G,B,A
  //  .RAM_DEPTH(WIDTH * HEIGHT),
  //  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  //  .INIT_FILE()
  //) frame_mem (
  //  .addra(),     // Address bus, width determined from RAM_DEPTH
  //  .dina(color_read),       // RAM input data, width determined from RAM_WIDTH
  //  .clka(clk_pixel),
  //  .wea(~active_draw),         // writing
  //  .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
  //  .rsta(sys_rst),       // Output reset (does not affect memory contents)
  //  .regcea(1'b1),   // Output register enable
  //  .douta(color_out)      // RAM output data, width determined from RAM_WIDTH
  //);

  // HDMI protocol

  logic tmds_signal [2:0];
  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!

  //three tmds_encoders (blue, green, red)
  //blue should have {vert_sync and hor_sync for control signals)
  //red and green have nothing
  tmds_encoder tmds_red(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(red),
    .control_in(2'b0),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[2]));
  tmds_encoder tmds_green(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(green),
    .control_in(2'b0),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[1]));
  tmds_encoder tmds_blue(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(blue),
    .control_in({vert_sync,hor_sync}),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[0]));
  //four tmds_serializers (blue, green, red, and clock)
  tmds_serializer red_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[2]),
    .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[1]),
    .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[0]),
    .tmds_out(tmds_signal[0]));

  //output buffers generating differential signal:
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
endmodule

`default_nettype wire