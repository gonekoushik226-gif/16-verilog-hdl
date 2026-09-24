`timescale 1ns / 1ps

// nand2: the single 2-input NAND primitive every other gate in this
// program is built from.
module nand2 (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = ~(a & b);

endmodule
