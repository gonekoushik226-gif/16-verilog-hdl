`timescale 1ns / 1ps

module tb_or_gate;

    reg  a, b;
    wire y;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg      expected;

    or_gate dut (.a(a), .b(b), .y(y));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_or_gate.vcd");
            $dumpvars(0, tb_or_gate);
        end

        $display(" a b | y");
        for (i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            #1;
            expected = a | b;
            checks = checks + 1;
            $display(" %b %b | %b", a, b, y);
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t a=%b b=%b expected=%b actual=%b",
                          $time, a, b, expected, y);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
