`timescale 1ns / 1ps

// add_sub: 4-bit combined adder/subtractor. When sub=0 it computes a+b;
// when sub=1 it computes a-b using the standard two's-complement trick:
// XOR every b bit with sub (one's complement when sub=1) and feed sub
// itself in as cin (the "+1" that turns one's complement into two's
// complement). Both operations share the same ripple-carry hardware.
module add_sub (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       sub,        // 0 = add (a+b), 1 = subtract (a-b)
    output wire [3:0] result,
    output wire       carry_out,  // unsigned carry (add) / NOT borrow (subtract)
    output wire       overflow,   // signed two's-complement overflow
    output wire       zero,       // result == 0
    output wire       negative    // result[3], sign bit if operands are signed
);

    wire [3:0] b_mux = b ^ {4{sub}};   // b unchanged for add, ~b for subtract
    wire [3:0] carry;                  // carry[i] = carry out of stage i

    full_adder fa0 (.a(a[0]), .b(b_mux[0]), .cin(sub),      .sum(result[0]), .carry_out(carry[0]));
    full_adder fa1 (.a(a[1]), .b(b_mux[1]), .cin(carry[0]), .sum(result[1]), .carry_out(carry[1]));
    full_adder fa2 (.a(a[2]), .b(b_mux[2]), .cin(carry[1]), .sum(result[2]), .carry_out(carry[2]));
    full_adder fa3 (.a(a[3]), .b(b_mux[3]), .cin(carry[2]), .sum(result[3]), .carry_out(carry[3]));

    assign carry_out = carry[3];
    // overflow: the carry into the sign bit disagrees with the carry out
    // of the sign bit — the classic two's-complement overflow test.
    assign overflow  = carry[3] ^ carry[2];
    assign zero      = (result == 4'b0000);
    assign negative  = result[3];

endmodule
