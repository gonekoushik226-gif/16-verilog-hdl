`timescale 1ns / 1ps

// seq_circuit: a small hand-built sequential circuit -- two D flip-flops
// (state q1,q0) plus combinational next-state logic and an output gate
// -- of exactly the kind a "clocked sequential circuit analysis"
// exercise starts from. Given only the gate equations below, the
// state table/next-state equations a student would derive by hand are
// precisely:
//
//   d1 = q1 XOR (q0 AND x)
//   d0 = NOT(q0) OR (q1 AND NOT x)
//   y  = q1 AND q0            (Moore output: depends on state only)
//
// This program's testbench directly forces every (q1,q0) state via
// hierarchical `force`, applies both values of x, and checks the
// resulting next state and output against exactly these equations --
// i.e. it verifies the derived state table is correct for the whole
// state/input space, not just whatever sequence a normal walk through
// the FSM would reach.
module seq_circuit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       x,
    output wire       y,
    output wire [1:0] state
);

    wire q1, q0;
    wire d1, d0;

    assign d1 = q1 ^ (q0 & x);
    assign d0 = (~q0) | (q1 & ~x);

    d_ff ff1 (.clk(clk), .rst_n(rst_n), .d(d1), .q(q1));
    d_ff ff0 (.clk(clk), .rst_n(rst_n), .d(d0), .q(q0));

    assign y     = q1 & q0;
    assign state = {q1, q0};

endmodule
