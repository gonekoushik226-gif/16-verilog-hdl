`timescale 1ns / 1ps

// half_adder: adds two single bits with no carry-in. sum is the XOR
// (odd parity of a,b), carry is the AND (both bits set).
module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);

    assign sum   = a ^ b;
    assign carry = a & b;

endmodule
