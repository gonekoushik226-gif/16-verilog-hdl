`timescale 1ns / 1ps

// arith_ops
// Arithmetic, relational and shift operators on two 4-bit unsigned operands,
// with every result sized so that no information is lost silently.
module arith_ops (
    input  wire [3:0] a,
    input  wire [3:0] b,
    // arithmetic
    output wire [4:0] sum,        // a + b, one extra bit for the carry
    output wire [3:0] diff,       // a - b, wraps modulo 16 when b > a
    output wire       borrow,     // 1 when a < b (diff wrapped)
    output wire [7:0] product,    // a * b needs 4 + 4 = 8 bits
    output wire [3:0] quotient,   // a / b, forced to 0 when b == 0
    output wire [3:0] remainder,  // a % b, forced to 0 when b == 0
    output wire       div_by_zero,
    // relational / equality
    output wire       lt, le, gt, ge, eq, ne,
    // shifts by b[1:0]
    output wire [3:0] shl,        // logical shift left
    output wire [3:0] shr,        // logical shift right (fills with 0)
    output wire [3:0] ashr        // arithmetic shift right (fills with a[3])
);

    // Extending both operands to 5 bits makes the carry visible.
    assign sum    = {1'b0, a} + {1'b0, b};
    assign diff   = a - b;
    assign borrow = (a < b);

    assign product = a * b;       // operands are extended to the 8-bit target

    // Division by zero returns x in simulation; define the behaviour instead.
    assign div_by_zero = (b == 4'd0);
    assign quotient    = div_by_zero ? 4'd0 : a / b;
    assign remainder   = div_by_zero ? 4'd0 : a % b;

    assign lt = (a <  b);
    assign le = (a <= b);
    assign gt = (a >  b);
    assign ge = (a >= b);
    assign eq = (a == b);
    assign ne = (a != b);

    assign shl  = a << b[1:0];
    assign shr  = a >> b[1:0];
    assign ashr = $signed(a) >>> b[1:0];   // >>> only sign-fills a signed operand

endmodule
