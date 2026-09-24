`timescale 1ns / 1ps

// comparator_n: width- and sign-generic magnitude comparator. Unlike the
// cell-cascaded comparator4 (program 046), this compares the two full
// buses in one relational expression, selecting a signed or unsigned
// interpretation of the bits at elaboration time via the SIGNED parameter.
module comparator_n #(
    parameter WIDTH  = 4,
    parameter SIGNED = 0     // 0 = unsigned compare, 1 = two's-complement signed compare
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output reg              gt,
    output reg              lt,
    output reg              eq
);

    always @(*) begin
        gt = 1'b0;
        lt = 1'b0;
        eq = 1'b0;
        if (SIGNED) begin
            // $signed() reinterprets the same bits as two's-complement
            // before the relational operators compare them
            if ($signed(a) > $signed(b))      gt = 1'b1;
            else if ($signed(a) < $signed(b)) lt = 1'b1;
            else                               eq = 1'b1;
        end else begin
            if (a > b)      gt = 1'b1;
            else if (a < b) lt = 1'b1;
            else             eq = 1'b1;
        end
    end

endmodule
