//Kosinw helped with this tool to use for faster testing of programs
`timescale 1ns / 1ps
`default_nettype none
module ram_bridge_rx (
    input wire pixel_clk_in,
    input wire [7:0] data_in,
    input wire valid_in,
    output logic [31:0] addr,
    output logic [35:0] data_out,
    output logic valid_out
);
    initial addr = 0;
    initial data_out = 0;
    initial valid_out = 0;
    logic [8:0] [7:0]buffer;
    logic state;
    logic [3:0] counter;

    always_ff @(posedge clk_in) begin
        if (state == 0) begin
            addr <= 0;
            data_out <= 0;
            valid_out <= 0;
            counter <= 0;
            if (valid_in) begin
                if (data_in == "W")     state <= 1;
            end
        end else if (valid_in) begin
            buffer[counter] <= data_in;
            counter <= counter + 1;

            if (counter == 9) begin
                state <= 0;

                addr<= {buffer[3],buffer[2],buffer[1],buffer[0]};
                data_out <= {buffer[8],buffer[7],buffer[6],buffer[5],buffer[4]};
                valid_out <= 1'b1;
                counter <= 0;
            end else begin
                addr <= 0;
                data_out <= 0;
                valid_out <= 0;
            end
        end
    end

endmodule

`default_nettype wire