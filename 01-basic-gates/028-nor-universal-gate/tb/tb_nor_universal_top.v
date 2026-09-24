`timescale 1ns / 1ps

module tb_nor_universal_top;

    reg  a, b;
    wire y_not_a, y_and, y_or, y_xnor;

    integer errors = 0;
    integer checks = 0;
    integer i;

    nor_universal_top dut (
        .a(a), .b(b),
        .y_not_a(y_not_a), .y_and(y_and), .y_or(y_or), .y_xnor(y_xnor)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_nor_universal_top.vcd");
            $dumpvars(0, tb_nor_universal_top);
        end

        $display(" a b | ~a  a&b  a|b  ~(a^b)");
        for (i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            #1;
            $display(" %b %b |  %b   %b    %b     %b",
                      a, b, y_not_a, y_and, y_or, y_xnor);

            checks = checks + 4;
            if (y_not_a !== ~a) begin
                errors = errors + 1;
                $display("ERROR: NOT  t=%0t a=%b expected=%b actual=%b", $time, a, ~a, y_not_a);
            end
            if (y_and !== (a & b)) begin
                errors = errors + 1;
                $display("ERROR: AND  t=%0t a=%b b=%b expected=%b actual=%b", $time, a, b, a & b, y_and);
            end
            if (y_or !== (a | b)) begin
                errors = errors + 1;
                $display("ERROR: OR   t=%0t a=%b b=%b expected=%b actual=%b", $time, a, b, a | b, y_or);
            end
            if (y_xnor !== ~(a ^ b)) begin
                errors = errors + 1;
                $display("ERROR: XNOR t=%0t a=%b b=%b expected=%b actual=%b", $time, a, b, ~(a ^ b), y_xnor);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
