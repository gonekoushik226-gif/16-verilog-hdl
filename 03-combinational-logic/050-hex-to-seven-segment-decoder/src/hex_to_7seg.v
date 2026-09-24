`timescale 1ns / 1ps

// hex_to_7seg: decodes a 4-bit hex nibble (0-F) to the seven active-low
// segment drives of a common-anode seven-segment display. seg is ordered
// {a,b,c,d,e,f,g} (MSB = segment a); a bit of 0 turns that segment on.
module hex_to_7seg (
    input  wire [3:0] hex,
    output reg  [6:0] seg
);

    always @(*) begin
        case (hex)
            //                 a b c d e f g
            4'h0: seg = 7'b0_0_0_0_0_0_1;
            4'h1: seg = 7'b1_0_0_1_1_1_1;
            4'h2: seg = 7'b0_0_1_0_0_1_0;
            4'h3: seg = 7'b0_0_0_0_1_1_0;
            4'h4: seg = 7'b1_0_0_1_1_0_0;
            4'h5: seg = 7'b0_1_0_0_1_0_0;
            4'h6: seg = 7'b0_1_0_0_0_0_0;
            4'h7: seg = 7'b0_0_0_1_1_1_1;
            4'h8: seg = 7'b0_0_0_0_0_0_0;
            4'h9: seg = 7'b0_0_0_0_1_0_0;
            4'hA: seg = 7'b0_0_0_1_0_0_0;
            4'hB: seg = 7'b1_1_0_0_0_0_0;
            4'hC: seg = 7'b0_1_1_0_0_0_1;
            4'hD: seg = 7'b1_0_0_0_0_1_0;
            4'hE: seg = 7'b0_1_1_0_0_0_0;
            4'hF: seg = 7'b0_1_1_1_0_0_0;
            default: seg = 7'b1_1_1_1_1_1_1;   // unreachable for a 4-bit input; kept per coding standard
        endcase
    end

endmodule
