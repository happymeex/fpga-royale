module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );
    
  integer num_ones;
  assign num_ones = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
  
  always_comb begin
    qm_out[0] = data_in[0];
    if (num_ones > 4 || ((num_ones == 4) && ~data_in[0])) begin
      for (integer i = 1; i < 8; i++) begin
        qm_out[i] = ~(qm_out[i-1] ^ data_in[i]);
      end
      qm_out[8] = 0;
    end else begin
      for (integer i = 1; i < 8; i++) begin
        qm_out[i] = qm_out[i-1] ^ data_in[i];
      end
      qm_out[8] = 1;
    end
  end

endmodule //end tm_choice