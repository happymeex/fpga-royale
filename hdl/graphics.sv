`timescale 1ns / 1ps
`default_nettype none

module graphics (
  input wire sys_rst,
  input wire clk_pixel, clk_5x,
  input wire active_draw,
  input wire sprite_valid,
  input wire [9:0] sprite_x,
  input wire [10:0] sprite_y,
  input wire [3:0] sprite_frame_number,
  input wire [9:0] hcount,
  input wire [10:0] vcount,
  input wire vert_sync, hor_sync,
  output logic [2:0] hdmi_tx_p,
  output logic [2:0] hdmi_tx_n,
  output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);

  logic [7:0] red, green, blue;

  // TODO: logic for retrieving R,G,B

  //  Xilinx Single Port Read First RAM (BROM containing spritesheet)
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                       // ROM data width
    .RAM_DEPTH(1024),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(spritesheet.mem))
  ) sprite_mem (
    .addra(),     // Address bus, width determined from RAM_DEPTH
    .dina(),       // RAM input data, width determined from RAM_WIDTH
    .clka(clk_pixel),       // Clock
    .wea(1'b0),         // writing disabled
    .ena(1'b1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(sys_rst),       // Output reset (does not affect memory contents)
    .regcea(1'b1),   // Output register enable
    .douta()      // RAM output data, width determined from RAM_WIDTH
  );

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