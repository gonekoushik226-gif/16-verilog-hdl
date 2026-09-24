`timescale 1ns / 1ps

// fp_unpack: decodes one IEEE-754 single-precision word into sign,
// biased exponent, and a 24-bit significand with the implicit leading 1
// restored (for normal numbers) or an all-zero significand (for zero).
// This design's documented scope is normal numbers and zero only (see
// fp_adder.v's header for the full limitation list).
module fp_unpack (
    input  wire [31:0] in,
    output wire         sign,
    output wire [7:0]   exp,
    output wire [23:0]  mant,
    output wire         is_zero
);

    assign sign    = in[31];
    assign exp     = in[30:23];
    assign is_zero = (in[30:0] == 31'b0);
    assign mant    = is_zero ? 24'b0 : {1'b1, in[22:0]};

endmodule
