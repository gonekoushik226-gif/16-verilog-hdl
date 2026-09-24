`timescale 1ns / 1ps

// full_adder: single-bit full adder (sum-of-products form). Used both
// as the bit-sliced 3:2 compressor in csa_layer and as the final
// carry-propagate adder in three_operand_adder.
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
