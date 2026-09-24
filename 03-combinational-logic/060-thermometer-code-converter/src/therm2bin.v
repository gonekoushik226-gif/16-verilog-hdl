`timescale 1ns / 1ps

// therm2bin: converts a WIDTH-bit thermometer code back to a binary count.
// The count is computed as a population count (number of 1 bits), which
// is the standard flash-ADC decoding technique precisely because it is
// tolerant of a single stray "bubble" (a 0 among the 1s, or a 1 among the
// 0s) caused by comparator metastability or noise — the count is still
// meaningful even when the code is not perfectly monotonic. `bubble`
// separately flags whenever the received code is not the canonical
// monotonic form for its own popcount, so a consumer can tell a clean
// reading from a corrected one.
module therm2bin #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]           therm,
    output reg  [$clog2(WIDTH+1)-1:0] bin,
    output reg                        bubble
);

    localparam BW = $clog2(WIDTH+1);

    integer i;

    always @(*) begin
        bin = {BW{1'b0}};
        for (i = 0; i < WIDTH; i = i + 1)
            bin = bin + {{(BW-1){1'b0}}, therm[i]};

        bubble = 1'b0;
        for (i = 0; i < WIDTH; i = i + 1)
            if (therm[i] != (i < bin))
                bubble = 1'b1;
    end

endmodule
