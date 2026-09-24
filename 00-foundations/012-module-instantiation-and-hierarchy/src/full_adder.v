`timescale 1ns / 1ps

// full_adder: adds three bits using two half adders and an OR gate
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    wire sum_ab;     // a ^ b from the first half adder
    wire carry_ab;   // a & b
    wire carry_c;    // (a ^ b) & cin

    half_adder ha_ab (
        .a    (a),
        .b    (b),
        .sum  (sum_ab),
        .carry(carry_ab)
    );

    half_adder ha_c (
        .a    (sum_ab),
        .b    (cin),
        .sum  (sum),
        .carry(carry_c)
    );

    assign cout = carry_ab | carry_c;

endmodule
