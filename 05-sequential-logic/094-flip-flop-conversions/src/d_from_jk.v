`timescale 1ns / 1ps

// d_from_jk: the inverse direction from jk_from_d.v -- rather than
// building JK behavior from a D flip-flop, this computes the D-to-JK
// excitation (the (j,k) values a JK flip-flop would need in order to
// reach the same next state as a plain D flip-flop with data input d)
// and feeds them into a JK-style update built the same way jk_from_d.v
// does. The D-to-JK excitation table is simply j=d, k=~d, independent
// of the current state. Composing the two excitation equations
// algebraically confirms they are exact inverses of each other:
// substituting j=d, k=~d into jk_from_d's D = j.~q + ~k.q gives
// D = d.~q + d.q = d.(~q+q) = d -- i.e. this module's output is
// provably identical to a plain d_ff's, which this program's testbench
// verifies directly.
module d_from_jk (
    input  wire clk,
    input  wire rst_n,
    input  wire d,
    output wire q
);

    wire j = d;
    wire k = ~d;

    wire d_excitation = (j & ~q) | (~k & q);

    d_ff core (.clk(clk), .rst_n(rst_n), .d(d_excitation), .q(q));

endmodule
