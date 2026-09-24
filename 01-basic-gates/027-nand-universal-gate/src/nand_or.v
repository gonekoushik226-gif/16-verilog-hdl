`timescale 1ns / 1ps

// nand_or: OR built from NAND using De Morgan's theorem:
// a | b == ~(~a & ~b) == NAND(NOT a, NOT b).
module nand_or (
    input  wire a,
    input  wire b,
    output wire y
);

    wire na, nb;

    nand_not u1 (.a(a), .y(na));
    nand_not u2 (.a(b), .y(nb));
    nand2    u3 (.a(na), .b(nb), .y(y));

endmodule
