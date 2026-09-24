`timescale 1ns / 1ps

// tb_t_ff: checks hold (t=0), toggle (t=1, confirming a clean divide-by-2
// pattern over several cycles), and reset.
module tb_t_ff;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, t;
    wire q;

    t_ff dut (.clk(clk), .rst_n(rst_n), .t(t), .q(q));

    always #5 clk = ~clk;

    task check(input expected);
        begin
            checks = checks + 1;
            if (q !== expected) begin
                errors = errors + 1;
                $display("ERROR: time=%0t t=%b expected q=%b actual q=%b", $time, t, expected, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_t_ff.vcd");
            $dumpvars(0, tb_t_ff);
        end

        rst_n = 0; t = 0; @(negedge clk); check(1'b0);
        rst_n = 1;

        // hold: several edges with t=0
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk); #1; check(1'b0);
        end

        // toggle: confirm clean divide-by-2 over 8 edges
        t = 1;
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk); #1;
            check(i[0] == 1'b0);   // toggles every edge: 1,0,1,0,...
        end

        // hold again at whatever value it last reached
        t = 0;
        @(posedge clk); #1; check(1'b0);

        // reset mid-toggle
        t = 1; @(posedge clk); #1; // q=1
        rst_n = 0; #1; check(1'b0);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
