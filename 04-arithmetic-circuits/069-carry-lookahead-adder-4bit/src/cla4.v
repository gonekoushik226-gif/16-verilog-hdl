`timescale 1ns / 1ps

// cla4: 4-bit carry-lookahead adder. Instead of rippling the carry
// through each stage (program 064), every internal carry bit is computed
// directly from the generate/propagate signals of all lower bits, so the
// adder's delay depends on the depth of the lookahead equations rather
// than growing linearly with the number of stages, at the cost of wider
// gates for the higher carry bits.
module cla4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       carry_out
);

    wire [3:0] p = a ^ b;   // bit propagate: this stage passes an incoming carry through
    wire [3:0] g = a & b;   // bit generate: this stage creates a carry on its own

    wire c0 = cin;
    wire c1 = g[0] | (p[0] & c0);
    wire c2 = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c0);
    wire c3 = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c0);
    wire c4 = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0])
              | (p[3] & p[2] & p[1] & p[0] & c0);

    assign sum       = p ^ {c3, c2, c1, c0};
    assign carry_out = c4;

endmodule
