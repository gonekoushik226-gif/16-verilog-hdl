`timescale 1ns / 1ps

// tb_baugh_wooley_mult: exhaustive over all 256 combinations of 4-bit
// two's-complement a and b, checked against Verilog's own
// $signed(a)*$signed(b) reference.
module tb_baugh_wooley_mult;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi;

    reg  [3:0] a, b;
    wire [7:0] product;

    baugh_wooley_mult dut (.a(a), .b(b), .product(product));

    task check;
        reg signed [7:0] expected;
        begin
            #1;
            expected = $signed(a) * $signed(b);
            checks = checks + 1;
            if (product !== expected) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d expected product=%0d actual product=%0d",
                          $signed(a), $signed(b), expected, $signed(product));
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_baugh_wooley_mult.vcd");
            $dumpvars(0, tb_baugh_wooley_mult);
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
