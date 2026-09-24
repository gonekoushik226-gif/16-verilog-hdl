`timescale 1ns / 1ps

// rom_init: a 16x8 ROM implemented as a `reg` memory array, initialized
// at time 0 from an external hex file via $readmemh -- the standard way
// to fill a ROM/RAM too large to write out as individual `case` arms
// (contrast program 135's hand-written case-statement ROM). The read
// itself stays purely combinational (an `assign` from the array).
module rom_init #(
    parameter ADDR_W = 4,
    parameter DATA_W = 8,
    parameter DEPTH  = 16
) (
    input  wire [ADDR_W-1:0] addr,
    output wire [DATA_W-1:0] data
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];

    initial begin
        $readmemh("data/rom.hex", mem);
    end

    assign data = mem[addr];

endmodule
