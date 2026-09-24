`timescale 1ns / 1ps

// inc_dec: adds or subtracts exactly 1 from an 8-bit value, built as a
// bit-sliced chain rather than a generic adder. A half adder's sum
// (a XOR carry-in) and a half subtractor's diff (a XOR borrow-in) are
// the *same* equation, so every bit's result here is simply a[i] XOR
// chain_bit regardless of direction; only the propagate condition for
// the chain bit differs between the two directions (AND for a carry —
// "propagate a carry out of this bit only if this bit is a 1" — versus
// NOT-AND for a borrow — "propagate a borrow out of this bit only if
// this bit is a 0"). `wrap` reports whether the operation rolled over
// (0xFF -> 0x00 incrementing, or 0x00 -> 0xFF decrementing).
module inc_dec #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire             dec,      // 0 = increment (a+1), 1 = decrement (a-1)
    output reg  [WIDTH-1:0] result,
    output reg              wrap      // carry-out (increment) / borrow-out (decrement)
);

    integer i;
    reg chain_bit;

    always @(*) begin
        result    = {WIDTH{1'b0}};
        chain_bit = 1'b1;   // always adding/subtracting exactly 1
        for (i = 0; i < WIDTH; i = i + 1) begin
            result[i] = a[i] ^ chain_bit;
            chain_bit = dec ? ((~a[i]) & chain_bit) : (a[i] & chain_bit);
        end
        wrap = chain_bit;
    end

endmodule
