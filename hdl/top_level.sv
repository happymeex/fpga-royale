`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz;
);
  //signals related to driving the video pipeline
  logic [10:0] hcount;
  logic [9:0] vcount;
  logic vert_sync;
  logic hor_sync;
  logic active_draw;
  logic new_frame;
  logic [5:0] frame_count;

  logic clk_pixel, clk_5x;
  hdmi_clk_wiz_720p mhdmicw (.clk_pixel(clk_pixel),.clk_tmds(clk_5x),
          .reset(0), .locked(locked), .clk_ref(clk_100mhz));
  
  video_sig_gen mvg(
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount),
      .vcount_out(vcount),
      .vs_out(vert_sync),
      .hs_out(hor_sync),
      .ad_out(active_draw),
      .nf_out(new_frame),
      .fc_out(frame_count)
  );

  graphics gr(
    .clk_pixel(clk_pixel),
    .clk_5x(clk_5x),
    .hcount(hcount),
    .vcount(vcount)
  );
endmodule

`default_nettype wire