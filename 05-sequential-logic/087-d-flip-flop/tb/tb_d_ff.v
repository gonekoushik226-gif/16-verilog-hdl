`timescale 1ns / 1ps

// tb_d_ff: drives d asynchronously between clock edges (proving q does
// not follow it, unlike a latch) and samples only at posedge clk, plus
// an asynchronous reset assertion mid-stream.
module tb_d_ff;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg d;
    wire q;

    d_ff dut (.clk(clk), .rst_n(rst_n), .d(d), .q(q));

    always #5 clk = ~clk;

    task check(input expected);
        begin
            checks = checks + 1;
            if (q !== expected) begin
                errors = errors + 1;
                $display("ERROR: time=%0t d=%b expected q=%b actual q=%b", $time, d, expected, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_d_ff.vcd");
            $dumpvars(0, tb_d_ff);
        end

        rst_n = 0; d = 1;
        @(negedge clk); check(1'b0);   // reset holds q at 0 even with d=1

        rst_n = 1;
        d = 1; @(posedge clk); #1; check(1'b1);
        d = 0; @(posedge clk); #1; check(1'b0);

        // toggle d between edges: q must not react until the next posedge
        d = 1; #2; d = 0; #1; check(1'b0);   // still the old sampled value
        @(posedge clk); #1; check(1'b0);      // d was 0 at the edge

        d = 1; @(posedge clk); #1; check(1'b1);

        // asynchronous reset asserted between clock edges
        #2 rst_n = 0; #1; check(1'b0);
        rst_n = 1;
        d = 1; @(posedge clk); #1; check(1'b1);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
