`timescale 1ns / 1ps

// bin2gray: converts a WIDTH-bit binary value to its reflected Gray code.
// Gray code's defining property is that consecutive values differ in
// exactly one bit, which this XOR-with-shifted-self construction achieves:
// each Gray bit is the XOR of a binary bit with the next more-significant
// binary bit, so only the single binary bit that actually toggles between
// n and n+1 changes any Gray bit above the point of the carry ripple.
module bin2gray #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] bin,
    output wire [WIDTH-1:0] gray
);

    // gray[WIDTH-1] = bin[WIDTH-1] (bin>>1 has a 0 there); every other bit
    // is bin[i] XOR bin[i+1].
    assign gray = bin ^ (bin >> 1);

endmodule
