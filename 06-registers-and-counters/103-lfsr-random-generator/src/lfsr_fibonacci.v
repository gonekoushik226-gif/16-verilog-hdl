`timescale 1ns / 1ps

// lfsr_fibonacci: 8-bit Fibonacci (external-XOR) linear feedback shift
// register using the maximal-length tap set [8,6,5,4] (polynomial
// x^8+x^6+x^5+x^4+1): every cycle, the register shifts left and a
// single feedback bit -- the XOR of taps 8,6,5,4 (bits 7,5,4,3 in
// 0-indexed form) -- enters at the LSB. With a nonzero seed this
// visits all 2^8-1=255 nonzero states in a fixed cyclic order before
// repeating (all-zero is the one "locked" state, avoided by resetting
// to a nonzero seed rather than 0).
module lfsr_fibonacci #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    output wire [WIDTH-1:0] q
);

    reg [WIDTH-1:0] state;

    wire feedback = state[7] ^ state[5] ^ state[4] ^ state[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= 8'h01;
        else        state <= {state[WIDTH-2:0], feedback};
    end

    assign q = state;

endmodule
