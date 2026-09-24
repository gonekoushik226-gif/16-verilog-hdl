`timescale 1ns / 1ps

module tb_not_gate;

    reg  a;
    wire y;

    integer errors = 0;
    integer checks = 0;

    not_gate dut (.a(a), .y(y));

    task check_one(input av, input ev);
        begin
            a = av;
            #1;
            checks = checks + 1;
            $display(" a=%b | y=%b", a, y);
            if (y !== ev) begin
                errors = errors + 1;
                $display("ERROR: t=%0t a=%b expected=%b actual=%b", $time, a, ev, y);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_not_gate.vcd");
            $dumpvars(0, tb_not_gate);
        end

        $display(" a | y");
        // Exhaustive 2-valued truth table
        check_one(1'b0, 1'b1);
        check_one(1'b1, 1'b0);

        // 4-state behaviour: unknown and high-impedance inputs both invert to x
        check_one(1'bx, 1'bx);
        check_one(1'bz, 1'bx);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
