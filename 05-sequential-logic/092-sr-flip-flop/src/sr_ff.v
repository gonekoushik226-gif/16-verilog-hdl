`timescale 1ns / 1ps

// sr_ff: clocked (edge-triggered) SR flip-flop. Being edge-triggered
// does not remove the S=R=1 ambiguity the way a JK flip-flop's toggle
// definition does (program 090) -- S=R=1 is still not a meaningful
// "set and reset simultaneously" request. This design's documented
// policy: S=R=1 is treated as invalid and reported on a dedicated
// `invalid` flag, while q simply holds its previous value rather than
// updating to an arbitrary result.
module sr_ff (
    input  wire clk,
    input  wire rst_n,
    input  wire s,
    input  wire r,
    output reg  q,
    output wire invalid
);

    assign invalid = s & r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else begin
            case ({s, r})
                2'b00: q <= q;      // hold
                2'b01: q <= 1'b0;   // reset
                2'b10: q <= 1'b1;   // set
                2'b11: q <= q;      // invalid: policy is to hold, not guess
            endcase
        end
    end

endmodule
