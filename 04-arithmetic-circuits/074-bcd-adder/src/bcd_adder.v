`timescale 1ns / 1ps

// bcd_adder: DIGITS-digit BCD adder, cascading bcd_digit_adder the same
// way rca_n cascades full_adder — each digit's decimal carry-out feeds
// the next digit's carry-in.
module bcd_adder #(
    parameter DIGITS = 4
) (
    input  wire [DIGITS*4-1:0] a,     // DIGITS packed BCD digits, digit 0 = a[3:0]
    input  wire [DIGITS*4-1:0] b,
    input  wire                cin,
    output wire [DIGITS*4-1:0] sum,
    output wire                cout   // carry out of the most significant digit
);

    wire [DIGITS:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < DIGITS; i = i + 1) begin : digit
            bcd_digit_adder u (
                .a(a[i*4 +: 4]), .b(b[i*4 +: 4]), .cin(carry[i]),
                .sum(sum[i*4 +: 4]), .cout(carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[DIGITS];

endmodule
