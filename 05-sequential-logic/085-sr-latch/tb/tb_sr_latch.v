`timescale 1ns / 1ps

// tb_sr_latch: drives the classic set/reset/hold/forbidden sequence and
// checks q/qn after each stimulus settles.
module tb_sr_latch;

    integer errors = 0;
    integer checks = 0;

    reg  s, r;
    wire q, qn;

    sr_latch dut (.s(s), .r(r), .q(q), .qn(qn));

    task check;
        input exp_q, exp_qn;
        begin
            #2;
            checks = checks + 1;
            if (q !== exp_q || qn !== exp_qn) begin
                errors = errors + 1;
                $display("ERROR: s=%b r=%b expected q=%b qn=%b actual q=%b qn=%b",
                          s, r, exp_q, exp_qn, q, qn);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_sr_latch.vcd");
            $dumpvars(0, tb_sr_latch);
        end

        s = 0; r = 1; check(1'b0, 1'b1);   // reset
        s = 0; r = 0; check(1'b0, 1'b1);   // hold after reset
        s = 1; r = 0; check(1'b1, 1'b0);   // set
        s = 0; r = 0; check(1'b1, 1'b0);   // hold after set
        s = 0; r = 1; check(1'b0, 1'b1);   // reset again
        s = 1; r = 1; check(1'b0, 1'b0);   // forbidden state
        // leaving the forbidden state through reset first gives a
        // predictable exit (both inputs releasing simultaneously is a
        // genuine race in real hardware and is not tested here)
        s = 0; r = 1; check(1'b0, 1'b1);   // exit via reset
        s = 1; r = 0; check(1'b1, 1'b0);   // set again
        s = 0; r = 0; check(1'b1, 1'b0);   // hold final

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
