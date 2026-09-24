`timescale 1ns / 1ps

// mux4to1: 4-to-1 multiplexer built structurally from three mux2to1
// instances instead of a single wide expression. sel[0] first narrows the
// choice within each pair, then sel[1] chooses between the two pairs.
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

    // First stage: pick within {d0,d1} and within {d2,d3} using sel[0]
    mux2to1 #(.WIDTH(WIDTH)) mux_lo (.sel(sel[0]), .d0(d0), .d1(d1), .y(lo));
    mux2to1 #(.WIDTH(WIDTH)) mux_hi (.sel(sel[0]), .d0(d2), .d1(d3), .y(hi));

    // Second stage: pick between the two first-stage results using sel[1]
    mux2to1 #(.WIDTH(WIDTH)) mux_out (.sel(sel[1]), .d0(lo), .d1(hi), .y(y));

endmodule
