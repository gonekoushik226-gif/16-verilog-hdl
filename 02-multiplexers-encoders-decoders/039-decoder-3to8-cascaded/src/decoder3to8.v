`timescale 1ns / 1ps

// decoder3to8: 3-to-8 one-hot decoder built by cascading two decoder2to4
// blocks. The top address bit a[2] enables exactly one of the two 2:4
// decoders; the other stays disabled and drives its half of y to zero.
module decoder3to8 (
    input  wire [2:0] a,
    input  wire       en,
    output wire [7:0] y
);

    wire en_lo = en & ~a[2];   // active when the target is in y[3:0]
    wire en_hi = en &  a[2];   // active when the target is in y[7:4]
    wire [3:0] y_lo, y_hi;

    decoder2to4 dec_lo (.a(a[1:0]), .en(en_lo), .y(y_lo));
    decoder2to4 dec_hi (.a(a[1:0]), .en(en_hi), .y(y_hi));

    assign y = {y_hi, y_lo};

endmodule
