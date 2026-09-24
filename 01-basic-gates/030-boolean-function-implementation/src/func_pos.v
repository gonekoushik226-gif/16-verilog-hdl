`timescale 1ns / 1ps

// func_pos: canonical product-of-sums (POS) form of the same function
//   f(a,b,c) = Sum of minterms m(0, 2, 5, 7) = Product of maxterms M(1, 3, 4, 6)
// One sum term per maxterm where f = 0, AND-ed together.
module func_pos (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    assign y = ( a |  b | ~c)   // M1: forces y=0 at 001
             & ( a | ~b | ~c)   // M3: forces y=0 at 011
             & (~a |  b |  c)   // M4: forces y=0 at 100
             & (~a | ~b |  c);  // M6: forces y=0 at 110

endmodule
