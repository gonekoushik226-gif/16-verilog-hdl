`timescale 1ns / 1ps

// fxp_mul: rounding, saturating fixed-point multiply. Multiplying two
// Qm.FRAC raw codes gives a raw product scaled by 2^(2*FRAC), not
// 2^FRAC, so it must be rescaled back down by FRAC bits before it is a
// valid Qm.FRAC code again. That rescale is a real right-shift (loses
// information), so this module rounds — adding a half-ULP bias
// (2^(FRAC-1)) before an arithmetic (sign-preserving) shift implements
// round-half-up — before saturating the result into WIDTH bits.
module fxp_mul #(
    parameter WIDTH = 8,
    parameter FRAC  = 4
) (
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] result,
    output wire                     overflow
);

    localparam signed [WIDTH-1:0] MAXV = {1'b0, {(WIDTH-1){1'b1}}};
    localparam signed [WIDTH-1:0] MINV = {1'b1, {(WIDTH-1){1'b0}}};

    wire signed [2*WIDTH-1:0] full_product = a * b;                     // exact, scale 2^(2*FRAC)
    wire signed [2*WIDTH-1:0] rounded      = full_product + (1 <<< (FRAC-1));
    wire signed [2*WIDTH-1:0] shifted      = rounded >>> FRAC;          // back to scale 2^FRAC

    wire signed [2*WIDTH-1:0] maxv_ext = {{WIDTH{1'b0}}, MAXV};
    wire signed [2*WIDTH-1:0] minv_ext = {{WIDTH{1'b1}}, MINV};

    assign overflow = (shifted > maxv_ext) || (shifted < minv_ext);
    assign result    = overflow ? (shifted[2*WIDTH-1] ? MINV : MAXV) : shifted[WIDTH-1:0];

endmodule
