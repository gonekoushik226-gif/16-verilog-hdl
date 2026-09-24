`timescale 1ns / 1ps

// csa_layer: a bit-sliced array of WIDTH independent full adders (a
// "3:2 compressor" — three input bits in, a sum bit and a carry bit
// out) with *no* connection between bits. Each full adder here uses
// x[i], y[i], z[i] all as same-weight inputs (not a[i],b[i],cin from a
// chain), so no carry ripples between bit positions — the carries are
// "saved" as a whole separate output vector instead of being resolved
// immediately, which is what lets three operands be reduced to two
// (sum, carry) in a single gate delay regardless of width.
module csa_layer #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire [WIDTH-1:0] z,
    output wire [WIDTH-1:0] sum,     // bitwise x^y^z, not yet carry-resolved
    output wire [WIDTH-1:0] carry    // bitwise majority(x,y,z), still at its own bit weight
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bitslice
            full_adder fa (.a(x[i]), .b(y[i]), .cin(z[i]),
                            .sum(sum[i]), .carry_out(carry[i]));
        end
    endgenerate

endmodule
