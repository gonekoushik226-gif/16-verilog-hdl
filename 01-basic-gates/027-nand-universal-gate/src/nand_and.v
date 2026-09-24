`timescale 1ns / 1ps

// nand_and: AND built from NAND. NAND(a,b) then inverted with nand_not
// (a NAND is an AND that still needs to be un-inverted).
module nand_and (
    input  wire a,
    input  wire b,
    output wire y
);

    wire n;

    nand2    u1 (.a(a), .b(b), .y(n));
    nand_not u2 (.a(n), .y(y));

endmodule
