`timescale 1ns / 1ps

// skip_block: a 4-bit ripple-carry block augmented with a carry-skip
// mux. block_p (AND of every bit's propagate a[i]^b[i]) is true exactly
// when the block, whatever its carry-in, would pass that carry straight
// through to carry_out unchanged. In that case carry_out is taken
// directly from cin via the fast mux path instead of waiting for the
// ripple to complete through all four full adders — the two paths are
// value-equivalent when block_p=1 (which is exactly the condition that
// makes the ripple result guaranteed equal to cin), so the mux is safe;
// its purpose is to shorten the *critical path* a downstream block's
// carry-in depends on, which plain functional simulation does not model
// timing for but which is the entire point of the architecture.
module skip_block (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire        carry_out
);

    wire [4:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : fa
            full_adder u (.a(a[i]), .b(b[i]), .cin(carry[i]),
                           .sum(sum[i]), .carry_out(carry[i+1]));
        end
    endgenerate

    wire [3:0] p = a ^ b;
    wire       block_p = &p;          // 1 iff every bit propagates
    wire       ripple_carry_out = carry[4];

    assign carry_out = block_p ? cin : ripple_carry_out;

endmodule
