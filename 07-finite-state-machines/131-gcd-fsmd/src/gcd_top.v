`timescale 1ns / 1ps

// gcd_top: connects gcd_controller and gcd_datapath into a complete
// FSMD (finite state machine with datapath) computing gcd(a_in,b_in)
// via repeated subtraction, one subtraction per clock cycle.
module gcd_top #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] a_in,
    input  wire [WIDTH-1:0] b_in,
    output wire             done,
    output wire             busy,
    output wire [WIDTH-1:0] result
);

    wire load, sub_a, sub_b, eq, a_gt_b, a_zero, b_zero;

    gcd_datapath #(.WIDTH(WIDTH)) u_dp (
        .clk(clk), .rst_n(rst_n),
        .load(load), .a_in(a_in), .b_in(b_in),
        .sub_a(sub_a), .sub_b(sub_b),
        .eq(eq), .a_gt_b(a_gt_b), .a_zero(a_zero), .b_zero(b_zero),
        .result(result)
    );

    gcd_controller u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start),
        .eq(eq), .a_gt_b(a_gt_b), .a_zero(a_zero), .b_zero(b_zero),
        .load(load), .sub_a(sub_a), .sub_b(sub_b),
        .done(done), .busy(busy)
    );

endmodule
