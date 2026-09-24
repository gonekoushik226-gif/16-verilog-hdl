`timescale 1ns / 1ps

// bcd_counter_3digit: three cascaded bcd_counter digits (ones, tens,
// hundreds) counting 000-999. Each digit's carry_out enables the next,
// more-significant digit -- since carry_out is combinational and high
// throughout the cycle a digit sits at 9 while enabled, the next digit
// sees a valid enable in time to increment on the very same clock edge
// the current digit wraps, giving a normal synchronous 000..999 count
// with no extra ripple delay across digits.
module bcd_counter_3digit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output wire [3:0] ones,
    output wire [3:0] tens,
    output wire [3:0] hundreds,
    output wire       carry_out   // pulses the cycle the count wraps 999 -> 000
);

    wire c_ones, c_tens;

    bcd_counter u_ones (.clk(clk), .rst_n(rst_n), .en(en),      .count(ones),     .carry_out(c_ones));
    bcd_counter u_tens (.clk(clk), .rst_n(rst_n), .en(c_ones),  .count(tens),     .carry_out(c_tens));
    bcd_counter u_hund (.clk(clk), .rst_n(rst_n), .en(c_tens),  .count(hundreds), .carry_out(carry_out));

endmodule
