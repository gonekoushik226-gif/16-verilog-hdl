`timescale 1ns / 1ps

// bin2bcd: converts an 8-bit binary value (0-255) to three BCD digits
// (hundreds, tens, units) using the shift-and-add-3 ("double dabble")
// algorithm, unrolled combinationally over a for loop instead of clocked
// one shift per cycle.
//
// Algorithm: hold a 20-bit register {hundreds, tens, units, remaining_bin}.
// Repeat WIDTH=8 times: if any BCD nibble is >= 5, add 3 to it (so that
// doubling it on the next shift cannot carry out of its 4-bit field into
// the wrong decimal weight), then shift the whole register left by one,
// moving the next unconsumed binary bit into the units nibble's LSB.
module bin2bcd (
    input  wire [7:0] bin,
    output wire [3:0] hundreds,
    output wire [3:0] tens,
    output wire [3:0] units
);

    localparam WIDTH = 8;

    // [19:16]=hundreds [15:12]=tens [11:8]=units [7:0]=binary bits not yet shifted in
    reg [WIDTH+11:0] shift_reg;
    integer i;

    always @(*) begin
        shift_reg = {12'b0, bin};
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (shift_reg[11:8] >= 5)
                shift_reg[11:8] = shift_reg[11:8] + 4'd3;
            if (shift_reg[15:12] >= 5)
                shift_reg[15:12] = shift_reg[15:12] + 4'd3;
            if (shift_reg[19:16] >= 5)
                shift_reg[19:16] = shift_reg[19:16] + 4'd3;
            shift_reg = shift_reg << 1;
        end
    end

    assign hundreds = shift_reg[19:16];
    assign tens     = shift_reg[15:12];
    assign units    = shift_reg[11:8];

endmodule
