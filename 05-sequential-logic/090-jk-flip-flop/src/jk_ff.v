`timescale 1ns / 1ps

// jk_ff: clocked JK flip-flop. Unlike the SR latch's forbidden J=K=1
// case, a JK flip-flop defines J=K=1 as toggle -- the extra state
// (edge-triggered, sampled once per clock) removes the ambiguity that
// makes S=R=1 problematic for a level-sensitive SR latch.
module jk_ff (
    input  wire clk,
    input  wire rst_n,
    input  wire j,
    input  wire k,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else begin
            case ({j, k})
                2'b00: q <= q;      // hold
                2'b01: q <= 1'b0;   // reset
                2'b10: q <= 1'b1;   // set
                2'b11: q <= ~q;     // toggle
            endcase
        end
    end

endmodule
