`timescale 1ns / 1ps

// flag_unit: derives the final flag set from the ALU's selected result.
// zero/negative are computed fresh from the result on every operation;
// carry/overflow are simply passed through from whichever unit produced
// them (0 from logic_unit/shift_unit, since neither has carry/overflow
// meaning), centralizing flag generation in one place instead of
// duplicating the zero/negative computation per unit.
module flag_unit (
    input  wire [7:0] result,
    input  wire        carry_in,
    input  wire        overflow_in,
    output wire        zero,
    output wire        negative,
    output wire        carry_out,
    output wire        overflow_out
);

    assign zero         = (result == 8'b0);
    assign negative     = result[7];
    assign carry_out    = carry_in;
    assign overflow_out = overflow_in;

endmodule
