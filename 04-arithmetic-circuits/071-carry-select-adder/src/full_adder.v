`timescale 1ns / 1ps

// full_adder: single-bit full adder (sum-of-products form).
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
