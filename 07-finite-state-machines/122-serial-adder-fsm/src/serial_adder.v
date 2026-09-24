`timescale 1ns / 1ps

// serial_adder: a Mealy FSM that adds two numbers one bit per clock
// (LSB first), holding the running carry as its only state. `sum` is a
// combinational (Mealy) function of the carry state AND the current a/b
// bits, so it is valid the same cycle those bits are presented -- unlike
// a bit-parallel adder, no width-dependent ripple delay exists here
// because the ripple happens across clock cycles instead of across
// combinational logic.
module serial_adder (
    input  wire clk,
    input  wire rst_n,
    input  wire start,      // pulse for one cycle before bit 0 of a new addition
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry_out   // registered carry, valid for the next bit / final carry after the last
);

    localparam C0 = 1'b0, C1 = 1'b1;

    reg carry_state, carry_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     carry_state <= C0;
        else if (start) carry_state <= C0;   // synchronous carry reset between additions
        else            carry_state <= carry_next;
    end

    // majority(a, b, carry_state) = carry into the next bit position
    always @(*) begin
        carry_next = (a & b) | (a & carry_state) | (b & carry_state);
    end

    assign sum       = a ^ b ^ carry_state;  // Mealy: function of state AND current inputs
    assign carry_out = carry_state;

endmodule
