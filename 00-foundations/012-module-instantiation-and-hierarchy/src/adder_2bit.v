`timescale 1ns / 1ps

// adder_2bit: two full adders chained through carry_mid.
// fa0 uses named port connections (recommended);
// fa1 uses positional connections (order must match the port list exactly).
module adder_2bit (
    input  wire [1:0] a,
    input  wire [1:0] b,
    input  wire       cin,
    output wire [1:0] sum,
    output wire       cout
);

    wire carry_mid;   // carry from bit 0 into bit 1

    full_adder fa0 (
        .a   (a[0]),
        .b   (b[0]),
        .cin (cin),
        .sum (sum[0]),
        .cout(carry_mid)
    );

    // positional: (a, b, cin, sum, cout)
    full_adder fa1 (a[1], b[1], carry_mid, sum[1], cout);

endmodule
