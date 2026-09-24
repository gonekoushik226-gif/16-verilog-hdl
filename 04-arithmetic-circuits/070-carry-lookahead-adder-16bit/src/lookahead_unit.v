`timescale 1ns / 1ps

// lookahead_unit: second-level carry lookahead across four 4-bit blocks.
// Treats each block's group propagate/generate (P[i]/G[i]) exactly the
// way cla4_block treats a single bit's p/g, producing all four blocks'
// carry-ins in parallel from the overall cin — no block waits for the
// block below it to finish rippling, which is the entire point of a
// hierarchical (two-level) lookahead adder.
module lookahead_unit (
    input  wire [3:0] p_group,   // p_group[i] = block i's group propagate
    input  wire [3:0] g_group,   // g_group[i] = block i's group generate
    input  wire       cin,
    output wire [3:0] block_cin, // block_cin[i] = carry into block i
    output wire       carry_out  // final carry out of block 3
);

    wire c0 = cin;
    wire c1 = g_group[0] | (p_group[0] & c0);
    wire c2 = g_group[1] | (p_group[1] & g_group[0])
            | (p_group[1] & p_group[0] & c0);
    wire c3 = g_group[2] | (p_group[2] & g_group[1])
            | (p_group[2] & p_group[1] & g_group[0])
            | (p_group[2] & p_group[1] & p_group[0] & c0);
    wire c4 = g_group[3] | (p_group[3] & g_group[2])
            | (p_group[3] & p_group[2] & g_group[1])
            | (p_group[3] & p_group[2] & p_group[1] & g_group[0])
            | (p_group[3] & p_group[2] & p_group[1] & p_group[0] & c0);

    assign block_cin = {c3, c2, c1, c0};
    assign carry_out = c4;

endmodule
