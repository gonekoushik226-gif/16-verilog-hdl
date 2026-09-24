`timescale 1ns / 1ps

// param_top
// Three instances of the same counter with different parameters:
//   u_tenths  : MODULUS 10 -> 4-bit count 0..9
//   u_seconds : MODULUS 60 -> 6-bit count 0..59, advances when tenths wraps
//   u_hex     : MODULUS 16 -> 4-bit count 0..15 (full binary range)
module param_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output wire [3:0] tenths,
    output wire [5:0] seconds,
    output wire [3:0] hex_count,
    output wire       minute_tick     // seconds counter wraps
);

    wire tenths_wrap;

    param_counter #(.MODULUS(10)) u_tenths (
        .clk(clk), .rst_n(rst_n), .en(en),
        .count(tenths), .wrap(tenths_wrap)
    );

    param_counter #(.MODULUS(60)) u_seconds (
        .clk(clk), .rst_n(rst_n), .en(tenths_wrap),
        .count(seconds), .wrap(minute_tick)
    );

    param_counter #(.MODULUS(16)) u_hex (
        .clk(clk), .rst_n(rst_n), .en(en),
        .count(hex_count), .wrap()             // wrap output intentionally unused
    );

endmodule
