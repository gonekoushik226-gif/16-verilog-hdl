`timescale 1ns / 1ps

// comparator1: single-bit magnitude comparator cell with cascade inputs,
// the building block comparator4 chains from MSB to LSB (7485-style).
// A cascaded comparator cannot decide gt/lt/eq from one bit pair alone: it
// must fall back to the result of the more-significant stage when the two
// input bits are equal, which is what the cascade inputs (gt_in/lt_in/eq_in)
// carry in from the previous (more-significant) cell.
module comparator1 (
    input  wire a,
    input  wire b,
    input  wire gt_in,   // cascaded "greater" decision from the more-significant stage
    input  wire lt_in,   // cascaded "less" decision from the more-significant stage
    input  wire eq_in,   // cascaded "equal so far" decision from the more-significant stage
    output reg  gt_out,
    output reg  lt_out,
    output reg  eq_out
);

    always @(*) begin
        if (eq_in) begin
            // every more-significant bit was equal: this bit gets to decide
            if (a & ~b) begin
                gt_out = 1'b1; lt_out = 1'b0; eq_out = 1'b0;
            end else if (~a & b) begin
                gt_out = 1'b0; lt_out = 1'b1; eq_out = 1'b0;
            end else begin
                gt_out = 1'b0; lt_out = 1'b0; eq_out = 1'b1;
            end
        end else begin
            // a more-significant bit already decided gt/lt: this bit cannot
            // overturn that outcome, so pass the cascaded decision through
            // unchanged instead of comparing a and b at all
            gt_out = gt_in;
            lt_out = lt_in;
            eq_out = 1'b0;
        end
    end

endmodule
