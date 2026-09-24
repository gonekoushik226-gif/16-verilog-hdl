`timescale 1ns / 1ps

// bit_manipulator
// Common vector operations on a 32-bit word: bit select, fixed and indexed
// part selects, byte swapping (endianness), sign extension and rotation.
module bit_manipulator (
    input  wire [31:0] data_in,
    input  wire [1:0]  byte_sel,    // which byte to extract (0 = least significant)
    output wire        msb,         // data_in[31]
    output wire        lsb,         // data_in[0]
    output wire [7:0]  low_byte,    // fixed part select   data_in[7:0]
    output wire [7:0]  high_byte,   // indexed part select data_in[31 -: 8]
    output wire [7:0]  sel_byte,    // variable part select data_in[byte_sel*8 +: 8]
    output wire [31:0] byte_swap,   // bytes in reverse order (endianness change)
    output wire [31:0] sext_byte,   // low byte sign-extended to 32 bits
    output wire [31:0] rotl8        // rotate left by 8 bits
);

    assign msb       = data_in[31];
    assign lsb       = data_in[0];
    assign low_byte  = data_in[7:0];
    assign high_byte = data_in[31 -: 8];            // bits 31 down to 24
    assign sel_byte  = data_in[byte_sel * 8 +: 8];  // base can be a signal, width must be constant

    assign byte_swap = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
    assign sext_byte = {{24{data_in[7]}}, data_in[7:0]};   // replicate the sign bit
    assign rotl8     = {data_in[23:0], data_in[31:24]};

endmodule
