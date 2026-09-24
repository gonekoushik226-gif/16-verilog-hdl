`timescale 1ns / 1ps

// hamming74_encoder: encodes 4 data bits into a 7-bit Hamming(7,4)
// codeword. Codeword bit positions are 1-indexed (matching the standard
// textbook derivation): position p is a parity bit when p is a power of
// two (1, 2, 4); every other position carries a data bit. Each parity bit
// covers exactly the positions whose binary representation has that
// parity bit's own bit set — e.g. p1 (position 1) covers every position
// with bit 0 set (1,3,5,7).
//
//   position: 1  2  3  4  5  6  7
//   content:  p1 p2 d1 p3 d2 d3 d4
module hamming74_encoder (
    input  wire [3:0] data,   // {d4,d3,d2,d1} — data[0]=d1 .. data[3]=d4
    output wire [6:0] code    // code[0]=position1 .. code[6]=position7
);

    wire d1 = data[0];
    wire d2 = data[1];
    wire d3 = data[2];
    wire d4 = data[3];

    // p1 covers positions {1,3,5,7} = {p1,d1,d2,d4}
    wire p1 = d1 ^ d2 ^ d4;
    // p2 covers positions {2,3,6,7} = {p2,d1,d3,d4}
    wire p2 = d1 ^ d3 ^ d4;
    // p3 covers positions {4,5,6,7} = {p3,d2,d3,d4}
    wire p3 = d2 ^ d3 ^ d4;

    assign code = {d4, d3, d2, p3, d1, p2, p1};

endmodule
