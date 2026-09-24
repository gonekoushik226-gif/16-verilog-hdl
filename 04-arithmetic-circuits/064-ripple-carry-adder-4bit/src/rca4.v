`timescale 1ns / 1ps

// rca4: fixed 4-bit ripple-carry adder. Four full adders chained so each
// stage's carry_out feeds the next stage's cin; the final carry_out is
// the chain's overall carry/overflow-into-bit-4.
module rca4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       carry_out
);

    wire [3:0] carry;   // carry[i] = carry out of stage i

    full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin),      .sum(sum[0]), .carry_out(carry[0]));
    full_adder fa1 (.a(a[1]), .b(b[1]), .cin(carry[0]), .sum(sum[1]), .carry_out(carry[1]));
    full_adder fa2 (.a(a[2]), .b(b[2]), .cin(carry[1]), .sum(sum[2]), .carry_out(carry[2]));
    full_adder fa3 (.a(a[3]), .b(b[3]), .cin(carry[2]), .sum(sum[3]), .carry_out(carry[3]));

    assign carry_out = carry[3];

endmodule
