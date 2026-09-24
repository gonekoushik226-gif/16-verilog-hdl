`timescale 1ns / 1ps

// tb_dff_en: alternates enabled and disabled clock edges while d keeps
// changing, checking q only updates on enabled edges.
module tb_dff_en;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n, en, d;
    wire q;

    dff_en dut (.clk(clk), .rst_n(rst_n), .en(en), .d(d), .q(q));

    always #5 clk = ~clk;

    task check(input expected);
        begin
            checks = checks + 1;
            if (q !== expected) begin
                errors = errors + 1;
                $display("ERROR: time=%0t en=%b d=%b expected q=%b actual q=%b", $time, en, d, expected, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_dff_en.vcd");
            $dumpvars(0, tb_dff_en);
        end

        rst_n = 0; en = 0; d = 1;
        @(negedge clk); check(1'b0);

        rst_n = 1;
        en = 1; d = 1; @(posedge clk); #1; check(1'b1);
        en = 0; d = 0; @(posedge clk); #1; check(1'b1);   // held despite d=0
        en = 0; d = 0; @(posedge clk); #1; check(1'b1);   // still held
        en = 1; d = 0; @(posedge clk); #1; check(1'b0);   // now updates
        en = 0; d = 1; @(posedge clk); #1; check(1'b0);   // held again
        en = 1; d = 1; @(posedge clk); #1; check(1'b1);

        // reset takes priority over enable
        en = 1; d = 1; rst_n = 0; #1; check(1'b0);
        rst_n = 1;
        en = 1; d = 1; @(posedge clk); #1; check(1'b1);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
