`timescale 1ns / 1ps

// bin2therm: converts a binary count (0..WIDTH) into WIDTH-bit thermometer
// code, where the low `bin` bits are 1 and the rest are 0 — the canonical
// form produced by, e.g., a flash-ADC comparator bank.
module bin2therm #(
    parameter WIDTH = 8
) (
    input  wire [$clog2(WIDTH+1)-1:0] bin,
    output reg  [WIDTH-1:0]           therm
);

    integer i;

    always @(*) begin
        for (i = 0; i < WIDTH; i = i + 1)
            therm[i] = (i < bin);
    end

endmodule
