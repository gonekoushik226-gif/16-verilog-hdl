`timescale 1ns / 1ps

module tb_mux_function;

    reg  a, b, c;
    wire y;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg  expected;

    mux_function dut (.a(a), .b(b), .c(c), .y(y));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mux_function.vcd");
            $dumpvars(0, tb_mux_function);
        end

        $display("a b c | y (majority)");
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            #1;
            // Independent truth-table reference: majority(a,b,c)
            expected = (a & b) | (b & c) | (a & c);
            checks = checks + 1;
            $display(" %b %b %b | %b", a, b, c, y);
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t a=%b b=%b c=%b expected=%b actual=%b",
                          $time, a, b, c, expected, y);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
