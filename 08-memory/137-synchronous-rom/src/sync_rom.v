`timescale 1ns / 1ps

// sync_rom: like program 136's rom_init, but the read is REGISTERED --
// `data` reflects `mem[addr]` one clock cycle after `addr` is
// presented, not combinationally. This is the idiomatic template real
// synthesis tools recognize for inferring dedicated block-RAM/ROM
// resources (which have a registered output stage in silicon) instead
// of slower distributed logic. Deliberately has no reset on `data`:
// forcing a reset value on a block-RAM output register is either
// impossible or costly on most FPGA architectures, so production
// block-ROM read templates omit it -- an intentional, explicit
// deviation from this repository's default reset style (CLAUDE.md §4
// permits this when stated).
module sync_rom #(
    parameter ADDR_W = 4,
    parameter DATA_W = 8,
    parameter DEPTH  = 16
) (
    input  wire             clk,
    input  wire [ADDR_W-1:0] addr,
    output reg  [DATA_W-1:0] data
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];

    initial begin
        $readmemh("data/rom.hex", mem);
    end

    always @(posedge clk) begin
        data <= mem[addr];
    end

endmodule
