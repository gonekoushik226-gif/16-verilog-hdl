`timescale 1ns / 1ps

// nand_universal_top: wraps the NAND-only NOT/AND/OR/XOR built in this
// program behind one set of ports so a single testbench can compare all
// four against Verilog's native operators.
module nand_universal_top (
    input  wire a,
    input  wire b,
    output wire y_not_a,
    output wire y_and,
    output wire y_or,
    output wire y_xor
);

    nand_not u_not (.a(a), .y(y_not_a));
    nand_and u_and (.a(a), .b(b), .y(y_and));
    nand_or  u_or  (.a(a), .b(b), .y(y_or));
    nand_xor u_xor (.a(a), .b(b), .y(y_xor));

endmodule
