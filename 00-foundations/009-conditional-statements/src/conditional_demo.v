`timescale 1ns / 1ps

// conditional_demo
// The four ways to describe choices in Verilog:
//   ?:      conditional operator (continuous assignment)   -> 2:1 mux
//   if/else priority chain                                 -> priority logic
//   casez   with wildcards                                 -> same priority logic
//   case    on a selector with a default                   -> parallel mux
module conditional_demo (
    input  wire [1:0] a,
    input  wire [1:0] b,
    input  wire       sel,
    input  wire [3:0] req,          // request lines, req[3] has highest priority
    input  wire [1:0] op,
    output wire [1:0] mux_out,      // sel ? a : b
    output reg  [1:0] prio_if,      // index of highest active req (if/else)
    output reg  [1:0] prio_casez,   // same function written with casez
    output reg        prio_valid,   // at least one req is active
    output reg  [1:0] alu_out       // op: 0 AND, 1 OR, 2 XOR, 3 ADD (mod 4)
);

    assign mux_out = sel ? a : b;

    // if/else chain: the first true condition wins, giving req[3] priority
    always @(*) begin
        prio_valid = 1'b1;
        if (req[3])      prio_if = 2'd3;
        else if (req[2]) prio_if = 2'd2;
        else if (req[1]) prio_if = 2'd1;
        else if (req[0]) prio_if = 2'd0;
        else begin
            prio_if    = 2'd0;
            prio_valid = 1'b0;
        end
    end

    // casez: '?' marks don't-care bits; items are checked in order
    always @(*) begin
        casez (req)
            4'b1???: prio_casez = 2'd3;
            4'b01??: prio_casez = 2'd2;
            4'b001?: prio_casez = 2'd1;
            default: prio_casez = 2'd0;   // 0001 and 0000
        endcase
    end

    // case: every op value selects one operation
    always @(*) begin
        case (op)
            2'd0:    alu_out = a & b;
            2'd1:    alu_out = a | b;
            2'd2:    alu_out = a ^ b;
            default: alu_out = a + b;     // 2'd3 (default also covers x/z in simulation)
        endcase
    end

endmodule
