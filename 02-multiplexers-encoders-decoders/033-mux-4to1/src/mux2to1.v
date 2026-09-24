`timescale 1ns / 1ps

// mux2to1: WIDTH-bit 2-to-1 multiplexer, the building block for mux4to1.
module mux2to1 #(
    parameter WIDTH = 1
) (
    input  wire             sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    output wire [WIDTH-1:0] y
);

    assign y = sel ? d1 : d0;

endmodule
