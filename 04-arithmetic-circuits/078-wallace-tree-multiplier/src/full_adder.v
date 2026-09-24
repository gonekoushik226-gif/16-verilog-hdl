`timescale 1ns / 1ps

// full_adder: single-bit full adder, used here as a 3:2 compressor cell
// (three same-weight bits in, one sum bit + one carry bit out) in the
// Wallace reduction tree, and again in the final carry-propagate adder.
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire carry_out
);

    assign sum       = a ^ b ^ cin;
    assign carry_out = (a & b) | (a & cin) | (b & cin);

endmodule
