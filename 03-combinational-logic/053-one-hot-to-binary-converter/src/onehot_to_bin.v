`timescale 1ns / 1ps

// onehot_to_bin: width-generic one-hot to binary converter built as an
// OR-tree rather than an enumerated case statement (contrast with
// encoder8to3 in category 02, which lists every valid code explicitly).
// For a genuine one-hot input only one term of the OR contributes, so
// ORing every set bit's own index together correctly recovers that bit's
// position; `valid` is derived separately from an explicit population
// count so a caller can tell a real one-hot code from a coincidental
// OR-tree result on a malformed (multi-bit or all-zero) input.
module onehot_to_bin #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]        onehot,
    output reg  [$clog2(WIDTH)-1:0] bin,
    output reg                      valid
);

    localparam BIN_WIDTH = $clog2(WIDTH);

    integer i;
    integer ones;

    always @(*) begin
        bin  = {BIN_WIDTH{1'b0}};
        ones = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (onehot[i]) begin
                bin  = bin | i[BIN_WIDTH-1:0];   // OR-tree: set bit's index contributes
                ones = ones + 1;
            end
        end
        valid = (ones == 1);
    end

endmodule
