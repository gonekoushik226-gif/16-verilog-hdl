`timescale 1ns / 1ps

// xnor_gate: 2-input XNOR gate. y is 1 when a and b are equal.
module xnor_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = ~(a ^ b);

endmodule
