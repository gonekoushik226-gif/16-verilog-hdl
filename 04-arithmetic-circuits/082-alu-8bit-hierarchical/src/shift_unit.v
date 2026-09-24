`timescale 1ns / 1ps

// shift_unit: the shift/rotate half of the hierarchical ALU. Shift/
// rotate amount comes from the caller (this ALU uses b[2:0], letting
// the same operand port double as a variable shift count).
module shift_unit (
    input  wire [7:0] a,
    input  wire [2:0] amount,
    input  wire [1:0] sel,   // 00=SHL 01=SHR 10=ROL 11=ROR
    output reg  [7:0] result
);

    always @(*) begin
        case (sel)
            2'b00:   result = a << amount;
            2'b01:   result = a >> amount;
            2'b10:   result = (a << amount) | (a >> (4'd8 - amount));
            2'b11:   result = (a >> amount) | (a << (4'd8 - amount));
            default: result = 8'b0;
        endcase
    end

endmodule
