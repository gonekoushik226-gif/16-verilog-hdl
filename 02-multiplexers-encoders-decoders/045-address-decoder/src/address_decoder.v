`timescale 1ns / 1ps

// address_decoder: memory-map address decoder for a 16-bit address bus.
// Produces one chip-select per mapped region and an `error` flag for any
// address that falls in a gap between regions. Unlike the earlier
// bit-slicing decoders in this category (decoder2to4/decoder_n), real
// memory maps rarely align regions to convenient power-of-two boundaries,
// so each region is checked with an explicit [base,top] range comparison.
//
// Memory map:
//   0x0000 - 0x1FFF  ROM     (8 KiB)
//   0x2000 - 0x5FFF  RAM     (16 KiB)
//   0x6000 - 0x6FFF  PERIPH  (4 KiB)
//   0x7000 - 0x70FF  UART    (256 B)
//   everything else  unmapped -> error
module address_decoder #(
    parameter ADDR_WIDTH = 16
) (
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg                   cs_rom,
    output reg                   cs_ram,
    output reg                   cs_periph,
    output reg                   cs_uart,
    output reg                   error
);

    // ROM starts at address 0, so on an unsigned addr bus "addr >= ROM_BASE"
    // would always be true; the lower bound is omitted rather than written
    // as a comparison that can never be false.
    localparam [ADDR_WIDTH-1:0] ROM_TOP    = 16'h1FFF;
    localparam [ADDR_WIDTH-1:0] RAM_BASE    = 16'h2000, RAM_TOP    = 16'h5FFF;
    localparam [ADDR_WIDTH-1:0] PERIPH_BASE = 16'h6000, PERIPH_TOP = 16'h6FFF;
    localparam [ADDR_WIDTH-1:0] UART_BASE   = 16'h7000, UART_TOP   = 16'h70FF;

    always @(*) begin
        // default assignment for every output: avoids an inferred latch
        cs_rom    = 1'b0;
        cs_ram    = 1'b0;
        cs_periph = 1'b0;
        cs_uart   = 1'b0;
        error     = 1'b0;

        if (addr <= ROM_TOP)
            cs_rom = 1'b1;
        else if (addr >= RAM_BASE && addr <= RAM_TOP)
            cs_ram = 1'b1;
        else if (addr >= PERIPH_BASE && addr <= PERIPH_TOP)
            cs_periph = 1'b1;
        else if (addr >= UART_BASE && addr <= UART_TOP)
            cs_uart = 1'b1;
        else
            error = 1'b1;
    end

endmodule
