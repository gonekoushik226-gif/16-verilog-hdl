`timescale 1ns / 1ps

// dff_async_reset_n: D flip-flop with this repository's default reset
// style -- asynchronous, active-LOW (rst_n). Included alongside the
// active-high asynchronous and synchronous variants in this same
// program so their timing differences can be directly compared in one
// testbench.
module dff_async_reset_n (
    input  wire clk,
    input  wire rst_n,    // active-low, asynchronous
    input  wire d,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else        q <= d;
    end

endmodule
