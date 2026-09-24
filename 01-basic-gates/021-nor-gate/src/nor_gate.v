`timescale 1ns / 1ps

// nor_gate: 2-input NOR gate, the complement of OR.
// y is 1 only when both a and b are 0 (De Morgan: ~(a|b) == ~a & ~b).
module nor_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = ~(a | b);

endmodule
