`timescale 1ns / 1ps

// tb_d_latch: drives d while en is high (transparent phase, q must
// track d) and while en is low (hold phase, q must stay put regardless
// of d).
module tb_d_latch;

    integer errors = 0;
    integer checks = 0;

    reg d, en;
    wire q;

    d_latch dut (.d(d), .en(en), .q(q));

    task check(input expected);
        begin
            #2;
            checks = checks + 1;
            if (q !== expected) begin
                errors = errors + 1;
                $display("ERROR: d=%b en=%b expected q=%b actual q=%b", d, en, expected, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_d_latch.vcd");
            $dumpvars(0, tb_d_latch);
        end

        // transparent phase: q must track d
        en = 1;
        d = 0; check(1'b0);
        d = 1; check(1'b1);
        d = 0; check(1'b0);
        d = 1; check(1'b1);

        // hold phase: q must stay at its last value regardless of d
        en = 0;
        d = 0; check(1'b1);   // q holds the 1 from before en dropped
        d = 1; check(1'b1);
        d = 0; check(1'b1);

        // re-enter transparent phase
        en = 1;
        d = 0; check(1'b0);

        en = 0;
        d = 1; check(1'b0);   // holds the 0

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
