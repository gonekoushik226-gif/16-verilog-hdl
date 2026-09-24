`timescale 1ns / 1ps

// operator_unit
// Side-by-side comparison of the three operator families that look alike:
//   bitwise   (& | ^ ~)   : operate bit by bit, result as wide as the operands
//   logical   (&& || !)   : treat each operand as true/false, 1-bit result
//   reduction (&a |a ^a)  : combine all bits of ONE operand into 1 bit
module operator_unit (
    input  wire [3:0] a,
    input  wire [3:0] b,
    // bitwise
    output wire [3:0] and_bw,
    output wire [3:0] or_bw,
    output wire [3:0] xor_bw,
    output wire [3:0] not_a,
    // logical
    output wire       and_log,
    output wire       or_log,
    output wire       not_log,
    // reduction on a
    output wire       red_and,
    output wire       red_or,
    output wire       red_xor,
    output wire       red_nand,
    output wire       red_nor,
    output wire       red_xnor
);

    assign and_bw  = a & b;
    assign or_bw   = a | b;
    assign xor_bw  = a ^ b;
    assign not_a   = ~a;

    assign and_log = a && b;   // true when a != 0 AND b != 0
    assign or_log  = a || b;   // true when a != 0 OR  b != 0
    assign not_log = !a;       // true when a == 0

    assign red_and  = &a;      // a[3] & a[2] & a[1] & a[0]
    assign red_or   = |a;
    assign red_xor  = ^a;      // odd parity of a
    assign red_nand = ~&a;
    assign red_nor  = ~|a;
    assign red_xnor = ~^a;

endmodule
