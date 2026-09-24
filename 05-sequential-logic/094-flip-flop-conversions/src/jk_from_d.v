`timescale 1ns / 1ps

// jk_from_d: realizes JK flip-flop behavior using an internal D flip-
// flop and the JK-to-D excitation equation. The excitation table asks
// "what D input, given the current state q, produces the JK
// characteristic table's next state?" for each of the 4 (j,k) cases;
// solving it gives D = J.~Q + ~K.Q, which is exactly what is wired
// into the internal d_ff's data input below.
module jk_from_d (
    input  wire clk,
    input  wire rst_n,
    input  wire j,
    input  wire k,
    output wire q
);

    wire d_excitation = (j & ~q) | (~k & q);

    d_ff core (.clk(clk), .rst_n(rst_n), .d(d_excitation), .q(q));

endmodule
