`timescale 1ns / 1ps

// booth_encoder: modified radix-4 Booth decoder for one 3-bit window
// (b2=b[2k+1], b1=b[2k], b0=b[2k-1], the overlapping bit from the group
// below). Each 3-bit pattern selects a signed digit in {-2,-1,0,+1,+2}
// for this group's partial-product row, decomposed here into a
// magnitude select (x1=1x, x2=2x, neither=0x) and a sign flag (neg).
module booth_encoder (
    input  wire b2,
    input  wire b1,
    input  wire b0,
    output reg  neg,   // 1: this row's contribution is negated
    output reg  x1,    // 1: row magnitude = 1x multiplicand
    output reg  x2     // 1: row magnitude = 2x multiplicand
);

    always @(*) begin
        neg = 1'b0;
        x1  = 1'b0;
        x2  = 1'b0;
        case ({b2, b1, b0})
            3'b000: begin neg = 1'b0; x1 = 1'b0; x2 = 1'b0; end   // 0
            3'b001: begin neg = 1'b0; x1 = 1'b1; x2 = 1'b0; end   // +1
            3'b010: begin neg = 1'b0; x1 = 1'b1; x2 = 1'b0; end   // +1
            3'b011: begin neg = 1'b0; x1 = 1'b0; x2 = 1'b1; end   // +2
            3'b100: begin neg = 1'b1; x1 = 1'b0; x2 = 1'b1; end   // -2
            3'b101: begin neg = 1'b1; x1 = 1'b1; x2 = 1'b0; end   // -1
            3'b110: begin neg = 1'b1; x1 = 1'b1; x2 = 1'b0; end   // -1
            3'b111: begin neg = 1'b0; x1 = 1'b0; x2 = 1'b0; end   // 0
            default: begin neg = 1'b0; x1 = 1'b0; x2 = 1'b0; end
        endcase
    end

endmodule
