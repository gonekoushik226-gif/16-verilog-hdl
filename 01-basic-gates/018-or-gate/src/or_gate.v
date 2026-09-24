`timescale 1ns / 1ps

// or_gate: 2-input OR gate built from the bitwise-OR operator.
// y is 1 when either a or b (or both) is 1.
module or_gate (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = a | b;

endmodule
