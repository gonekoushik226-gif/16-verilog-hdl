`timescale 1ns / 1ps

// arith_unit: the arithmetic half of the hierarchical ALU. Computes
// add or subtract (selected by `sub`) plus carry/overflow, using the
// same widened-minuend two's-complement technique as program 068/081.
module arith_unit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire        sub,
    output wire [7:0] result,
    output wire        carry,
    output wire        overflow
);

    wire [8:0] ext = sub ? ({1'b1, a} - {1'b0, b}) : ({1'b0, a} + {1'b0, b});

    assign result   = ext[7:0];
    assign carry    = ext[8];
    assign overflow = sub ? ((a[7] != b[7]) && (result[7] != a[7]))
                           : ((a[7] == b[7]) && (result[7] != a[7]));

endmodule
