`timescale 1ns / 1ps

// decoder2to4: binary-to-one-hot decoder with an active-high enable.
// When enabled, exactly one bit of y (bit a) is 1; when disabled, y is all
// zero regardless of a.
module decoder2to4 (
    input  wire [1:0] a,
    input  wire       en,
    output wire [3:0] y
);

    assign y = en ? (4'b0001 << a) : 4'b0000;

endmodule
