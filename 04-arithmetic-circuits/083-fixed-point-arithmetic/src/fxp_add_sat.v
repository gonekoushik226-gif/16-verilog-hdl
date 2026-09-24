`timescale 1ns / 1ps

// fxp_add_sat: saturating fixed-point add. Both operands share the same
// Qm.FRAC format (signed WIDTH-bit raw code, real value = code /
// 2^FRAC), so adding the raw codes directly adds the real values
// exactly — no rescaling needed, unlike multiplication. The only issue
// is that the true sum may not fit back in WIDTH bits, so the result is
// clamped ("saturated") to the format's representable range instead of
// wrapping.
module fxp_add_sat #(
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

    // one extra bit of headroom is always enough to hold the exact sum
    // of two WIDTH-bit signed values with no overflow at this width.
    wire signed [WIDTH:0] ext = {a[WIDTH-1], a} + {b[WIDTH-1], b};

    // the sum fits back in WIDTH bits iff its sign bit and what would be
    // bit WIDTH-1 after truncation agree (pure sign-extension, nothing
    // lost); they disagree exactly when saturation is required.
    assign overflow = (ext[WIDTH] != ext[WIDTH-1]);
    assign result    = overflow ? (ext[WIDTH] ? MINV : MAXV) : ext[WIDTH-1:0];

endmodule
