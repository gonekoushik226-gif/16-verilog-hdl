`timescale 1ns / 1ps

// gcd_datapath: two registers (a_reg, b_reg) implementing the
// subtraction-based Euclidean algorithm's storage and arithmetic. The
// controller decides, each cycle, whether to load new operands or
// subtract the smaller register from the larger. `result` reports
// whichever register is nonzero once the computation has converged
// (see gcd_controller.v for why this matters for zero operands).
module gcd_datapath #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             load,
    input  wire [WIDTH-1:0] a_in,
    input  wire [WIDTH-1:0] b_in,
    input  wire             sub_a,
    input  wire             sub_b,
    output wire              eq,
    output wire              a_gt_b,
    output wire              a_zero,
    output wire              b_zero,
    output wire [WIDTH-1:0]  result
);

    reg [WIDTH-1:0] a_reg, b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= {WIDTH{1'b0}};
            b_reg <= {WIDTH{1'b0}};
        end else if (load) begin
            a_reg <= a_in;
            b_reg <= b_in;
        end else if (sub_a) begin
            a_reg <= a_reg - b_reg;
        end else if (sub_b) begin
            b_reg <= b_reg - a_reg;
        end
    end

    assign eq     = (a_reg == b_reg);
    assign a_gt_b = (a_reg > b_reg);
    assign a_zero = (a_reg == {WIDTH{1'b0}});
    assign b_zero = (b_reg == {WIDTH{1'b0}});
    assign result  = a_zero ? b_reg : a_reg;

endmodule
