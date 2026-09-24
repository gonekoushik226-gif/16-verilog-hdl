`timescale 1ns / 1ps

// xor_gate: 2-input XOR gate. y is 1 when a and b differ.
module xor_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = a ^ b;

endmodule
