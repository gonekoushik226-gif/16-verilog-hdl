`timescale 1ns / 1ps

// signed_ops
// Two's complement arithmetic on 4-bit signed operands (-8 .. +7).
module signed_ops (
    input  wire signed [3:0] a,
    input  wire signed [3:0] b,
    output wire signed [4:0] sum_full,    // a + b, sign-extended: never overflows
    output wire signed [3:0] sum_wrap,    // a + b truncated to 4 bits
    output wire              overflow,    // sum_wrap is wrong (signed overflow)
    output wire signed [4:0] neg_a,       // -a, 5 bits so that -(-8) = +8 fits
    output wire        [3:0] abs_a,       // |a| as unsigned (0..8)
    output wire signed [7:0] sext_a,      // a sign-extended to 8 bits
    output wire        [7:0] zext_a,      // a zero-extended to 8 bits (a different value!)
    output wire              lt_signed,   // a < b comparing as signed numbers
    output wire              lt_unsigned, // same bits compared as unsigned numbers
    output wire signed [7:0] product      // a * b, signed
);

    // Both operands are signed, so Verilog sign-extends them to the 5-bit target
    assign sum_full = a + b;
    assign sum_wrap = a + b;

    // Signed overflow: operands have the same sign but the result sign differs
    assign overflow = (a[3] == b[3]) && (sum_wrap[3] != a[3]);

    assign neg_a  = -a;
    assign abs_a  = a[3] ? -a : a;          // -(-8) = 1000b = 8 read as unsigned
    assign sext_a = a;                      // implicit sign extension (signed source)
    assign zext_a = {4'b0000, a};           // concatenation result is unsigned

    assign lt_signed   = (a < b);
    assign lt_unsigned = ($unsigned(a) < $unsigned(b));

    assign product = a * b;

endmodule
