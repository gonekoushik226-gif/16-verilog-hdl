`timescale 1ns / 1ps

// majority_behavioral: the same 3-input majority function expressed as an
// algorithm ("count the 1s, compare to a threshold") in an always block —
// the highest level of abstraction, closest to how a designer thinks about
// the requirement.
module majority_behavioral (
    input  wire a,
    input  wire b,
    input  wire c,
    output reg  y
);

    reg [1:0] ones;

    always @(*) begin
        ones = a + b + c;   // 1-bit inputs summed into a 2-bit count (0..3)
        y = (ones >= 2'd2);
    end

endmodule
