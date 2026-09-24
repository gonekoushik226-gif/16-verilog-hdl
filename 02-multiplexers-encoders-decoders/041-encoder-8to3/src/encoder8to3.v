`timescale 1ns / 1ps

// encoder8to3: 8-to-3 binary encoder. Converts a strictly one-hot input d
// into the binary index of its set bit. Any input that is not one-hot
// (all-zero, or more than one bit set) is flagged invalid via `valid`,
// and y is forced to a known value rather than left undefined.
module encoder8to3 (
    input  wire [7:0] d,
    output reg  [2:0] y,
    output reg        valid
);

    always @(*) begin
        y     = 3'b000;    // default assignment: avoids an inferred latch
        valid = 1'b1;
        case (d)
            8'b0000_0001: y = 3'd0;
            8'b0000_0010: y = 3'd1;
            8'b0000_0100: y = 3'd2;
            8'b0000_1000: y = 3'd3;
            8'b0001_0000: y = 3'd4;
            8'b0010_0000: y = 3'd5;
            8'b0100_0000: y = 3'd6;
            8'b1000_0000: y = 3'd7;
            default: begin
                y     = 3'b000;
                valid = 1'b0;
            end
        endcase
    end

endmodule
