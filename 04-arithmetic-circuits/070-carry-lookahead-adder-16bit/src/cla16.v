`timescale 1ns / 1ps

// cla16: 16-bit hierarchical (two-level) carry-lookahead adder. Four
// cla4_block instances each add one nibble using purely local
// lookahead; a single lookahead_unit computes all four blocks' carry-ins
// directly from the top-level cin and each block's group P/G, so no
// block ever waits for a ripple from the block below it.
module cla16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        cin,
    output wire [15:0] sum,
    output wire        carry_out
);

    wire [3:0] p_group, g_group, block_cin;

    cla4_block blk0 (.a(a[3:0]),   .b(b[3:0]),   .cin(block_cin[0]),
                      .sum(sum[3:0]),   .p_group(p_group[0]), .g_group(g_group[0]));
    cla4_block blk1 (.a(a[7:4]),   .b(b[7:4]),   .cin(block_cin[1]),
                      .sum(sum[7:4]),   .p_group(p_group[1]), .g_group(g_group[1]));
    cla4_block blk2 (.a(a[11:8]),  .b(b[11:8]),  .cin(block_cin[2]),
                      .sum(sum[11:8]),  .p_group(p_group[2]), .g_group(g_group[2]));
    cla4_block blk3 (.a(a[15:12]), .b(b[15:12]), .cin(block_cin[3]),
                      .sum(sum[15:12]), .p_group(p_group[3]), .g_group(g_group[3]));

    lookahead_unit lu (.p_group(p_group), .g_group(g_group), .cin(cin),
                        .block_cin(block_cin), .carry_out(carry_out));

endmodule
