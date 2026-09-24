`timescale 1ns / 1ps

// gray2bin_gen: Gray code to binary. Each binary bit depends on the binary
// bit above it, so the generate loop builds an XOR chain from the MSB down.
module gray2bin_gen #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] gray,
    output wire [WIDTH-1:0] bin
);

    assign bin[WIDTH-1] = gray[WIDTH-1];

    genvar i;
    generate
        for (i = WIDTH - 2; i >= 0; i = i - 1) begin : g_bit
            assign bin[i] = bin[i + 1] ^ gray[i];
        end
    endgenerate

endmodule
