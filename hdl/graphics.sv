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
  parameter NUM_FRAMES = 18, // total number of frames across all sprites
  parameter WIDTH = 1280,
  parameter HEIGHT = 720,
  parameter CANVAS_WIDTH = 360,
  parameter CANVAS_HEIGHT = 720,
  parameter PALETTE_SIZE = 8
)(
  input wire sys_rst,
  input wire clk_pixel, clk_5x,
  input wire active_draw,
  input wire [5:0] frame_count,
  input wire sprite_valid,
  input wire [$clog2(CANVAS_WIDTH)-1:0] sprite_x,
  input wire [$clog2(CANVAS_HEIGHT)-1:0] sprite_y,
  input wire [$clog2(NUM_FRAMES)-1:0] sprite_frame_number,
  input wire [$clog2(WIDTH)-1:0] hcount,
  input wire [$clog2(HEIGHT)-1:0] vcount,
  input wire vert_sync, hor_sync,
  output logic sprite_ready, // high when ready to receive sprite info for next frame
  output logic [2:0] hdmi_tx_p,
  output logic [2:0] hdmi_tx_n,
  output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);

  localparam PIXELS_PER_FRAME = SPRITE_FRAME_WIDTH * SPRITE_FRAME_HEIGHT;
  localparam SPRITE_MEM_DEPTH = NUM_FRAMES * SPRITE_FRAME_WIDTH * SPRITE_FRAME_HEIGHT;
  localparam PALETTE_WIDTH = $clog2(PALETTE_SIZE);
  localparam CANVAS_PIXELS = CANVAS_WIDTH * CANVAS_HEIGHT;
  logic [$clog2(SPRITE_MEM_DEPTH)-1:0] spritesheet_addr;

  logic [PALETTE_WIDTH-1:0] read_color_index; // written to frame storage
  logic [PALETTE_WIDTH-1:0] color_index_1; // used to index output color
  logic [PALETTE_WIDTH-1:0] color_index_2; // used to index output color

  logic reading; // high when graphics module is reading from spritesheet
  logic write_mem_1; // high when frame storage 1 is written to as storage for next frame
  logic write_mem_2 = ~write_mem_1;

  logic in_canvas = hcount < CANVAS_WIDTH && vcount < CANVAS_HEIGHT;
  logic [$clog2(CANVAS_PIXELS)-1:0] output_index; // row-major order index of current (hcount, vcount)
  assign output_index = in_canvas ? hcount + CANVAS_WIDTH * vcount : 0;
  logic in_water;
  localparam WATER_Y_MIN = CANVAS_HEIGHT / 2 - 20;
  localparam WATER_Y_MAX = CANVAS_HEIGHT / 2 + 20;
  localparam WATER_X_MIN = 90;
  localparam WATER_X_MAX = CANVAS_WIDTH - 90;
  assign in_water = hcount < WATER_X_MAX && hcount > WATER_X_MIN
                   && vcount < WATER_Y_MAX && vcount > WATER_Y_MIN;
  logic in_banner; // grey bars for holding troop card UI
  localparam BANNER_TOP_Y_MIN = 20;
  localparam BANNER_TOP_Y_MAX = 20 + SPRITE_FRAME_HEIGHT;
  localparam BANNER_BOTTOM_Y_MIN = CANVAS_HEIGHT - 20 - SPRITE_FRAME_HEIGHT;
  localparam BANNER_BOTTOM_Y_MAX = CANVAS_HEIGHT - 20;
  assign in_banner = (vcount > BANNER_TOP_Y_MIN && vcount < BANNER_TOP_Y_MAX)
                    || (vcount > BANNER_BOTTOM_Y_MIN && vcount < BANNER_TOP_Y_MAX);

  logic [7:0] red, green, blue; // values sent to HDMI during drawing period
  logic [23:0] color_out;
  logic draw = active_draw && in_canvas;
  assign red = draw ? color_out[23:16] : 0;
  assign green = draw ? color_out[15:8] : 0;
  assign blue = draw ? color_out[7:0] : 0;

  // BROM containing spritesheet
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PALETTE_WIDTH),
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
    .douta(read_color_index)
  );

  // BROM containing palette
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24), // RGB
    .RAM_DEPTH(PALETTE_SIZE),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(palette.mem))
  ) palette_mem (
    .addra(write_mem_1 ? color_index_2 : color_index_1),     //
    .dina(),
    .clka(clk_pixel),
    .wea(1'b0),         // writing disabled
    .ena(1'b1),         // RAM Enable, for additional power savings, consider disabling during active draw
    .rsta(sys_rst),       // Output reset (does not affect memory contents)
    .regcea(1'b1),   // Output register enable
    .douta(color_out)      // RAM output data, width determined from RAM_WIDTH
  );


  // Two BRAMs for frame storage. During any given frame, one is written to,
  // the other is read from; switch roles in next frame.

  logic [$clog2(CANVAS_PIXELS)-1:0] frame_loc_ptr; // pointer for writing palette value to frame storage
  logic [$clog2(CANVAS_WIDTH):0] frame_x;
  logic [$clog2(CANVAS_HEIGHT):0] frame_y;
  assign frame_loc_ptr = frame_y * CANVAS_WIDTH + frame_x; // row major order
  logic in_range;
  assign in_range = frame_x < CANVAS_WIDTH && frame_y < CANVAS_HEIGHT;

  logic is_transparent = read_color_index == 0; // true if current pixel being read from spritesheet is transparent

  logic wea1;
  assign wea1 = write_mem_1 && reading && !is_transparent && in_range || !write_mem_1;
  logic [PALETTE_WIDTH-1:0] dina1;
  always_comb begin
    if (write_mem_1 && reading) dina1 = read_color_index;
    else if (in_banner) dina1 = PALETTE_SIZE - 3;
    else if (in_water) dina1 = PALETTE_SIZE - 2;
    else dina1 = PALETTE_SIZE - 1;
  end
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PALETTE_WIDTH),
    .RAM_DEPTH(CANVAS_PIXELS),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()
  ) frame_mem_1 (
    .addra(write_mem_1 ? frame_loc_ptr : output_index),
    .dina(dina1),       // RAM input data, width determined from RAM_WIDTH
    .clka(clk_pixel),
    .wea(wea1),
    .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(sys_rst),       // Output reset (does not affect memory contents)
    .regcea(1'b1),   // Output register enable
    .douta(color_index_1)      // RAM output data, width determined from RAM_WIDTH
  );

  logic wea2;
  assign wea2 = write_mem_2 && reading && !is_transparent && in_range || !write_mem_2;
  logic [PALETTE_WIDTH-1:0] dina2;
  always_comb begin
    if (write_mem_2 && reading) dina2 = read_color_index;
    else dina2 = PALETTE_SIZE - 1;
  end
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PALETTE_WIDTH),
    .RAM_DEPTH(CANVAS_PIXELS),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()
  ) frame_mem_2 (
    .addra(write_mem_2 ? frame_loc_ptr : output_index),
    .dina(dina2),       //
    .clka(clk_pixel),
    .wea(wea2),         // writing
    .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(sys_rst),       // Output reset (does not affect memory contents)
    .regcea(1'b1),   // Output register enable
    .douta(color_index_2)      // RAM output data, width determined from RAM_WIDTH
  );

  // the good stuff oh yeAH mhm
  logic [5:0] prev_frame_count;
  logic [$clog2(CANVAS_WIDTH)-1:0] store_sprite_x;
  logic [$clog2(CANVAS_HEIGHT)-1:0] store_sprite_y;
  always_ff @(posedge clk_pixel) begin
    prev_frame_count <= frame_count;
    if (frame_count != prev_frame_count) begin
      write_mem_1 <= ~write_mem_1; // swap
    end
    if (reading) begin
      //
      if (frame_x == store_sprite_x + SPRITE_FRAME_WIDTH - 1 && frame_y == store_sprite_y + SPRITE_FRAME_HEIGHT - 1) begin
        // stop reading
        sprite_ready <= 1;
        reading <= 0;
      end else begin
        if (frame_x == store_sprite_x + SPRITE_FRAME_WIDTH - 1) begin
          // move down a row
          frame_x <= store_sprite_x;
          frame_y <= frame_y + 1;
        end else begin
          frame_x <= frame_x + 1;
        end
        spritesheet_addr <= spritesheet_addr + 1;
      end
    end else begin
      if (sprite_valid) begin
        reading <= 1;
        sprite_ready <= 0;
        frame_x <= sprite_x;
        frame_y <= sprite_y;
        store_sprite_x <= sprite_x;
        store_sprite_y <= sprite_y;
        spritesheet_addr <= sprite_frame_number * PIXELS_PER_FRAME;
      end
    end
  end

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