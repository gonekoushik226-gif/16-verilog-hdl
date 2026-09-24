`timescale 1ns / 1ps

// edge_detector: produces a single-cycle pulse on rising, falling, or
// either edge of sig_in. Two flip-flop stages are used, not one:
// sig_sync registers the raw input, and sig_prev registers sig_sync
// one cycle later. Comparing two *registered* signals (sig_sync,
// sig_prev) rather than combining the live, unregistered sig_in with a
// single delayed copy is what gives a clean, stable, exactly-one-cycle
// pulse -- comparing a combinational signal against a registered one
// updating on the very same edge produces only a delta-cycle glitch
// that disappears before the end of that same clock edge, not a
// checkable pulse (this was an actual bug in an earlier version of this
// module, caught by this program's own testbench and documented in
// README.md SS13).
module edge_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire sig_in,
    output wire rising,
    output wire falling,
    output wire any_edge
);

    reg sig_sync, sig_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sig_sync <= 1'b0;
            sig_prev <= 1'b0;
        end else begin
            sig_sync <= sig_in;
            sig_prev <= sig_sync;
        end
    end

    assign rising   = sig_sync & ~sig_prev;
    assign falling  = ~sig_sync & sig_prev;
    assign any_edge = sig_sync ^ sig_prev;

endmodule
