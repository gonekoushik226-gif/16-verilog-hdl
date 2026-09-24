`timescale 1ns / 1ps

// pedestrian_request: latches a momentary button press (`req_btn`) into
// `req_pending` until the controller services it and pulses `clear`.
// Multiple presses before service collapse into a single pending
// request, matching a real crosswalk button.
module pedestrian_request (
    input  wire clk,
    input  wire rst_n,
    input  wire req_btn,
    input  wire clear,
    output reg  req_pending
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      req_pending <= 1'b0;
        else if (clear)  req_pending <= 1'b0;
        else if (req_btn) req_pending <= 1'b1;
    end

endmodule
