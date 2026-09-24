`timescale 1ns / 1ps

// nand_not: NOT built from a single NAND with both inputs tied together.
// NAND(a,a) = ~(a&a) = ~a.
module nand_not (
    input  wire a,
    output wire y
);

    nand2 u1 (.a(a), .b(a), .y(y));

endmodule
