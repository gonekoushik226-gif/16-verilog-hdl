`timescale 1ns / 1ps

// shifter: single-stage shifter driven directly by Verilog's shift
// operators, selectable between left (<<), logical right (>>), and
// arithmetic right (>>>) shift. Direction and type are runtime control
// inputs rather than parameters, since a real ALU shifter must switch
// mode per instruction.
module shifter #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]            data,
    input  wire [$clog2(WIDTH)-1:0]    shamt,
    input  wire                        left,   // 1 = shift left, 0 = shift right
    input  wire                        arith,  // right shift only: 1 = arithmetic (sign-extend), 0 = logical
    output reg  [WIDTH-1:0]            result
);

    always @(*) begin
        if (left)
            result = data << shamt;
        else if (arith)
            // $signed() makes >>> sign-extend from data's MSB instead of
            // shifting in zeros; left shift has no arithmetic/logical
            // distinction, so `arith` only affects the right-shift branch
            result = $signed(data) >>> shamt;
        else
            result = data >> shamt;
    end

endmodule
