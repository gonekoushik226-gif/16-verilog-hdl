`timescale 1ns / 1ps

// bcd_counter: a single BCD digit counter, 0-9, wrapping back to 0.
// carry_out is combinational (not registered): it is high throughout
// the cycle the counter is at 9 and enabled, exactly the pulse needed
// to enable a next, more-significant digit's counter on the same clock
// edge this digit wraps (see program 109's cascade).
module bcd_counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output reg  [3:0] count,
    output wire       carry_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 4'd0;
        else if (en) begin
            if (count == 4'd9) count <= 4'd0;
            else               count <= count + 4'd1;
        end
    end

    assign carry_out = en & (count == 4'd9);

endmodule
