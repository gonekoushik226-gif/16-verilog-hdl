`timescale 1ns / 1ps

// nor_and: AND built from NOR using De Morgan's theorem:
// a & b == ~(~a | ~b) == NOR(NOT a, NOT b).
module nor_and (
    input  wire a,
    input  wire b,
    output wire y
);

    wire na, nb;

    nor_not u1 (.a(a), .y(na));
    nor_not u2 (.a(b), .y(nb));
    nor2    u3 (.a(na), .b(nb), .y(y));

endmodule
