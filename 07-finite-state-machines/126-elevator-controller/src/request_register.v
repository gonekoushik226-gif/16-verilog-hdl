`timescale 1ns / 1ps

// request_register: one sticky request bit per floor. A bit is set by
// `request_in` (level-true for one or more cycles is fine; setting an
// already-set bit is harmless) and cleared by `clear_mask` (pulsed by
// the controller for the floor just arrived at). If both are asserted
// for the same bit on the same cycle, clear wins -- a floor being
// serviced this cycle should not immediately re-arm itself from a
// simultaneous new request for that same floor.
module request_register #(
    parameter FLOORS = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [FLOORS-1:0] request_in,
    input  wire [FLOORS-1:0] clear_mask,
    output reg  [FLOORS-1:0] pending
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pending <= {FLOORS{1'b0}};
        else        pending <= (pending | request_in) & ~clear_mask;
    end

endmodule
