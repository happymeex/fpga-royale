`timescale 1ns / 1ps
`default_nettype none

module mouse_tb;

    localparam CANVAS_WIDTH = 360;
    localparam CANVAS_HEIGHT = 720;

    logic clk_in;
    logic clk_ps2_raw;
    logic ps2_data;
    logic rst_in;
    logic click;
    
    logic [$clog2(CANVAS_WIDTH)-1:0] mouse_x;
    logic [$clog2(CANVAS_HEIGHT)-1:0] mouse_y;

    always begin
        #5;
        clk_in = !clk_in;
    end

    always begin
        #500;
        clk_ps2_raw = !clk_ps2_raw;
    end

    mouse ms (
        .clk_in(clk_in),
        .clk_ps2_raw(clk_ps2_raw),
        .ps2_data(ps2_data),
        .rst_in(rst_in),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .click(click)
    );

    initial begin
        $dumpfile("mouse.vcd");
        $dumpvars(0, mouse_tb);
        $display("Starting mouse sim");
        clk_in = 0;
        clk_ps2_raw = 0;
        rst_in = 0;
        ps2_data = 1;
        #10;
        rst_in = 1;
        #10;
        rst_in = 0;
        #10;
        ps2_data = 0;
        #1000;
        // click low, both signs positive
        for (int i = 0; i < 8; i++) begin
            ps2_data = 0;
            #1000;
        end
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit
        #1000;
        ps2_data = 0; // start bit
        ps2_data = 0; #1000; ps2_data = 1; #1000;
        ps2_data = 0; #1000; ps2_data = 1; #1000;
        ps2_data = 0; #1000; ps2_data = 1; #1000;
        ps2_data = 0; #1000; ps2_data = 1; #1000;
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit
        #1000;
        ps2_data = 0; // start bit
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit, idle
        #3000;

        // second packet;
        ps2_data = 0;
        #1000;
        // sign_x positive, sign_y negative, click is high
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 0; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 0; #1000;
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit
        #1000;
        ps2_data = 0; // start bit
        // x_delta 256, should cap at 359
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit
        #1000;
        ps2_data = 0; // start bit
        // y_delta 256, should bottom out at 0
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; #1000; ps2_data = 1; #1000;
        ps2_data = 1; // parity bit
        #1000;
        ps2_data = 1; // stop bit, idle
        #3000;
        $display("Finishing mouse sim");
        $finish;
    end

endmodule

`default_nettype wire