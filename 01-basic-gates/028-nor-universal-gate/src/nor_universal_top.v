`timescale 1ns / 1ps

// nor_universal_top: wraps the NOR-only NOT/AND/OR/XNOR built in this
// program behind one set of ports so a single testbench can compare all
// four against Verilog's native operators.
module nor_universal_top (
    input  wire a,
    input  wire b,
    output wire y_not_a,
    output wire y_and,
    output wire y_or,
    output wire y_xnor
);

    nor_not  u_not  (.a(a), .y(y_not_a));
    nor_and  u_and  (.a(a), .b(b), .y(y_and));
    nor_or   u_or   (.a(a), .b(b), .y(y_or));
    nor_xnor u_xnor (.a(a), .b(b), .y(y_xnor));

endmodule
