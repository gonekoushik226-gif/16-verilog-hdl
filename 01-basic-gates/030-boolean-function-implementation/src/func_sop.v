`timescale 1ns / 1ps

// func_sop: canonical sum-of-products (SOP) form of
//   f(a,b,c) = Sum of minterms m(0, 2, 5, 7)
// One product term per minterm where f = 1, OR-ed together — read
// directly off the truth table with no simplification.
module func_sop (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    assign y = (~a & ~b & ~c)   // m0: 000
             | (~a &  b & ~c)   // m2: 010
             | ( a & ~b &  c)   // m5: 101
             | ( a &  b &  c);  // m7: 111

endmodule
