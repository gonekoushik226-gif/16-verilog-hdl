`timescale 1ns / 1ps

// alu4: minimal 4-bit ALU combining the arithmetic (068) and logic
// (category 01) operations built earlier in this repository behind a
// single opcode-decoded interface, with a standard carry/overflow/
// zero/negative flag set.
module alu4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] opcode,
    output reg  [3:0] result,
    output reg        carry,      // valid for ADD/SUB only
    output reg        overflow,   // valid for ADD/SUB only
    output wire       zero,
    output wire       negative
);

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_AND = 3'b010;
    localparam OP_OR  = 3'b011;
    localparam OP_XOR = 3'b100;
    localparam OP_NOT = 3'b101;
    localparam OP_SHL = 3'b110;
    localparam OP_SHR = 3'b111;

    reg [4:0] ext;

    always @(*) begin
        result   = 4'b0000;
        carry    = 1'b0;
        overflow = 1'b0;
        ext      = 5'b0;
        case (opcode)
            OP_ADD: begin
                ext      = {1'b0, a} + {1'b0, b};
                result   = ext[3:0];
                carry    = ext[4];
                overflow = (a[3] == b[3]) && (result[3] != a[3]);
            end
            OP_SUB: begin
                // two's-complement subtract via a widened minuend, same
                // technique as program 068: ext[4]=1 means "no borrow".
                ext      = {1'b1, a} - {1'b0, b};
                result   = ext[3:0];
                carry    = ext[4];
                overflow = (a[3] != b[3]) && (result[3] != a[3]);
            end
            OP_AND:  result = a & b;
            OP_OR:   result = a | b;
            OP_XOR:  result = a ^ b;
            OP_NOT:  result = ~a;
            OP_SHL:  result = a << 1;
            OP_SHR:  result = a >> 1;
            default: result = 4'b0000;
        endcase
    end

    assign zero     = (result == 4'b0000);
    assign negative = result[3];

endmodule
