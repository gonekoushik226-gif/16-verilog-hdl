`timescale 1ns / 1ps

// t_ff: a toggle flip-flop with T permanently tied to 1 by every
// instance in ripple_counter.v -- each bit simply divides its own
// clock input by 2 (same design as program 091, T=1 fixed).
module t_ff (
    input  wire clk,
    input  wire rst_n,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else        q <= ~q;
    end

endmodule
