`timescale 1ns / 1ps

// dff_sync_reset: D flip-flop with a SYNCHRONOUS active-high reset --
// rst only takes effect at the next rising clk edge, unlike the
// asynchronous variants in this same program. Notice rst does not
// appear in the sensitivity list at all: it is just another data input
// sampled at the clock edge, like d.
module dff_sync_reset (
    input  wire clk,
    input  wire rst,      // active-high, synchronous
    input  wire d,
    output reg  q
);

    always @(posedge clk) begin
        if (rst) q <= 1'b0;
        else     q <= d;
    end

endmodule
