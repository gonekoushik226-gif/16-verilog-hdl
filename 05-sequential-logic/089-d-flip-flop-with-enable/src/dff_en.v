`timescale 1ns / 1ps

// dff_en: D flip-flop with a synchronous clock-enable. When en=0, a
// clock edge arrives but q simply keeps its old value -- the enable
// gates whether the edge has any effect at all, distinct from a
// synchronous reset (program 088), which forces a specific value
// rather than holding the current one.
module dff_en (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    input  wire d,
    output reg  q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)   q <= 1'b0;
        else if (en)  q <= d;
        // else: en=0, hold -- q keeps its value across this edge
    end

endmodule
