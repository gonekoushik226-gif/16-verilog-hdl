`timescale 1ns / 1ps

// tb_ms_dff: drives d both aligned with clock edges and between them
// (to prove the slave really is frozen while the master is
// transparent), comparing ms_dff's q against a plain behavioral
// posedge-triggered reference model on every check.
module tb_ms_dff;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg d;
    wire q;

    reg ref_q;

    ms_dff dut (.clk(clk), .d(d), .q(q));

    always #5 clk = ~clk;
    always @(posedge clk) ref_q <= d;

    task check;
        begin
            checks = checks + 1;
            if (q !== ref_q) begin
                errors = errors + 1;
                $display("ERROR: time=%0t d=%b expected q=%b actual q=%b", $time, d, ref_q, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_ms_dff.vcd");
            $dumpvars(0, tb_ms_dff);
        end

        ref_q = 1'bx;
        d = 0; @(posedge clk); #1; check;
        d = 1; @(posedge clk); #1; check;

        // change d while clk=0 (master transparent, slave frozen): q
        // must NOT change until the rising edge actually occurs
        @(negedge clk); #1;
        d = 0; #1; check;   // q must still be the old (slave-held) value
        d = 1; #1; check;
        d = 0; #1; check;
        @(posedge clk); #1; check;   // now q updates to the final d

        // change d while clk=1 (slave transparent, master frozen): q
        // must NOT change either, since the master isn't sampling
        @(posedge clk); #1;
        d = 1; #1; check;
        d = 0; #1; check;
        @(negedge clk);
        @(posedge clk); #1; check;

        for (i = 0; i < 10; i = i + 1) begin
            d = $random;
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
