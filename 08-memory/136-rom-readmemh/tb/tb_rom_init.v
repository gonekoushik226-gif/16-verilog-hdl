`timescale 1ns / 1ps

// tb_rom_init: reads the SAME hex file into an independent reference
// array and checks the DUT's output at every address against it --
// proving the DUT actually loaded the file's contents rather than,
// say, all zeros or leftover simulator garbage.
module tb_rom_init;

    integer errors = 0;
    integer checks = 0;

    reg  [3:0] addr;
    wire [7:0] data;

    rom_init #(.ADDR_W(4), .DATA_W(8), .DEPTH(16)) dut (.addr(addr), .data(data));

    reg [7:0] ref_mem [0:15];
    initial $readmemh("data/rom.hex", ref_mem);

    integer i;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_rom_init.vcd");
            $dumpvars(0, tb_rom_init);
        end

        for (i = 0; i < 16; i = i + 1) begin
            addr = i[3:0];
            #1;
            checks = checks + 1;
            if (data !== ref_mem[i]) begin
                errors = errors + 1;
                $display("ERROR: addr=%0d data=%02h expected=%02h", i, data, ref_mem[i]);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
