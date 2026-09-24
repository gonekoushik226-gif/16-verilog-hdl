`timescale 1ns / 1ps

// decoder_n: parameterized N-to-2^N one-hot decoder with enable, using the
// same shift-based construction as decoder2to4 (038) generalized to any N.
module decoder_n #(
    parameter N = 3                    // address width
) (
    input  wire [N-1:0]      a,
    input  wire              en,
    output wire [(1<<N)-1:0] y
);

    localparam OUT_W = 1 << N;

    assign y = en ? ({{OUT_W-1{1'b0}}, 1'b1} << a) : {OUT_W{1'b0}};

endmodule
