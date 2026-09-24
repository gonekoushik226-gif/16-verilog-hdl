`timescale 1ns / 1ps

// parity_checker: receive-side counterpart of parity_generator. Recomputes
// the expected parity bit for the received data and flags `error` when the
// received parity bit disagrees — which happens for any single-bit flip
// anywhere in {data, parity_in}, since one bit flip always changes the
// total number of 1s from even to odd or vice versa.
module parity_checker #(
    parameter WIDTH = 8,
    parameter ODD   = 0     // must match the ODD setting used to generate parity_in
) (
    input  wire [WIDTH-1:0] data,
    input  wire             parity_in,
    output wire             error
);

    wire expected_parity = ODD ? ~(^data) : (^data);

    assign error = (parity_in != expected_parity);

endmodule
