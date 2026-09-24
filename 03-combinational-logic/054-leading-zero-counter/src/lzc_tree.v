`timescale 1ns / 1ps

// lzc_tree: leading-zero counter implemented as a divide-and-conquer tree.
// A WIDTH-bit input is split into equal upper/lower halves, each counted
// recursively; if the upper half is entirely zero, the answer is HALF plus
// the lower half's count, otherwise it is just the upper half's count.
// This is the same result as lzc_loop's priority scan, computed with
// O(log WIDTH) recursion depth instead of an O(WIDTH) sequential scan.
// Requires WIDTH to be a power of two so every recursive split is exact.
module lzc_tree #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]           data,
    output wire [$clog2(WIDTH+1)-1:0] count,
    output wire                        all_zero
);

    localparam CW = $clog2(WIDTH+1);

    generate
        if (WIDTH == 1) begin : base
            assign all_zero = ~data[0];
            assign count    = all_zero ? 1'b1 : 1'b0;
        end else begin : recurse
            localparam HALF    = WIDTH / 2;
            localparam SUB_CW  = $clog2(HALF+1);

            wire [SUB_CW-1:0] count_hi_raw, count_lo_raw;
            wire              allz_hi, allz_lo;

            lzc_tree #(.WIDTH(HALF)) upper (
                .data(data[WIDTH-1:HALF]), .count(count_hi_raw), .all_zero(allz_hi));
            lzc_tree #(.WIDTH(HALF)) lower (
                .data(data[HALF-1:0]),     .count(count_lo_raw), .all_zero(allz_lo));

            wire [CW-1:0] count_hi = {{(CW-SUB_CW){1'b0}}, count_hi_raw};
            wire [CW-1:0] count_lo = {{(CW-SUB_CW){1'b0}}, count_lo_raw};

            assign all_zero = allz_hi & allz_lo;
            // upper half all zero -> its HALF bits are all leading zeros,
            // plus whatever leading zeros the lower half itself has;
            // otherwise the upper half alone already contains the first 1
            assign count = allz_hi ? (HALF[CW-1:0] + count_lo) : count_hi;
        end
    endgenerate

endmodule
