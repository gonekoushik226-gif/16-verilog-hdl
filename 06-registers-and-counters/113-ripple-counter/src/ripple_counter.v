`timescale 1ns / 1ps

// ripple_counter: an ASYNCHRONOUS (ripple) binary counter -- a
// deliberate exception to this repository's default fully-synchronous
// style (CLAUDE.md SS4), built specifically to show why ripple counters
// are avoided in synchronous designs. Bit 0 toggles on the real clock;
// every other bit's t_ff is clocked not by `clk` but by the *previous
// bit's own output*, so each bit only updates after the bit below it
// has already toggled -- a chain of cascaded clock-to-output delays
// ("ripple") rather than every bit updating simultaneously from one
// shared clock edge, as every other counter in this category does.
//
// Each cascaded stage triggers on the FALLING edge of the bit below it
// (`~q[i-1]`, so a negedge of q[i-1] becomes a posedge t_ff can trigger
// on), not the rising edge. This is deliberate, not arbitrary: a T
// flip-flop chain triggered on each stage's rising edge produces a DOWN
// counter, not an up counter -- a classic, easy-to-get-backwards fact
// about ripple counters (see README.md SS14) caught by this program's
// own testbench during development.
module ripple_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    output wire [WIDTH-1:0] q
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : stage
            if (i == 0)
                t_ff u (.clk(clk),      .rst_n(rst_n), .q(q[i]));
            else
                t_ff u (.clk(~q[i-1]),  .rst_n(rst_n), .q(q[i]));
        end
    endgenerate

endmodule
