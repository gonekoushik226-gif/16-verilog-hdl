`timescale 1ns / 1ps

// full_adder: two half adders plus an OR gate, the textbook construction.
// The first half adder sums a and b; the second adds cin to that partial
// sum. Either partial-sum stage can produce a carry, and at most one of
// them ever does for a given input combination, so carry_out is their OR.
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire carry_out
);

    wire sum1, carry1, carry2;

    half_adder ha1 (.a(a),    .b(b), .sum(sum1), .carry(carry1));
    half_adder ha2 (.a(sum1), .b(cin), .sum(sum), .carry(carry2));

    assign carry_out = carry1 | carry2;

endmodule
