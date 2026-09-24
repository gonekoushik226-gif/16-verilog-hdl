`timescale 1ns / 1ps

// nor_xnor: the NOR-only dual of the NAND-only XOR network in 027. Wiring
// four NOR gates in the same pattern that gives XOR with NAND gives XNOR
// with NOR (De Morgan duality swaps AND<->OR and NAND<->NOR everywhere,
// which turns the "difference" function into the "equality" function):
//   n1 = NOR(a, b)
//   n2 = NOR(a, n1)
//   n3 = NOR(b, n1)
//   y  = NOR(n2, n3)
module nor_xnor (
    input  wire a,
    input  wire b,
    output wire y
);

    wire n1, n2, n3;

    nor2 u1 (.a(a),  .b(b),  .y(n1));
    nor2 u2 (.a(a),  .b(n1), .y(n2));
    nor2 u3 (.a(b),  .b(n1), .y(n3));
    nor2 u4 (.a(n2), .b(n3), .y(y));

endmodule
