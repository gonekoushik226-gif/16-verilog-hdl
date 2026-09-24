`timescale 1ns / 1ps

// wallace_mult4: unsigned 4x4 -> 8-bit Wallace-tree multiplier. Forms
// the same 16 AND partial products as program 076's array multiplier,
// but instead of summing them with three sequential full-width adders,
// reduces each same-weight column in parallel with 3:2 compressors
// (full adders) until every column holds at most two bits, then
// combines the final two rows with one carry-propagate adder (CPA).
// This wiring was hand-derived column by column (see the stage
// comments below) and cross-checked exhaustively by this program's
// testbench.
module wallace_mult4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] product
);

    // 16 partial products, pp_i_j = a[i] & b[j], at weight (i+j)
    wire pp_0_0 = a[0] & b[0];
    wire pp_0_1 = a[0] & b[1];
    wire pp_0_2 = a[0] & b[2];
    wire pp_0_3 = a[0] & b[3];
    wire pp_1_0 = a[1] & b[0];
    wire pp_1_1 = a[1] & b[1];
    wire pp_1_2 = a[1] & b[2];
    wire pp_1_3 = a[1] & b[3];
    wire pp_2_0 = a[2] & b[0];
    wire pp_2_1 = a[2] & b[1];
    wire pp_2_2 = a[2] & b[2];
    wire pp_2_3 = a[2] & b[3];
    wire pp_3_0 = a[3] & b[0];
    wire pp_3_1 = a[3] & b[1];
    wire pp_3_2 = a[3] & b[2];
    wire pp_3_3 = a[3] & b[3];

    // column bit counts before reduction: w0=1 w1=2 w2=3 w3=4 w4=3 w5=2 w6=1

    // ---- stage 1: reduce the three columns with height >= 3 (w2, w3, w4) ----
    wire s2_1, c2_1;   // w2 (pp_0_2,pp_1_1,pp_2_0) -> sum stays w2, carry -> w3
    full_adder fa1 (.a(pp_0_2), .b(pp_1_1), .cin(pp_2_0), .sum(s2_1), .carry_out(c2_1));

    wire s3_1, c3_1;   // w3, 3 of its 4 bits (pp_0_3,pp_1_2,pp_2_1) -> sum stays w3, carry -> w4
    full_adder fa2 (.a(pp_0_3), .b(pp_1_2), .cin(pp_2_1), .sum(s3_1), .carry_out(c3_1));
    // pp_3_0 is w3's 4th bit; it passes through stage 1 unreduced

    wire s4_1, c4_1;   // w4 (pp_1_3,pp_2_2,pp_3_1) -> sum stays w4, carry -> w5
    full_adder fa3 (.a(pp_1_3), .b(pp_2_2), .cin(pp_3_1), .sum(s4_1), .carry_out(c4_1));

    // after stage 1: w0=1 w1=2 w2=1{s2_1} w3=3{s3_1,pp_3_0,c2_1}
    //                w4=2{s4_1,c3_1} w5=3{pp_2_3,pp_3_2,c4_1} w6=1

    // ---- stage 2: reduce the two columns now at height 3 (w3, w5) ----
    wire s3_2, c3_2;   // w3 (s3_1,pp_3_0,c2_1) -> sum stays w3, carry -> w4
    full_adder fa4 (.a(s3_1), .b(pp_3_0), .cin(c2_1), .sum(s3_2), .carry_out(c3_2));

    wire s5_2, c5_2;   // w5 (pp_2_3,pp_3_2,c4_1) -> sum stays w5, carry -> w6
    full_adder fa5 (.a(pp_2_3), .b(pp_3_2), .cin(c4_1), .sum(s5_2), .carry_out(c5_2));

    // after stage 2: w0=1 w1=2 w2=1 w3=1{s3_2} w4=3{s4_1,c3_1,c3_2}
    //                w5=1{s5_2} w6=2{pp_3_3,c5_2}

    // ---- stage 3: reduce the one remaining column at height 3 (w4) ----
    wire s4_3, c4_3;   // w4 (s4_1,c3_1,c3_2) -> sum stays w4, carry -> w5
    full_adder fa6 (.a(s4_1), .b(c3_1), .cin(c3_2), .sum(s4_3), .carry_out(c4_3));

    // after stage 3, every column has height <= 2:
    // w0=1{pp_0_0} w1=2{pp_0_1,pp_1_0} w2=1{s2_1} w3=1{s3_2}
    // w4=1{s4_3}   w5=2{s5_2,c4_3}     w6=2{pp_3_3,c5_2}

    // ---- final carry-propagate adder: combine the two remaining rows ----
    wire [6:0] row_a = {pp_3_3, s5_2, s4_3, s3_2, s2_1, pp_0_1, pp_0_0};
    wire [6:0] row_b = {c5_2,   c4_3, 1'b0, 1'b0, 1'b0, pp_1_0, 1'b0  };

    wire [6:0] carry;
    half_adder ha0 (.a(row_a[0]), .b(row_b[0]), .sum(product[0]), .carry(carry[0]));
    genvar i;
    generate
        for (i = 1; i < 7; i = i + 1) begin : cpa
            full_adder fa (.a(row_a[i]), .b(row_b[i]), .cin(carry[i-1]),
                            .sum(product[i]), .carry_out(carry[i]));
        end
    endgenerate
    assign product[7] = carry[6];

endmodule
