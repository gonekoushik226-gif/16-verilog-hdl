`timescale 1ns / 1ps

// popcount: counts the number of 1 bits in a WIDTH-bit input using a
// recursive adder tree — the input is split into two halves, each half's
// population count is found recursively, and the two counts are added.
// Unlike lzc_tree (program 054), this split does not need to be exactly
// even, so the recursion terminates cleanly for any WIDTH, not just
// powers of two.
module popcount #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]         data,
    output wire [$clog2(WIDTH+1)-1:0] count
);

    generate
        if (WIDTH == 1) begin : base
            assign count = data[0];
        end else begin : recurse
            localparam HALF = WIDTH / 2;         // lower half width
            localparam REM  = WIDTH - HALF;      // upper half width

            wire [$clog2(REM+1)-1:0]  count_hi;
            wire [$clog2(HALF+1)-1:0] count_lo;

            popcount #(.WIDTH(REM))  upper (.data(data[WIDTH-1:HALF]), .count(count_hi));
            popcount #(.WIDTH(HALF)) lower (.data(data[HALF-1:0]),     .count(count_lo));

            // operand widths are automatically extended to the sum's
            // width for this addition; no result can overflow CW bits
            // since the two halves together account for exactly WIDTH bits
            assign count = count_hi + count_lo;
        end
    endgenerate

endmodule
