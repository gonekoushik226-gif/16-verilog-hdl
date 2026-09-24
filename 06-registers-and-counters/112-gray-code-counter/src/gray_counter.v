`timescale 1ns / 1ps

// gray_counter: counts through all 2^WIDTH Gray-code values, each
// differing from the previous by exactly one bit. Built from a plain
// internal binary counter plus the standard binary-to-Gray conversion
// (gray = binary XOR (binary >> 1)) applied every cycle, rather than
// deriving Gray-code next-state logic directly.
module gray_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output wire [WIDTH-1:0] gray_count
);

    reg [WIDTH-1:0] bin;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  bin <= {WIDTH{1'b0}};
        else if (en) bin <= bin + 1'b1;
    end

    assign gray_count = bin ^ (bin >> 1);

endmodule
