`timescale 1ns / 1ps

// half_adder: adds two single bits with no carry-in.
module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);

    assign sum   = a ^ b;
    assign carry = a & b;

endmodule
