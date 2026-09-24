`timescale 1ns / 1ps

// tb_half_subtractor: exhaustive 2-bit input space (a,b) checked against
// the signed difference a-b split into {borrow,diff}.
module tb_half_subtractor;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  a, b;
    wire diff, borrow;

    half_subtractor dut (.a(a), .b(b), .diff(diff), .borrow(borrow));

    task check;
        reg signed [1:0] expected;
        begin
            #1;
            expected = a - b;
            checks = checks + 1;
            if (diff !== expected[0] || borrow !== expected[1]) begin
                errors = errors + 1;
                $display("ERROR: a=%b b=%b expected diff=%b borrow=%b actual diff=%b borrow=%b",
                          a, b, expected[0], expected[1], diff, borrow);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_half_subtractor.vcd");
            $dumpvars(0, tb_half_subtractor);
        end

        for (i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
