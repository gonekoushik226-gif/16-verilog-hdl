`timescale 1ns / 1ps

// not_gate: 1-input inverter built from the bitwise-NOT operator.
// y is the logical complement of a, including 4-state (x/z) propagation.
module not_gate (
    input  wire a,
    output wire y
);

    assign y = ~a;

endmodule
