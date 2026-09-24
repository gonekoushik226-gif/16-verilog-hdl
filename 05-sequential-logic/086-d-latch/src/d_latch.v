`timescale 1ns / 1ps

// d_latch: level-sensitive D latch. While en=1 the latch is
// "transparent" -- q follows d immediately, with no clock edge
// involved. While en=0 the latch holds its last value. The missing
// `else` in the always block is deliberate: it is exactly what
// describes "hold when not enabled" and is what synthesis correctly
// reads as a latch (see program.conf: ALLOW_LATCH=yes, since this
// program's entire point is a level-sensitive storage element).
module d_latch (
    input  wire d,
    input  wire en,
    output reg  q
);

    always @(*) begin
        if (en) q = d;
    end

endmodule
