`timescale 1ns / 1ps

// buffer_gate: non-inverting buffer built from the built-in `buf` gate
// primitive (not a dataflow `assign`). A single `buf` instance may drive
// several output nets from one input net, which is shown here with two
// outputs (y1, y2) driven by one primitive.
module buffer_gate (
    input  wire a,
    output wire y1,
    output wire y2
);

    // buf <instance>(out1, out2, ..., outN, in) — every argument except
    // the last is an output; all outputs follow the single input.
    buf u_buf (y1, y2, a);

endmodule
