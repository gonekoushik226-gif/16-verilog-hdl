`timescale 1ns / 1ps

// mux4to1: 4-to-1 multiplexer built structurally from three mux2to1
// instances. sel[0] first narrows the choice within each pair, then
// sel[1] chooses between the two pairs. Reused here (unmodified from
// program 033) as the hardware that implements mux_function's Shannon
// expansion.
module mux4to1 #(
    parameter WIDTH = 1
) (
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    input  wire [WIDTH-1:0] d3,
    output wire [WIDTH-1:0] y
);

    wire [WIDTH-1:0] lo, hi;

    mux2to1 #(.WIDTH(WIDTH)) mux_lo (.sel(sel[0]), .d0(d0), .d1(d1), .y(lo));
    mux2to1 #(.WIDTH(WIDTH)) mux_hi (.sel(sel[0]), .d0(d2), .d1(d3), .y(hi));
    mux2to1 #(.WIDTH(WIDTH)) mux_out (.sel(sel[1]), .d0(lo), .d1(hi), .y(y));

endmodule
