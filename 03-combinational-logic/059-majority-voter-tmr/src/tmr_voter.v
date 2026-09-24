`timescale 1ns / 1ps

// tmr_voter: triple-modular-redundancy majority voter. Three independent
// copies (a, b, c) of the same WIDTH-bit signal are combined bit-by-bit
// with a 2-of-3 majority function, masking any single copy's fault; a
// disagree flag reports whenever the three copies were not identical,
// even when the vote itself still produced the correct majority result.
module tmr_voter #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    output wire [WIDTH-1:0] voted,
    output wire              disagree
);

    // per-bit 2-of-3 majority: 1 whenever at least two of the three
    // corresponding bits agree on 1
    assign voted = (a & b) | (b & c) | (a & c);

    // any bit position where the three copies are not all identical
    assign disagree = |((a ^ b) | (b ^ c) | (a ^ c));

endmodule
