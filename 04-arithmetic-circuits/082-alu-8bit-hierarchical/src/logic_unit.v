`timescale 1ns / 1ps

// logic_unit: the bitwise-logic half of the hierarchical ALU.
module logic_unit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [1:0] sel,   // 00=AND 01=OR 10=XOR 11=NOT(a)
    output reg  [7:0] result
);

    always @(*) begin
        case (sel)
            2'b00:   result = a & b;
            2'b01:   result = a | b;
            2'b10:   result = a ^ b;
            2'b11:   result = ~a;
            default: result = 8'b0;
        endcase
    end

endmodule
