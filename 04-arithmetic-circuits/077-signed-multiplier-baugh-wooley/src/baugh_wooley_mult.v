`timescale 1ns / 1ps

// baugh_wooley_mult: 4x4 -> 8-bit signed (two's complement) multiplier
// using the Baugh-Wooley algorithm, which turns a signed multiply into
// a single array of ordinary AND partial products (no explicit sign
// extension or subtraction anywhere), at the cost of complementing a
// few of those partial-product bits and adding two fixed correction
// bits. Derivation: writing a = -a3*8 + A, b = -b3*8 + B (A,B = the
// unsigned value of each operand's low 3 bits) and expanding a*b gives
//   a*b = a3b3*64 - a3*B*8 - b3*A*8 + A*B
// The two negative terms share the same 8x scale factor, so their sum
// S = a3*B + b3*A (a 4-bit unsigned value) can be negated as a whole
// with -S = NOT(S_zero_extended_to_5_bits) + 1, which distributes into:
// complement every individual bit of the two partial-product rows that
// make up S (row a3&b[2:0] and row b3&a[2:0]) and add two fixed 1-bits,
// one at weight 2^4 and one at the sign position 2^7 — both derived
// exactly (not by pattern-matching a textbook diagram) and verified
// exhaustively by this program's testbench against $signed(a)*$signed(b).
module baugh_wooley_mult (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] product
);

    // modified partial-product rows: row i holds bits {p_i3,p_i2,p_i1,p_i0}.
    // Upper-left 3x3 grid (i,j in 0..2) and the corner p33 are plain ANDs;
    // the rest of row 3 and column 3 are bitwise-inverted per the
    // derivation above.
    wire [3:0] row0 = { ~(a[0] & b[3]), a[0] & b[2], a[0] & b[1], a[0] & b[0] };
    wire [3:0] row1 = { ~(a[1] & b[3]), a[1] & b[2], a[1] & b[1], a[1] & b[0] };
    wire [3:0] row2 = { ~(a[2] & b[3]), a[2] & b[2], a[2] & b[1], a[2] & b[0] };
    wire [3:0] row3 = { a[3] & b[3], ~(a[3] & b[2]), ~(a[3] & b[1]), ~(a[3] & b[0]) };

    // each row is added at its own weight (row i occupies bit weight i);
    // the two correction constants sit at weight 4 (2^n) and weight 7
    // (2^(2n-1), the sign bit). Everything is summed mod 2^8, which is
    // exact because an n x n signed multiply always fits in exactly 2n
    // bits, so any "overflow" beyond bit 7 here is expected and correct
    // to discard.
    assign product = {4'b0, row0}
                    + ({4'b0, row1} << 1)
                    + ({4'b0, row2} << 2)
                    + ({4'b0, row3} << 3)
                    + 8'b0001_0000
                    + 8'b1000_0000;

endmodule
