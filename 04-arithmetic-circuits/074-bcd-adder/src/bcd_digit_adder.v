`timescale 1ns / 1ps

// bcd_digit_adder: adds two BCD digits (0-9 each) plus a carry-in and
// produces a valid BCD digit sum plus a decimal carry-out. Binary
// addition alone is not decimally correct once the result exceeds 9
// (e.g. 9+9=18 in binary is 0b10010, which is not a valid single BCD
// digit) — the classic fix is to detect that case and add 6, which
// pushes the result past the next power-of-two boundary exactly enough
// to "skip" the six unused 4-bit codes (1010-1111) and land back on a
// valid BCD digit with the correct decimal carry.
module bcd_digit_adder (
    input  wire [3:0] a,     // BCD digit, 0-9
    input  wire [3:0] b,     // BCD digit, 0-9
    input  wire       cin,
    output wire [3:0] sum,   // BCD digit, 0-9
    output wire       cout   // decimal carry: 1 if the digit sum >= 10
);

    wire [4:0] bin_sum = {1'b0, a} + {1'b0, b} + {4'b0, cin};
    wire       correct = (bin_sum > 5'd9);
    wire [4:0] corrected = correct ? (bin_sum + 5'd6) : bin_sum;

    assign sum  = corrected[3:0];
    assign cout = correct;

endmodule
