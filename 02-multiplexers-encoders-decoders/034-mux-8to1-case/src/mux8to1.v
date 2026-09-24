`timescale 1ns / 1ps

// mux8to1: WIDTH-bit 8-to-1 multiplexer written with a case statement
// instead of a mux tree, showing the alternative "table lookup" coding
// style for the same kind of block as mux2to1/mux4to1.
module mux8to1 #(
    parameter WIDTH = 1
) (
    input  wire [2:0]       sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    input  wire [WIDTH-1:0] d3,
    input  wire [WIDTH-1:0] d4,
    input  wire [WIDTH-1:0] d5,
    input  wire [WIDTH-1:0] d6,
    input  wire [WIDTH-1:0] d7,
    output reg  [WIDTH-1:0] y
);

    always @(*) begin
        y = {WIDTH{1'b0}};      // default assignment: avoids an inferred latch
        case (sel)
            3'd0: y = d0;
            3'd1: y = d1;
            3'd2: y = d2;
            3'd3: y = d3;
            3'd4: y = d4;
            3'd5: y = d5;
            3'd6: y = d6;
            3'd7: y = d7;
            default: y = {WIDTH{1'b0}};
        endcase
    end

endmodule
