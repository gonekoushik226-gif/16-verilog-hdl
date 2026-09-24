`timescale 1ns / 1ps

// pg_cell: per-bit propagate/generate cell, the atomic unit every level
// of a carry-lookahead adder is built from.
module pg_cell (
    input  wire a,
    input  wire b,
    output wire p,   // propagate: this bit passes an incoming carry through
    output wire g    // generate: this bit creates a carry on its own
);

    assign p = a ^ b;
    assign g = a & b;

endmodule
