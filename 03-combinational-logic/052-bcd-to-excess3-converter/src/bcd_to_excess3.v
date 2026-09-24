`timescale 1ns / 1ps

// bcd_to_excess3: converts a 4-bit BCD digit (0-9) to Excess-3 code
// (BCD value + 3), a self-complementing code historically used in early
// decimal adders. Codes 10-15 are not valid BCD digits, so they are
// flagged with `invalid` instead of silently producing a code.
module bcd_to_excess3 (
    input  wire [3:0] bcd,
    output reg  [3:0] excess3,
    output reg         invalid
);

    always @(*) begin
        invalid = 1'b0;
        excess3 = 4'd0;
        if (bcd <= 4'd9) begin
            excess3 = bcd + 4'd3;
        end else begin
            invalid = 1'b1;
        end
    end

endmodule
