`timescale 1ns / 1ps

// nor_or: OR built from NOR. NOR(a,b) then inverted with nor_not
// (a NOR is an OR that still needs to be un-inverted).
module nor_or (
    input  wire a,
    input  wire b,
    output wire y
);

    wire n;

    nor2    u1 (.a(a), .b(b), .y(n));
    nor_not u2 (.a(n), .y(y));

endmodule
