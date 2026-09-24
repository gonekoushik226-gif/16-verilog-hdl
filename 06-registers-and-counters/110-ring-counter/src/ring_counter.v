`timescale 1ns / 1ps

// ring_counter: a WIDTH-bit one-hot ring counter -- exactly one bit is
// 1, rotating one position every enabled cycle. The feedback bit is not
// a plain wraparound (which would never recover from an invalid
// power-up state); it is NOR of every bit except the one about to be
// discarded (q[WIDTH-2:0]), which self-corrects: from all-zero it
// injects a new 1; from any state with more than one bit set it
// converges to a valid one-hot state within a few cycles (see
// README.md SS13 for a worked trace of both cases).
module ring_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] q
);

    wire feedback = ~(|q[WIDTH-2:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  q <= {{(WIDTH-1){1'b0}}, 1'b1};
        else if (en) q <= {q[WIDTH-2:0], feedback};
    end

endmodule
