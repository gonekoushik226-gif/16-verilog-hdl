`timescale 1ns / 1ps

// bin2gray_gen: binary to Gray code, one XOR per bit built with generate-for
module bin2gray_gen #(
    parameter WIDTH = 4
) (
    input  wire [WIDTH-1:0] bin,
    output wire [WIDTH-1:0] gray
);

    assign gray[WIDTH-1] = bin[WIDTH-1];   // MSB is copied

    genvar i;
    generate
        for (i = 0; i < WIDTH - 1; i = i + 1) begin : g_bit
            assign gray[i] = bin[i + 1] ^ bin[i];
        end
    endgenerate

endmodule
