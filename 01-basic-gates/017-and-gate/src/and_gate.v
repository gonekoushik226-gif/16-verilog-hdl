`timescale 1ns / 1ps

// and_gate: 2-input AND gate built from the bitwise-AND operator.
// y is 1 only when both a and b are 1.
module and_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = a & b;

endmodule
