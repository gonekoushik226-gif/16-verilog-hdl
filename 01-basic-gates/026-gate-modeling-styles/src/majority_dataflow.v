`timescale 1ns / 1ps

// majority_dataflow: the same 3-input majority function expressed as one
// Boolean equation with continuous assignment — the middle level of
// abstraction.
module majority_dataflow (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    assign y = (a & b) | (b & c) | (a & c);

endmodule
