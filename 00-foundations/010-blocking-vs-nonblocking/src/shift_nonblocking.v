`timescale 1ns / 1ps

// shift_nonblocking
// Three-stage shift register written correctly with non-blocking
// assignments. All right-hand sides are sampled before any register is
// updated, so each stage receives the previous value of the stage before it.
module shift_nonblocking (
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  q1,
    output reg  q2,
    output reg  q3
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 1'b0;
            q2 <= 1'b0;
            q3 <= 1'b0;
        end else begin
            q1 <= din;
            q2 <= q1;
            q3 <= q2;
        end
    end

endmodule
