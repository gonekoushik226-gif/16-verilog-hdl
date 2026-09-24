`timescale 1ns / 1ps

module tb_procedural_demo;

    reg        clk = 1'b0;
    reg        rst_n;
    reg  [3:0] a, b;
    wire [3:0] max_ab;
    wire [3:0] max_q;

    integer errors = 0;
    integer checks = 0;
    integer i, j;
    reg  [3:0] expected_q;

    procedural_demo dut (
        .clk(clk), .rst_n(rst_n), .a(a), .b(b),
        .max_ab(max_ab), .max_q(max_q)
    );

    always #5 clk = ~clk;   // 10 ns clock period

    task check(input [3:0] actual, input [3:0] expected, input [8*8-1:0] name);
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t %0s a=%0d b=%0d expected %0d got %0d",
                         $time, name, a, b, expected, actual);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_procedural_demo.vcd");
            $dumpvars(0, tb_procedural_demo);
        end

        $timeformat(-9, 0, " ns", 0);   // print %t values in nanoseconds

        // 1) Asynchronous reset: max_q clears without waiting for a clock edge
        a = 4'd9; b = 4'd3; rst_n = 1'b1;
        #2 rst_n = 1'b0;
        #1 check(max_q, 4'd0, "reset");
        $display("reset asserted at t=2 ns, max_q=%0d at t=%0t (no clock edge yet)", max_q, $time);

        // 2) Combinational block: exhaustive a,b while reset holds max_q at 0
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j;
                #1 check(max_ab, (i > j) ? i : j, "max_ab");
            end
        $display("combinational max_ab checked for all 256 (a,b) pairs");

        // 3) Sequential block: change inputs on the falling edge, check after
        //    the next rising edge that max_q captured max_ab.
        @(negedge clk) rst_n = 1'b1;
        $display(" a  b | max_ab | max_q after next rising edge");
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            a = $random; b = $random;
            expected_q = (a > b) ? a : b;
            @(posedge clk); #1;
            check(max_q, expected_q, "max_q");
            $display("%2d %2d |   %2d   |   %2d", a, b, max_ab, max_q);
        end

        // 4) Register holds its value between clock edges
        @(negedge clk);
        expected_q = max_q;
        a = 4'd0; b = 4'd1;   // max_ab becomes 1 immediately...
        #2 check(max_q, expected_q, "hold");  // ...but max_q waits for the edge
        @(posedge clk); #1 check(max_q, 4'd1, "max_q");

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #10000;
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
