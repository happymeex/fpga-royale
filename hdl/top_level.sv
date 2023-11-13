`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  output logic [2:0] hdmi_tx_p,
  output logic [2:0] hdmi_tx_n,
  output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
);
  //signals related to driving the video pipeline
  logic [10:0] hcount;
  logic [9:0] vcount;
  logic vert_sync;
  logic hor_sync;
  logic active_draw;
  logic new_frame;
  logic [5:0] frame_count;

  logic locked; // unused
  logic sys_rst;
  assign sys_rst = 0;

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

  logic [2:0] frame_number;

  graphics #(
    .SPRITE_FRAME_WIDTH(192), // testing
    .SPRITE_FRAME_HEIGHT(128),
    .NUM_FRAMES(5)
  ) gr(
    .sys_rst(sys_rst),
    .clk_pixel(clk_pixel),
    .clk_5x(clk_5x),
    .frame_count(frame_count),
    .active_draw(active_draw),
    .hcount(hcount),
    .vcount(vcount),
    .vert_sync(vert_sync),
    .hor_sync(hor_sync),
    .sprite_valid(1),
    .sprite_x(100),
    .sprite_y(200),
    .sprite_frame_number(frame_number),
    .sprite_ready(),
    .hdmi_tx_p(hdmi_tx_p),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_clk_p(hdmi_clk_p),
    .hdmi_clk_n(hdmi_clk_n)
  );

logic [3:0] counter;
logic [5:0] prev_frame_count;
logic forward_wag;
always_ff @(posedge clk_pixel) begin
  prev_frame_count <= frame_count;
  if (frame_count != prev_frame_count) begin
    if (counter == 11) begin
      counter <= 0;
      if (frame_number >= 4) begin
        forward_wag <= 0;
        frame_number <= frame_number - 1;
      end else if (frame_number == 0) begin
        forward_wag <= 1;
        frame_number <= frame_number + 1;
      end else begin
        if (forward_wag) frame_number <= frame_number + 1;
        else frame_number <= frame_number - 1;
      end
    end else begin
      counter <= counter + 1;
    end
  end
end

endmodule

`default_nettype wire