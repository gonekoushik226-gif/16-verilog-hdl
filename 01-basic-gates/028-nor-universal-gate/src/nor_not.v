`timescale 1ns / 1ps

// nor_not: NOT built from a single NOR with both inputs tied together.
// NOR(a,a) = ~(a|a) = ~a.
module nor_not (
    input  wire a,
    output wire y
);

    nor2 u1 (.a(a), .b(a), .y(y));

endmodule
