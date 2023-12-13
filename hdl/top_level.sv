`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz,
  input wire [3:0] btn,
  inout wire [7:0] pmodb,
  inout wire [7:0] pmoda,
  input wire [15:0] sw, //all 16 input slide switches
  output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
	output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
	output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
	output logic [6:0] ss1_c, //cathod controls for the segments of lower four digits
  output logic [2:0] hdmi_tx_p,
  output logic [2:0] hdmi_tx_n,
  output logic hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
  input wire uart_rxd
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
  assign sys_rst = btn[2];
  logic buf_clk;
  BUFG bu (
    .I(clk_100mhz),
    .O(buf_clk)
  );

  logic clk_pixel, clk_5x;
  hdmi_clk_wiz_720p mhdmicw (.clk_pixel(clk_pixel),.clk_tmds(clk_5x),
          .reset(0), .locked(locked), .clk_ref(buf_clk));
  
  localparam NUM_FRAMES = 24;
  localparam CANVAS_HEIGHT = 720;
  localparam CANVAS_WIDTH = 360;
  localparam PALETTE_SIZE = 16;

  logic sprite_valid;
  logic [$clog2(NUM_FRAMES)-1:0] sprite_frame;
  logic [$clog2(CANVAS_WIDTH)-1:0] sprite_x;
  logic [$clog2(CANVAS_HEIGHT)-1:0] sprite_y;
  logic [$clog2(CANVAS_WIDTH)-1:0] mouse_x_a[1:0];
  logic [$clog2(CANVAS_HEIGHT)-1:0] mouse_y_a[1:0];
  logic click_a[1:0];
  logic ps2_clk_a;
  logic ps2_data_a;
  assign ps2_clk_a = pmoda[2];
  assign ps2_data_a = pmoda[0];
  logic [$clog2(CANVAS_WIDTH)-1:0] mouse_x_b[1:0];
  logic [$clog2(CANVAS_HEIGHT)-1:0] mouse_y_b[1:0];
  logic click_b[1:0];
  logic ps2_clk_b;
  logic ps2_data_b;
  assign ps2_clk_b = pmodb[2];
  assign ps2_data_b = pmodb[0];
  logic [7:0] hp00,
  logic [7:0] hp01,
  logic [7:0] hp10,
  logic [7:0] hp11,
  logic [6:0] ss_c;
  // logic test_clk;
  // initial test_clk = 1;
  // always_ff @( posedge buf_clk ) begin
  //   if (ps2_clk_a == 0) test_clk <= 0;
  // end
  logic [31:0]val_in;
  assign val_in<={hp00,hp01,hp10,hp11};
  seven_segment_controller mssc(.clk_in(buf_clk),
                                  .rst_in(sys_rst),
                                  .val_in(val_in),
                                  .cat_out(ss_c),
                                  .an_out({ss0_an, ss1_an}));
  //assign ss0_c = ss_c; //control upper four digit's cathodes!
//  assign ss1_c = ss_c; //same as above but for lower four digits!

  singleprocessor #(
    .CANVAS_HEIGHT(CANVAS_HEIGHT),
    .CANVAS_WIDTH(CANVAS_WIDTH),
    .NUM_FRAMES(NUM_FRAMES),
    .INSTRUCTIONS_SIZE(800),
    .MAX_SPRITES(64),
    .MEMORY_SIZE(320),
    .INSTRUCTION_WIDTH(36),
    .ROW_SIZE(1280) // not used for now
  ) pr (
    .pixel_clk_in(clk_pixel),
    .rst_in(sys_rst),
    .new_frame(new_frame),
    .x(sprite_x),
    .y(sprite_y),
    .frame(sprite_frame),
    .sprite_valid(sprite_valid),
    .mouse1x(mouse_x_a[1]),
    .mouse1y(mouse_y_a[1]),
    .isClicked1(click_a[1]),
    .mouse2x(mouse_x_b[1]),
    .mouse2y(mouse_y_b[1]),
    .isClicked2(click_b[1]),
    .isOn(sw[0]),
    .uart_rx_in(uart_rxd),
    .go(btn[3]),
    .hp00(hp00),
    .hp01(hp01),
    .hp10(hp10),
    .hp11(hp11)
  );
  
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

  // logic [2:0] frame_number;

  graphics #(
    .SPRITE_FRAME_WIDTH(48), // testing
    .SPRITE_FRAME_HEIGHT(48),
    .NUM_FRAMES(NUM_FRAMES),
    .PALETTE_SIZE(PALETTE_SIZE),
    .TRANSPARENT_COLOR_INDEX(3)
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
    .sprite_valid(sprite_valid),
    .sprite_x(sprite_x),
    .sprite_y(sprite_y),
    .sprite_frame_number(sprite_frame),
    .sprite_ready(),
    .hdmi_tx_p(hdmi_tx_p),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_clk_p(hdmi_clk_p),
    .hdmi_clk_n(hdmi_clk_n)
  );

mouse_iface #(
  .CANVAS_WIDTH(CANVAS_WIDTH),
  .CANVAS_HEIGHT(CANVAS_HEIGHT)
) ms_a (
  .clk_in(buf_clk),
  .ps2_clk(ps2_clk_a),
  .rst_in(sys_rst),
  .ps2_data(ps2_data_a),
  .mouse_x(mouse_x_a[0]),
  .mouse_y(mouse_y_a[0]),
  .click(click_a[0])
);

mouse_iface #(
  .CANVAS_WIDTH(CANVAS_WIDTH),
  .CANVAS_HEIGHT(CANVAS_HEIGHT)
) ms_b (
  .clk_in(buf_clk),
  .ps2_clk(ps2_clk_b),
  .rst_in(sys_rst),
  .ps2_data(ps2_data_b),
  .mouse_x(mouse_x_b[0]),
  .mouse_y(mouse_y_b[0]),
  .click(click_b[0])
);
// logic [3:0] counter;
// logic [5:0] prev_frame_count;
// logic forward_wag;
 always_ff @(posedge clk_pixel) begin
    mouse_x_a[1]<=mouse_x_a[0];
    mouse_y_a[1]<=mouse_y_a[0];
    mouse_x_b[1]<=mouse_x_b[0];
    mouse_y_b[1]<=mouse_y_b[0];
    click_a[1]<=click_a[0];
    click_b[1]<=click_b[0];
 end
//   prev_frame_count <= frame_count;
//   if (frame_count != prev_frame_count) begin
//     if (counter == 11) begin
//       counter <= 0;
//       if (frame_number >= 4) begin
//         forward_wag <= 0;
//         frame_number <= frame_number - 1;
//       end else if (frame_number == 0) begin
//         forward_wag <= 1;
//         frame_number <= frame_number + 1;
//       end else begin
//         if (forward_wag) frame_number <= frame_number + 1;
//         else frame_number <= frame_number - 1;
//       end
//     end else begin
//       counter <= counter + 1;
//     end
//   end
// end

endmodule

`default_nettype wire