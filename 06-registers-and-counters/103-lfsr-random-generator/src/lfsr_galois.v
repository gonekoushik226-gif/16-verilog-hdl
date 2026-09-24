`timescale 1ns / 1ps

// lfsr_galois: the same maximal-length polynomial as lfsr_fibonacci.v
// (x^8+x^6+x^5+x^4+1), realized in Galois (internal-XOR) form instead:
// the register shifts right every cycle, and only when the bit shifting
// out is 1 does the register additionally XOR with a fixed tap mask
// (8'hB8 = taps at bits 7,5,4,3) -- functionally equivalent (same
// period, same maximal-length property) to the Fibonacci form but with
// the XOR gates distributed through the register instead of
// concentrated in one external feedback path, which is what usually
// lets a Galois LFSR run at a higher clock rate in real hardware.
module lfsr_galois #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    output wire [WIDTH-1:0] q
);

    localparam [WIDTH-1:0] TAP_MASK = 8'hB8;

    reg [WIDTH-1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= 8'h01;
        else        state <= state[0] ? ((state >> 1) ^ TAP_MASK) : (state >> 1);
    end

    assign q = state;

endmodule
