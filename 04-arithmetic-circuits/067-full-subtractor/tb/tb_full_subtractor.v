`timescale 1ns / 1ps

// tb_full_subtractor: exhaustive 3-bit input space (a,b,bin) checked
// against the signed difference a-b-bin split into {borrow_out,diff}.
module tb_full_subtractor;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  a, b, bin;
    wire diff, borrow_out;

    full_subtractor dut (.a(a), .b(b), .bin(bin), .diff(diff), .borrow_out(borrow_out));

    task check;
        reg signed [1:0] expected;
        begin
            #1;
            expected = a - b - bin;
            checks = checks + 1;
            if (diff !== expected[0] || borrow_out !== expected[1]) begin
                errors = errors + 1;
                $display("ERROR: a=%b b=%b bin=%b expected diff=%b borrow=%b actual diff=%b borrow=%b",
                          a, b, bin, expected[0], expected[1], diff, borrow_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_full_subtractor.vcd");
            $dumpvars(0, tb_full_subtractor);
        end

        for (i = 0; i < 8; i = i + 1) begin
            {a, b, bin} = i[2:0];
            check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
