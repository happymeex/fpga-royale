`timescale 1ns / 1ps
`default_nettype none

module mouse #(
    parameter CANVAS_WIDTH = 360,
    parameter CANVAS_HEIGHT = 720
)(
    input wire clk_in,
    input wire clk_ps2_raw,
    input wire ps2_data,
    input wire rst_in,
    output logic click,
    output logic [$clog2(CANVAS_WIDTH)-1:0] mouse_x,
    output logic [$clog2(CANVAS_HEIGHT)-1:0] mouse_y
);

typedef enum logic [2:0] {
    IDLE,
    DATA,
    PARITY,
    STOP
} State;
typedef enum logic [1:0] { 
    STATUS,
    X_DATA,
    Y_DATA
} ByteType;

logic [10:0] stream;
State state;
ByteType btype;

logic clk_ps2;
logic [7:0] mouse_dx;
logic [7:0] mouse_dy;

synchronizer sync (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .us_in(clk_ps2_raw),
    .s_out(clk_ps2)
);

logic prev_clk_ps2;
logic neg_ps2_edge;
assign neg_ps2_edge = {prev_clk_ps2, clk_ps2} == 2'b10;
logic [3:0] num_data_bits;

logic sign_x;
logic sign_y;

// combinationally calculate this
logic [$clog2(CANVAS_WIDTH)-1:0] new_mouse_x;
logic [$clog2(CANVAS_HEIGHT)-1:0] new_mouse_y;

logic [7:0] data;
assign data = stream[9:2];

always_comb begin
    if (sign_x) begin
        // negative delta
        if (data > mouse_x) new_mouse_x = 0;
        else new_mouse_x = mouse_x - data;
    end else begin
        if (data + mouse_x >= CANVAS_WIDTH) new_mouse_x = CANVAS_WIDTH - 1;
        else new_mouse_x = data + mouse_x;
    end
    if (sign_y) begin
        // negative delta
        if (data > mouse_y) new_mouse_y = 0;
        else new_mouse_y = mouse_y - data;
    end else begin
        if (data + mouse_y >= CANVAS_WIDTH) new_mouse_y = CANVAS_WIDTH - 1;
        else new_mouse_y = data + mouse_y;
    end
end

always_ff @(posedge clk_in) begin
    prev_clk_ps2 <= clk_ps2;
    if (rst_in) begin
        mouse_dx <= 0;
        mouse_dy <= 0;
        mouse_x <= 0;
        mouse_y <= 0;
        click <= 0;
        sign_x <= 0;
        sign_y <= 0;
        state <= IDLE;
        btype <= STATUS;
        num_data_bits <= 0;
    end else if (neg_ps2_edge) begin
        stream <= {ps2_data, stream[10:1]};
        num_data_bits <= (state == DATA) ? num_data_bits + 1 : 4'b0;
        case (state)
            IDLE:
                if (ps2_data == 0) begin
                    state <= DATA;
                end
            DATA:
                if (num_data_bits == 7) begin
                    state <= PARITY;
                end
            PARITY:
                state <= STOP;
            STOP:
                if (btype == Y_DATA) begin
                    state <= IDLE;
                    btype <= STATUS;
                    mouse_dy <= stream[9:2];
                    mouse_y <= new_mouse_y;
                end
                else begin
                    state <= DATA;
                    if (btype == STATUS) begin
                        btype <= X_DATA;
                        click <= stream[2];
                        sign_x <= stream[6];
                        sign_y <= stream[7];
                    end
                    else if (btype == X_DATA) begin
                        btype <= Y_DATA;
                        mouse_dx <= stream[9:2];
                        mouse_x <= new_mouse_x;
                    end
                end
        endcase
    end
end

endmodule

`default_nettype wire