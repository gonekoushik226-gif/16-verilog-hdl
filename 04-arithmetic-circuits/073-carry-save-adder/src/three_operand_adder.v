`timescale 1ns / 1ps

// three_operand_adder: adds three WIDTH-bit numbers using one carry-save
// layer plus one final carry-propagate adder — only two sequential
// addition delays in total, regardless of WIDTH, versus chaining two
// ordinary WIDTH-bit adders (which would cost two full ripple delays).
// This is the core idea multi-operand reduction trees (Wallace trees,
// multiplier partial-product summation) build on: use carry-save stages
// to reduce N operands to 2, and pay the ripple-carry cost only once, at
// the very end.
module three_operand_adder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]   a,
    input  wire [WIDTH-1:0]   b,
    input  wire [WIDTH-1:0]   c,
    output wire [WIDTH+1:0]   sum   // wide enough for 3*(2^WIDTH-1), no overflow
);

    wire [WIDTH-1:0] csum, ccarry;
    csa_layer #(.WIDTH(WIDTH)) csa (.x(a), .y(b), .z(c), .sum(csum), .carry(ccarry));

    // csum is at its natural bit weight; ccarry must be shifted left one
    // position (each saved carry bit belongs to the next-higher weight)
    // before the two are finally combined with an ordinary ripple add.
    wire [WIDTH+1:0] op1 = {2'b00, csum};
    wire [WIDTH+1:0] op2 = {1'b0, ccarry, 1'b0};

    wire [WIDTH+2:0] fcarry;
    assign fcarry[0] = 1'b0;

    genvar i;
    generate
        for (i = 0; i < WIDTH + 2; i = i + 1) begin : final_stage
            full_adder fa (.a(op1[i]), .b(op2[i]), .cin(fcarry[i]),
                            .sum(sum[i]), .carry_out(fcarry[i+1]));
        end
    endgenerate

endmodule
