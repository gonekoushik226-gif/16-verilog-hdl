`timescale 1ns / 1ps

// t_ff: clocked T (toggle) flip-flop. T=1 toggles q every clock edge;
// T=0 holds. Tying t=1 permanently turns this into a divide-by-2
// clock/frequency divider, the simplest possible counter.
module t_ff (
    input  wire clk,
    input  wire rst_n,
    input  wire t,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else if (t) q <= ~q;
        // else: hold
    end

endmodule
