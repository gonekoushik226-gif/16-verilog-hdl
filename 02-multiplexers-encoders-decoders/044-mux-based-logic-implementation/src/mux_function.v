`timescale 1ns / 1ps

// mux_function: implements the 3-input majority function
//   f(a,b,c) = a&b | b&c | a&c   (f = 1 iff at least two of a,b,c are 1)
// using a single 4-to-1 mux and Shannon expansion on {a,b}, instead of a
// sum-of-products expression. Expanding f around a and b leaves, for each
// of the four (a,b) combinations, a residual function of c alone:
//
//   a b | f(a,b,c) residual (as a function of c)
//   0 0 |  0            (constant 0)
//   0 1 |  c            (constant "c")
//   1 0 |  c            (constant "c")
//   1 1 |  1            (constant 1)
//
// Those four residuals become the mux's four data inputs, with {a,b}
// driving its select.
module mux_function (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire y
);

    mux4to1 #(.WIDTH(1)) mux_inst (
        .sel({a, b}),
        .d0(1'b0),   // a=0,b=0 residual: f = 0
        .d1(c),      // a=0,b=1 residual: f = c
        .d2(c),      // a=1,b=0 residual: f = c
        .d3(1'b1),   // a=1,b=1 residual: f = 1
        .y(y)
    );

endmodule
