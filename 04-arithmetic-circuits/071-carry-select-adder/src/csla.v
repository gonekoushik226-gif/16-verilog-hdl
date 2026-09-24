`timescale 1ns / 1ps

// csla: 8-bit carry-select adder, split into a low nibble and a high
// nibble. The low nibble is computed once (its carry-in is known: the
// module's own cin). The high nibble is computed speculatively *twice*,
// in parallel with the low nibble — once assuming a carry-in of 0 and
// once assuming a carry-in of 1 — so both candidate results are already
// available by the time the low nibble's real carry_out is known. A 2:1
// mux then simply selects the correct pre-computed high-nibble result,
// instead of waiting for the carry to ripple from the low nibble into
// the high one.
module csla (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       carry_out
);

    wire [3:0] sum_low;
    wire       carry_low;

    wire [3:0] sum_high0, sum_high1;
    wire       carry_high0, carry_high1;

    rca_n #(.WIDTH(4)) low (
        .a(a[3:0]), .b(b[3:0]), .cin(cin),
        .sum(sum_low), .carry_out(carry_low)
    );

    // speculative high-nibble sums, computed in parallel with `low`
    rca_n #(.WIDTH(4)) high0 (
        .a(a[7:4]), .b(b[7:4]), .cin(1'b0),
        .sum(sum_high0), .carry_out(carry_high0)
    );
    rca_n #(.WIDTH(4)) high1 (
        .a(a[7:4]), .b(b[7:4]), .cin(1'b1),
        .sum(sum_high1), .carry_out(carry_high1)
    );

    // select the correct speculative result once carry_low is known
    assign sum[3:0]  = sum_low;
    assign sum[7:4]  = carry_low ? sum_high1  : sum_high0;
    assign carry_out = carry_low ? carry_high1 : carry_high0;

endmodule
