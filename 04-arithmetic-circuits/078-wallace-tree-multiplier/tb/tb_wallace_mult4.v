`timescale 1ns / 1ps

// tb_wallace_mult4: exhaustive over all 256 combinations of 4-bit a and
// b, checked against Verilog's own a*b.
module tb_wallace_mult4;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi;

    reg  [3:0] a, b;
    wire [7:0] product;

    wallace_mult4 dut (.a(a), .b(b), .product(product));

    task check;
        reg [7:0] expected;
        begin
            #1;
            expected = a * b;
            checks = checks + 1;
            if (product !== expected) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d expected product=%0d actual product=%0d",
                          a, b, expected, product);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_wallace_mult4.vcd");
            $dumpvars(0, tb_wallace_mult4);
        end

        for (ai = 0; ai < 16; ai = ai + 1)
            for (bi = 0; bi < 16; bi = bi + 1) begin
                a = ai[3:0]; b = bi[3:0];
                check;
            end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
