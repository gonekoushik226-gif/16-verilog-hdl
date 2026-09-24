`timescale 1ns / 1ps

// func_minimized: the K-map-minimized form of the same function.
//
// K-map for f(a,b,c) = Sum m(0,2,5,7), rows=a, cols=bc (Gray order 00,01,11,10):
//         bc=00  bc=01  bc=11  bc=10
//   a=0:    1      0      0      1
//   a=1:    0      1      1      0
//
// m0/m2 (a=0, c=0, b either) group into a'c'.
// m5/m7 (a=1, c=1, b either) group into a c.
// f = a'c' + ac = XNOR(a, c) — b never affects the result and drops out
// entirely, which is exactly what the minimization step is meant to find.
module func_minimized (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    // b is kept in the port list so this module can be driven and
    // compared like-for-like against func_sop/func_pos, but the
    // minimized equation provably never reads it (see the derivation
    // above) — Verilator's lint pass reports this as an unused-input
    // warning, which is the expected, correct observation, not a bug.
    assign y = ~(a ^ c);

endmodule
