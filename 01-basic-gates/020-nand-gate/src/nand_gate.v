`timescale 1ns / 1ps

// nand_gate: 2-input NAND gate, the complement of AND.
// y is 0 only when both a and b are 1 (De Morgan: ~(a&b) == ~a | ~b).
module nand_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = ~(a & b);

endmodule
