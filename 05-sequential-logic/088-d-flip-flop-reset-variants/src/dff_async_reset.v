`timescale 1ns / 1ps

// dff_async_reset: D flip-flop with an ASYNCHRONOUS ACTIVE-HIGH reset
// -- a deliberate deviation from this repository's default reset style
// (asynchronous, active-LOW), included here specifically to contrast
// with dff_async_reset_n.v and dff_sync_reset.v in the same testbench.
// Asserting rst takes effect immediately, independent of clk.
module dff_async_reset (
    input  wire clk,
    input  wire rst,      // active-high, asynchronous
    input  wire d,
    output reg  q
);

    always @(posedge clk or posedge rst) begin
        if (rst) q <= 1'b0;
        else     q <= d;
    end

endmodule
