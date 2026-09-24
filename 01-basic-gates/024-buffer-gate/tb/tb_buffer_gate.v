`timescale 1ns / 1ps

module tb_buffer_gate;

    reg  a;
    wire y1, y2;

    integer errors = 0;
    integer checks = 0;

    buffer_gate dut (.a(a), .y1(y1), .y2(y2));

    task check_one(input av, input ev);
        begin
            a = av;
            #1;
            checks = checks + 1;
            $display(" a=%b | y1=%b y2=%b", a, y1, y2);
            if (y1 !== ev || y2 !== ev) begin
                errors = errors + 1;
                $display("ERROR: t=%0t a=%b expected=%b y1=%b y2=%b",
                          $time, a, ev, y1, y2);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_buffer_gate.vcd");
            $dumpvars(0, tb_buffer_gate);
        end

        $display(" a | y1 y2");
        // Exhaustive 2-valued truth table
        check_one(1'b0, 1'b0);
        check_one(1'b1, 1'b1);

        // 4-state propagation: a buffer passes x/z through unchanged as x
        // (an undriven/unknown input has no defined level to reproduce;
        // 'z' is not a valid gate *output* either, so it reads back as x)
        check_one(1'bx, 1'bx);
        check_one(1'bz, 1'bx);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
