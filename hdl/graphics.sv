`timescale 1ns / 1ps
`default_nettype none

module graphics ();

  logic tmds_signal [2:0];
  logic hdmi_tx_p;
  logic hdmi_tx_n;
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