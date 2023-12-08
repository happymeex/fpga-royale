`timescale 1ns / 1ps
`default_nettype none

module mouse_iface #(
    parameter CANVAS_WIDTH = 360,
    parameter CANVAS_HEIGHT = 720
)(
    input wire clk_in,
    input wire ps2_clk,
    input wire ps2_data,
    input wire rst_in,
    output logic click,
    output logic [$clog2(CANVAS_WIDTH)-1:0] mouse_x,
    output logic [$clog2(CANVAS_HEIGHT)-1:0] mouse_y
);

logic bitRead;
logic bitWrite;
logic bitErr;
logic [7:0] vecRxData;
logic [7:0] TX_DATA;

logic [4:0] counter;
logic [9:0] bound;
logic setmax_x, setmax_y;
initial begin
    counter = 0;
    bound = CANVAS_WIDTH;
    setmax_x = 1;
    setmax_y = 0;
end
always_ff @(posedge clk_in) begin
    if (counter < 30) begin
        counter <= counter + 1;
        if (counter == 15) begin
            bound <= CANVAS_HEIGHT;
            setmax_x <= 0;
            setmax_y <= 1;
        end
    end else if (counter == 30) begin
        counter <= counter + 1;
        setmax_y <= 0;
    end
end

mouse_controller mctrl (
    .clk(clk_in),
    .rst(rst_in),
    .read(bitRead),
    .write(bitWrite),
    .err(bitErr),
    .setmax_x(setmax_x),
    .setmax_y(setmax_y),
    .setx(),
    .sety(),
    .value(bound),
    .rx_data(vecRxData[7:0]),
    .tx_data(TX_DATA[7:0]),
    .left(click),
    .middle(),
    .right(),
    .xpos(mouse_x),
    .ypos(mouse_y),
    .zpos(),
    .new_event()
);

ps2interface p2i (
    .clk(clk_in),
    .rst(rst_in),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .tx_data(TX_DATA),
    .write(bitWrite),
    .rx_data(vecRxData),
    .read(bitRead),
    .busy(),
    .err(bitErr)
);


endmodule

`default_nettype wire