`timescale 1ns / 1ps

// d_ff: edge-triggered D flip-flop, this repository's default reset
// style (asynchronous assert, active-low rst_n). Unlike program 086's
// d_latch, q only changes at the rising edge of clk -- d's value at
// every other time, including while clk is stable at either level, has
// no effect.
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
