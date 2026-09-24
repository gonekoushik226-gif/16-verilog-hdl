`timescale 1ns / 1ps

// procedural_demo
// The same "reg" keyword used for two very different pieces of hardware:
//   max_ab : combinational logic described in an always @(*) block
//   max_q  : a flip-flop register described in an always @(posedge clk) block
module procedural_demo (
    input  wire       clk,
    input  wire       rst_n,     // asynchronous, active-low reset
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [3:0] max_ab,    // larger of a and b, updates immediately
    output reg  [3:0] max_q      // max_ab captured on the rising clock edge
);

    // Combinational: re-evaluated whenever a or b changes. Every path assigns
    // max_ab, so no storage (latch) is implied.
    always @(*) begin
        if (a > b)
            max_ab = a;
        else
            max_ab = b;
    end

    // Sequential: executes only on a rising clock edge or when reset asserts.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            max_q <= 4'd0;
        else
            max_q <= max_ab;
    end

endmodule
