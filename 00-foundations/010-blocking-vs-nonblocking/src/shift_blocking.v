`timescale 1ns / 1ps

// shift_blocking
// The same three statements written with BLOCKING assignments. Each
// assignment completes before the next line executes, so q2 sees the NEW q1
// and q3 sees the NEW q2: all three stages receive din on the same edge and
// the "shift register" collapses into a single stage.
// This module is intentionally wrong; it exists to demonstrate the bug.
module shift_blocking (
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  q1,
    output reg  q2,
    output reg  q3
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 = 1'b0;
            q2 = 1'b0;
            q3 = 1'b0;
        end else begin
            q1 = din;
            q2 = q1;   // already equals din
            q3 = q2;   // already equals din
        end
    end

endmodule
