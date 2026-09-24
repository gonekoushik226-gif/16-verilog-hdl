`timescale 1ns / 1ps

// bcd_counter: single BCD digit counter (same design as program 108),
// reused here as the per-digit building block of a cascaded 3-digit
// counter.
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
