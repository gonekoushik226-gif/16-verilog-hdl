`timescale 1ns / 1ps

// literal_constants
// The value 200 written in four number bases, a negative literal, zero
// extension and replication, plus two masking operations used to observe how
// the unknown (x) and high-impedance (z) values propagate through logic.
module literal_constants (
    input  wire [3:0]  a,
    output wire [7:0]  dec_val,    // 8'd200
    output wire [7:0]  hex_val,    // 8'hC8
    output wire [7:0]  bin_val,    // 8'b1100_1000
    output wire [7:0]  oct_val,    // 8'o310
    output wire [7:0]  neg_val,    // -8'sd56 : same bit pattern as 200
    output wire [15:0] zero_ext,   // 8-bit literal assigned to 16 bits
    output wire [7:0]  replicated, // {2{4'hA}}
    output wire [3:0]  and_mask,   // a & 4'b1100 : clears the low two bits
    output wire [3:0]  or_mask     // a | 4'b0011 : sets the low two bits
);

    assign dec_val    = 8'd200;
    assign hex_val    = 8'hC8;
    assign bin_val    = 8'b1100_1000;   // '_' is only a visual separator
    assign oct_val    = 8'o310;
    assign neg_val    = -8'sd56;        // two's complement of 56
    assign zero_ext   = {8'h00, 8'hC8};
    assign replicated = {2{4'hA}};

    assign and_mask = a & 4'b1100;
    assign or_mask  = a | 4'b0011;

endmodule
