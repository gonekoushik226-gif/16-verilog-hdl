`timescale 1ns / 1ps

// rca_n: WIDTH-bit ripple-carry adder (same design as program 065),
// used here as the building block for each carry-select segment.
module rca_n #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             carry_out
);

    wire [WIDTH:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : stage
            full_adder fa (
                .a(a[i]), .b(b[i]), .cin(carry[i]),
                .sum(sum[i]), .carry_out(carry[i+1])
            );
        end
    endgenerate

    assign carry_out = carry[WIDTH];

endmodule
