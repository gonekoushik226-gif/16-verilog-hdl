`timescale 1ns / 1ps

// alu8: 8-bit hierarchical ALU. Three independent functional units
// (arithmetic, logic, shift) all compute in parallel every cycle; a
// result mux driven by opcode[3:2] then selects which unit's output
// (and which carry/overflow, if any) actually reaches the output, and
// flag_unit derives the final flag set from whichever result was
// selected. This mirrors how a real ALU is structured: separate
// execution units feeding a shared result/flag path, rather than one
// large `case` statement doing everything (contrast program 081).
module alu8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] opcode,   // [3:2] = unit select, [1:0] = op within unit
    output wire [7:0] result,
    output wire        carry,
    output wire        overflow,
    output wire        zero,
    output wire        negative
);

    localparam UNIT_ARITH = 2'b00;
    localparam UNIT_LOGIC = 2'b01;
    localparam UNIT_SHIFT = 2'b10;

    wire [7:0] arith_result, logic_result, shift_result;
    wire       arith_carry, arith_overflow;

    arith_unit u_arith (.a(a), .b(b), .sub(opcode[0]),
                         .result(arith_result), .carry(arith_carry), .overflow(arith_overflow));
    logic_unit u_logic (.a(a), .b(b), .sel(opcode[1:0]), .result(logic_result));
    shift_unit u_shift (.a(a), .amount(b[2:0]), .sel(opcode[1:0]), .result(shift_result));

    reg [7:0] mux_result;
    reg       mux_carry, mux_overflow;

    always @(*) begin
        mux_result   = 8'b0;
        mux_carry    = 1'b0;
        mux_overflow = 1'b0;
        case (opcode[3:2])
            UNIT_ARITH: begin
                mux_result   = arith_result;
                mux_carry    = arith_carry;
                mux_overflow = arith_overflow;
            end
            UNIT_LOGIC: mux_result = logic_result;
            UNIT_SHIFT: mux_result = shift_result;
            default:    mux_result = 8'b0;   // reserved unit-select value
        endcase
    end

    flag_unit u_flags (.result(mux_result), .carry_in(mux_carry), .overflow_in(mux_overflow),
                        .zero(zero), .negative(negative), .carry_out(carry), .overflow_out(overflow));

    assign result = mux_result;

endmodule
