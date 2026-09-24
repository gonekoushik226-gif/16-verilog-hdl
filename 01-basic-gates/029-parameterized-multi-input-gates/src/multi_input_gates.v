`timescale 1ns / 1ps

// multi_input_gates: generalizes the six 2-input gates of 017-023 to an
// N-input gate bank using Verilog's unary reduction operators, which
// combine every bit of a bus into a single result.
module multi_input_gates #(
    parameter N = 4
) (
    input  wire [N-1:0] a,
    output wire         y_and,
    output wire         y_or,
    output wire         y_xor,
    output wire         y_nand,
    output wire         y_nor,
    output wire         y_xnor
);

    assign y_and  = &a;    // 1 iff every bit of a is 1
    assign y_or   = |a;    // 1 iff at least one bit of a is 1
    assign y_xor  = ^a;    // 1 iff an odd number of bits of a are 1
    assign y_nand = ~&a;
    assign y_nor  = ~|a;
    assign y_xnor = ~^a;   // 1 iff an even number of bits of a are 1

endmodule
