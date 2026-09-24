`timescale 1ns / 1ps

// array_multiplier4: unsigned 4x4 -> 8-bit array multiplier. Forms four
// shifted partial-product rows (each row is `a` AND-masked by one bit of
// `b` and shifted to that bit's weight) and sums all four with an array
// of half/full adders arranged as three sequential 8-bit adder stages —
// the "array" in the name refers to this grid of adder cells, as opposed
// to a single wide combinational multiply operator.
module array_multiplier4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] product
);

    // four partial-product rows, each pre-shifted to its bit's weight;
    // the maximum possible sum (15+30+60+120=225) never exceeds 8 bits,
    // so every adder stage below is exact with no overflow.
    wire [7:0] pp0 = b[0] ? {4'b0000, a}       : 8'b0;
    wire [7:0] pp1 = b[1] ? {3'b000, a, 1'b0}  : 8'b0;
    wire [7:0] pp2 = b[2] ? {2'b00, a, 2'b00}  : 8'b0;
    wire [7:0] pp3 = b[3] ? {1'b0, a, 3'b000}  : 8'b0;

    wire [7:0] sum1, sum2;
    wire [7:0] carry1, carry2, carry3;

    genvar i;

    // stage 1: sum1 = pp0 + pp1
    generate
        for (i = 0; i < 8; i = i + 1) begin : stage1
            if (i == 0)
                half_adder ha (.a(pp0[0]), .b(pp1[0]), .sum(sum1[0]), .carry(carry1[0]));
            else
                full_adder fa (.a(pp0[i]), .b(pp1[i]), .cin(carry1[i-1]),
                                .sum(sum1[i]), .carry_out(carry1[i]));
        end
    endgenerate

    // stage 2: sum2 = sum1 + pp2
    generate
        for (i = 0; i < 8; i = i + 1) begin : stage2
            if (i == 0)
                half_adder ha (.a(sum1[0]), .b(pp2[0]), .sum(sum2[0]), .carry(carry2[0]));
            else
                full_adder fa (.a(sum1[i]), .b(pp2[i]), .cin(carry2[i-1]),
                                .sum(sum2[i]), .carry_out(carry2[i]));
        end
    endgenerate

    // stage 3: product = sum2 + pp3
    generate
        for (i = 0; i < 8; i = i + 1) begin : stage3
            if (i == 0)
                half_adder ha (.a(sum2[0]), .b(pp3[0]), .sum(product[0]), .carry(carry3[0]));
            else
                full_adder fa (.a(sum2[i]), .b(pp3[i]), .cin(carry3[i-1]),
                                .sum(product[i]), .carry_out(carry3[i]));
        end
    endgenerate

endmodule
