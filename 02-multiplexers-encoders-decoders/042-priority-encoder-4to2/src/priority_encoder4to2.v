`timescale 1ns / 1ps

// priority_encoder4to2: 4-to-2 priority encoder. Unlike encoder8to3 (041),
// multiple set bits in d are allowed: the highest-indexed set bit wins,
// using casez with don't-care bits to express the priority directly.
module priority_encoder4to2 (
    input  wire [3:0] d,
    output reg  [1:0] y,
    output reg        valid
);

    always @(*) begin
        y     = 2'b00;      // default assignment: avoids an inferred latch
        valid = |d;
        casez (d)
            4'b1???: y = 2'd3;   // bit 3 has top priority
            4'b01??: y = 2'd2;
            4'b001?: y = 2'd1;
            4'b0001: y = 2'd0;
            default: y = 2'b00;  // d == 4'b0000: no requester, y is don't-care
        endcase
    end

endmodule
