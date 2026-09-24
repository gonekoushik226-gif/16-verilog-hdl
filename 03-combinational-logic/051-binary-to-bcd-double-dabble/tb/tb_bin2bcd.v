`timescale 1ns / 1ps

// tb_bin2bcd: exhaustive check of all 256 8-bit values against a reference
// model computed with plain integer division/modulo, independent of the
// RTL's shift-and-add-3 algorithm.
module tb_bin2bcd;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  [7:0] bin;
    wire [3:0] hundreds, tens, units;

    bin2bcd dut (.bin(bin), .hundreds(hundreds), .tens(tens), .units(units));

    task check(input [7:0] b);
        reg [3:0] exp_h, exp_t, exp_u;
        begin
            bin = b;
            #1;
            exp_h = b / 100;
            exp_t = (b / 10) % 10;
            exp_u = b % 10;
            checks = checks + 1;
            if (hundreds !== exp_h || tens !== exp_t || units !== exp_u) begin
                errors = errors + 1;
                $display("ERROR: bin=%0d expected {h,t,u}=%0d%0d%0d actual=%0d%0d%0d",
                          b, exp_h, exp_t, exp_u, hundreds, tens, units);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bin2bcd.vcd");
            $dumpvars(0, tb_bin2bcd);
        end

        $display("exhaustive 8-bit sweep (256 values)...");
        for (i = 0; i < 256; i = i + 1)
            check(i[7:0]);
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
