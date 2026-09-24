`timescale 1ns / 1ps

// gray2bin: inverse of bin2gray. Undoing the XOR-with-shifted-self
// construction requires a running (prefix) XOR from the MSB down, since
// each binary bit depends on every gray bit at or above its own position:
// bin[i] = gray[WIDTH-1] ^ gray[WIDTH-2] ^ ... ^ gray[i].
// This is computed here as a ripple: bin[MSB] = gray[MSB], then each lower
// bin bit is the previous (more-significant) bin bit XORed with its own
// gray bit — an unrolled combinational XOR chain, not a clocked loop.
module gray2bin #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] gray,
    output reg  [WIDTH-1:0] bin
);

    integer i;

    always @(*) begin
        bin[WIDTH-1] = gray[WIDTH-1];
        for (i = WIDTH - 2; i >= 0; i = i - 1)
            bin[i] = bin[i+1] ^ gray[i];
    end

endmodule
