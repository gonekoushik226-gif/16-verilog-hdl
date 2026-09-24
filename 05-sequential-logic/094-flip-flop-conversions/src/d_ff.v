`timescale 1ns / 1ps

// d_ff: plain D flip-flop (same design as program 087), reused here as
// the elementary storage element every conversion in this program is
// built from.
module d_ff (
    input  wire clk,
    input  wire rst_n,
    input  wire d,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else        q <= d;
    end

endmodule
