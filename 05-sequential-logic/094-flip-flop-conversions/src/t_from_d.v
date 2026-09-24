`timescale 1ns / 1ps

// t_from_d: realizes T (toggle) flip-flop behavior using an internal D
// flip-flop and the T-to-D excitation equation D = T XOR Q (hold q when
// t=0 by feeding q back to itself; invert it when t=1).
module t_from_d (
    input  wire clk,
    input  wire rst_n,
    input  wire t,
    output wire q
);

    wire d_excitation = t ^ q;

    d_ff core (.clk(clk), .rst_n(rst_n), .d(d_excitation), .q(q));

endmodule
