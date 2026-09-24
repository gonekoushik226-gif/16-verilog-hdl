`timescale 1ns / 1ps

// cska: 8-bit carry-skip adder built from two skip_block instances.
// Each block ripples internally but can also "skip" its carry straight
// through via the block-propagate mux in skip_block, shortening the
// carry path across blocks whose bits all individually propagate.
module cska (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       carry_out
);

    wire carry_mid;

    skip_block low  (.a(a[3:0]), .b(b[3:0]), .cin(cin),
                      .sum(sum[3:0]), .carry_out(carry_mid));
    skip_block high (.a(a[7:4]), .b(b[7:4]), .cin(carry_mid),
                      .sum(sum[7:4]), .carry_out(carry_out));

endmodule
