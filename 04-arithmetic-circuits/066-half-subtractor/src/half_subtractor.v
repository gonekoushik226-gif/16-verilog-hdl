`timescale 1ns / 1ps

// half_subtractor: computes a-b for single bits with no borrow-in.
// diff is the XOR (same as half_adder's sum); borrow is set only when
// a=0,b=1, i.e. a bit must be borrowed from a higher position.
module half_subtractor (
    input  wire a,
    input  wire b,
    output wire diff,
    output wire borrow
);

    assign diff   = a ^ b;
    assign borrow = (~a) & b;

endmodule
