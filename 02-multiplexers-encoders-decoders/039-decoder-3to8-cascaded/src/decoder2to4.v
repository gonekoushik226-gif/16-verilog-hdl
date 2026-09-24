`timescale 1ns / 1ps

// decoder2to4: binary-to-one-hot decoder with an active-high enable, the
// building block cascaded twice inside decoder3to8.
module decoder2to4 (
    input  wire [1:0] a,
    input  wire       en,
    output wire [3:0] y
);

    assign y = en ? (4'b0001 << a) : 4'b0000;

endmodule
