`timescale 1ns / 1ps
`default_nettype none   // undeclared identifiers become errors, not implicit wires

// wire_assign_demo
// Shows nets, vectors, intermediate wires and continuous assignments on a
// 3-bit input: a majority vote, a parity bit, a bit-reversed copy and a
// zero-extended copy.
module wire_assign_demo (
    input  wire [2:0] in_bits,
    output wire       majority,   // 1 when at least two input bits are 1
    output wire       parity,     // 1 when an odd number of input bits are 1
    output wire [2:0] reversed,   // in_bits with bit order reversed
    output wire [3:0] zero_ext    // in_bits widened to 4 bits
);

    // Intermediate nets: one AND term per pair of inputs
    wire pair_01;
    wire pair_12;
    wire pair_02;

    assign pair_01 = in_bits[0] & in_bits[1];
    assign pair_12 = in_bits[1] & in_bits[2];
    assign pair_02 = in_bits[0] & in_bits[2];

    assign majority = pair_01 | pair_12 | pair_02;

    // Net declaration assignment: declare and drive in one statement
    wire odd_ones = in_bits[0] ^ in_bits[1] ^ in_bits[2];
    assign parity = odd_ones;

    // Concatenation builds a vector from individual bits
    assign reversed = {in_bits[0], in_bits[1], in_bits[2]};
    assign zero_ext = {1'b0, in_bits};

endmodule

`default_nettype wire   // restore the default for files compiled after this one
