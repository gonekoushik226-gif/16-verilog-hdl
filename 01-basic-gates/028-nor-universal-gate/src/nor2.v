`timescale 1ns / 1ps

// nor2: the single 2-input NOR primitive every other gate in this
// program is built from.
module nor2 (
    input  wire a,
    input  wire b,
    output wire y
);

    assign y = ~(a | b);

endmodule
