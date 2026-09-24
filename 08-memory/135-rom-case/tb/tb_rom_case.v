`timescale 1ns / 1ps

// tb_rom_case: exhaustively checks every one of the 16 addresses (a
// combinational design, so no clock is needed) against addr*addr,
// computed independently in the testbench.
module tb_rom_case;

    integer errors = 0;
    integer checks = 0;

    reg  [3:0] addr;
    wire [7:0] data;

    rom_case dut (.addr(addr), .data(data));

    integer i;
    reg [7:0] expected;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_rom_case.vcd");
            $dumpvars(0, tb_rom_case);
        end

        for (i = 0; i < 16; i = i + 1) begin
            addr = i[3:0];
            #1;
            expected = i * i;
            checks = checks + 1;
            if (data !== expected) begin
                errors = errors + 1;
                $display("ERROR: addr=%0d data=%0d expected=%0d", i, data, expected);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
