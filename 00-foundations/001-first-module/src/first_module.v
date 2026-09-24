`timescale 1ns / 1ps

// first_module
// The smallest useful Verilog module: it forwards its input to one output
// and drives the inverted input on a second output.
module first_module (
    input  wire in_sig,     // 1-bit input
    output wire out_sig,    // copy of in_sig
    output wire out_sig_n   // inverse of in_sig (_n = active-low / inverted)
);

    assign out_sig   = in_sig;
    assign out_sig_n = ~in_sig;

endmodule
