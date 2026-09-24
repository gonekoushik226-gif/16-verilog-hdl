`timescale 1ns / 1ps

// nand_xor: XOR built from four NAND gates only (the classic minimal
// NAND-only XOR construction):
//   n1 = NAND(a, b)
//   n2 = NAND(a, n1)
//   n3 = NAND(b, n1)
//   y  = NAND(n2, n3)
module nand_xor (
    input  wire a,
    input  wire b,
    output wire y
);

    wire n1, n2, n3;

    nand2 u1 (.a(a),  .b(b),  .y(n1));
    nand2 u2 (.a(a),  .b(n1), .y(n2));
    nand2 u3 (.a(b),  .b(n1), .y(n3));
    nand2 u4 (.a(n2), .b(n3), .y(y));

endmodule
