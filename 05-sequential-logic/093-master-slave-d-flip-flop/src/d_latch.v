`timescale 1ns / 1ps

// d_latch: level-sensitive D latch (same design as program 086),
// reused here twice to build an edge-triggered flip-flop out of two
// latches.
module d_latch (
    input  wire d,
    input  wire en,
    output reg  q
);

    always @(*) begin
        if (en) q = d;
    end

endmodule
