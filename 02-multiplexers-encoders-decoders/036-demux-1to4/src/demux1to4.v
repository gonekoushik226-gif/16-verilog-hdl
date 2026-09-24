`timescale 1ns / 1ps

// demux1to4: routes a single WIDTH-bit data input to exactly one of four
// outputs, chosen by sel; every non-selected output is held at zero.
module demux1to4 #(
    parameter WIDTH = 1
) (
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] y0,
    output wire [WIDTH-1:0] y1,
    output wire [WIDTH-1:0] y2,
    output wire [WIDTH-1:0] y3
);

    assign y0 = (sel == 2'b00) ? d : {WIDTH{1'b0}};
    assign y1 = (sel == 2'b01) ? d : {WIDTH{1'b0}};
    assign y2 = (sel == 2'b10) ? d : {WIDTH{1'b0}};
    assign y3 = (sel == 2'b11) ? d : {WIDTH{1'b0}};

endmodule
