`timescale 1ns / 1ps

// half_subtractor: computes a-b for single bits with no borrow-in.
module half_subtractor (
    input  wire a,
    input  wire b,
    output wire diff,
    output wire borrow
);

    assign diff   = a ^ b;
    assign borrow = (~a) & b;

endmodule
