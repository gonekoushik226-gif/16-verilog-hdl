`timescale 1ns / 1ps

// majority_gate_level: 3-input majority function y = ab + bc + ac,
// written with structural gate-level primitives and named intermediate
// nets — the lowest level of abstraction Verilog offers.
module majority_gate_level (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    wire ab, bc, ac;

    and (ab, a, b);
    and (bc, b, c);
    and (ac, a, c);
    or  (y, ab, bc, ac);

endmodule
