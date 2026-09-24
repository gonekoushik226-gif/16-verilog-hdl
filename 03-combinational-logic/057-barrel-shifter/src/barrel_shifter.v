`timescale 1ns / 1ps

// barrel_shifter: logical (zero-fill) shifter built from $clog2(WIDTH)
// mux stages instead of a single wide operator, using generate to
// instantiate one stage per bit of the shift amount. Stage k either
// passes its input through unchanged or shifts it by 2^k, selected by
// shamt[k] — any shift amount is reached in log2(WIDTH) stages instead of
// a single WIDTH-way mux, the same structure `shifter` (program 056)
// leaves to the synthesis tool's own optimizer.
module barrel_shifter #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]         data,
    input  wire [$clog2(WIDTH)-1:0] shamt,
    input  wire                     left,   // 1 = shift left, 0 = shift right (zero-fill both ways)
    output wire [WIDTH-1:0]         result
);

    localparam STAGES = $clog2(WIDTH);

    // `stage` is a genuinely acyclic chain (stage[k+1] depends only on
    // stage[k], never the reverse); Verilator's flattener nonetheless
    // treats the whole array as one signal and reports a false-positive
    // UNOPTFLAT cycle, a known limitation documented at the warning's own
    // URL, hence the lint_off around just this declaration.
    /* verilator lint_off UNOPTFLAT */
    wire [WIDTH-1:0] stage [0:STAGES];
    /* verilator lint_on UNOPTFLAT */
    assign stage[0] = data;

    genvar k;
    generate
        for (k = 0; k < STAGES; k = k + 1) begin : stage_gen
            localparam integer SH = (1 << k);
            wire [WIDTH-1:0] shifted_left  = stage[k] << SH;
            wire [WIDTH-1:0] shifted_right = stage[k] >> SH;
            // shamt[k] set -> apply this stage's fixed shift of 2^k;
            // clear -> pass this stage's input through unchanged
            assign stage[k+1] = shamt[k] ? (left ? shifted_left : shifted_right) : stage[k];
        end
    endgenerate

    assign result = stage[STAGES];

endmodule
