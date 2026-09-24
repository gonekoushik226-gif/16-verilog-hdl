`timescale 1ns / 1ps

// door_monitor: registers the raw door sensor so the rest of the
// design (and the timer's `pause` input) reacts to a clean, one-cycle-
// delayed, glitch-free `door_open` level rather than the asynchronous
// input directly.
module door_monitor (
    input  wire clk,
    input  wire rst_n,
    input  wire door_open_raw,
    output reg  door_open
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) door_open <= 1'b0;
        else        door_open <= door_open_raw;
    end

endmodule
