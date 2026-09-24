`timescale 1ns / 1ps

// parity_generator: computes a single parity bit for a WIDTH-bit data word
// so that {data, parity} has the parity selected by ODD. Companion module
// parity_checker recomputes the same bit on the receive side and compares.
module parity_generator #(
    parameter WIDTH = 8,
    parameter ODD   = 0     // 0 = even parity, 1 = odd parity
) (
    input  wire [WIDTH-1:0] data,
    output wire             parity
);

    // ^data is 1 exactly when data holds an odd number of 1 bits.
    // Even parity: append that bit directly so the total count of 1s
    // (data + parity) is always even.
    // Odd  parity: append its complement so the total count is always odd.
    assign parity = ODD ? ~(^data) : (^data);

endmodule
