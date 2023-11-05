module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20)
(
  input wire clk_pixel_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out,
  output logic hs_out,
  output logic ad_out,
  output logic nf_out,
  output logic [5:0] fc_out);

  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;
  
  logic just_reset;

  always_ff @( posedge clk_pixel_in ) begin
    if (rst_in) begin
      hcount_out <= 0;
      vcount_out <= 0;
      vs_out <= 0;
      hs_out <= 0;
      ad_out <= 0;
      nf_out <= 0;
      fc_out <= 0;
      just_reset <= 1;
    end else if (just_reset) begin
      just_reset <= 0;
      ad_out <= 1;
    end else begin
      if (hcount_out == TOTAL_PIXELS - 1) begin
        hcount_out <= 0;
        if (vcount_out < ACTIVE_LINES - 1) begin
          ad_out <= 1;
        end else if (vcount_out == ACTIVE_LINES - 1) begin
          ad_out <= 0;
        end else if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH - 1) begin
          vs_out <= 1;
        end else if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH - 1) begin
          vs_out <= 0;
        end else if (vcount_out == TOTAL_LINES - 1) begin
          ad_out <= 1;
        end
        vcount_out <= vcount_out == TOTAL_LINES - 1 ? 0 : vcount_out + 1;
      end else begin
        hcount_out <= hcount_out + 1;
        if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1) begin
        hs_out <= 0;
        end else if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1) begin
          hs_out <= 1;
        end else if (hcount_out == ACTIVE_H_PIXELS - 1) begin
          ad_out <= 0;
        end
      end

      if (hcount_out == ACTIVE_H_PIXELS - 1 && vcount_out == ACTIVE_LINES) begin
        nf_out <= 1;
        fc_out <= fc_out == 59 ? 0 : fc_out + 1;
      end

      if (nf_out) nf_out <= 0;
    end
  end

  //your code here

endmodule
