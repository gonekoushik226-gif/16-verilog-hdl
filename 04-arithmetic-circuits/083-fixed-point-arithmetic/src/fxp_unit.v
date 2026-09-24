`timescale 1ns / 1ps

// fxp_unit: combines the saturating add and rounding-saturating
// multiply into one opcode-selected fixed-point arithmetic unit.
module fxp_unit #(
    parameter WIDTH = 8,
    parameter FRAC  = 4
) (
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    input  wire                     op,   // 0 = add, 1 = multiply
    output wire signed [WIDTH-1:0] result,
    output wire                     overflow
);

    wire signed [WIDTH-1:0] add_result, mul_result;
    wire                     add_overflow, mul_overflow;

    fxp_add_sat #(.WIDTH(WIDTH), .FRAC(FRAC)) u_add (
        .a(a), .b(b), .result(add_result), .overflow(add_overflow)
    );
    fxp_mul #(.WIDTH(WIDTH), .FRAC(FRAC)) u_mul (
        .a(a), .b(b), .result(mul_result), .overflow(mul_overflow)
    );

    assign result   = op ? mul_result   : add_result;
    assign overflow = op ? mul_overflow : add_overflow;

endmodule
