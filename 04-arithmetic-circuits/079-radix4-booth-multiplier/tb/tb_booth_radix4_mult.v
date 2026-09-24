`timescale 1ns / 1ps

// tb_booth_radix4_mult: two DUTs. dut6 (WIDTH=6) is checked exhaustively
// over all 64x64=4096 signed operand combinations. dut16 (WIDTH=16) is
// checked with 3000 random operand pairs plus extreme-value corners.
// Both are compared against Verilog's own signed multiply.
module tb_booth_radix4_mult;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi, r;

    // ---- WIDTH = 6, exhaustive ----
    reg  signed [5:0]  a6, b6;
    wire signed [11:0] product6;

    booth_radix4_mult #(.WIDTH(6)) dut6 (.a(a6), .b(b6), .product(product6));

    // ---- WIDTH = 16, random ----
    reg  signed [15:0] a16, b16;
    wire signed [31:0] product16;

    booth_radix4_mult #(.WIDTH(16)) dut16 (.a(a16), .b(b16), .product(product16));

    task check6;
        reg signed [11:0] expected;
        begin
            #1;
            expected = a6 * b6;
            checks = checks + 1;
            if (product6 !== expected) begin
                errors = errors + 1;
                $display("ERROR(W6): a=%0d b=%0d expected product=%0d actual product=%0d",
                          a6, b6, expected, product6);
            end
        end
    endtask

    task check16;
        reg signed [31:0] expected;
        begin
            #1;
            expected = a16 * b16;
            checks = checks + 1;
            if (product16 !== expected) begin
                errors = errors + 1;
                $display("ERROR(W16): a=%0d b=%0d expected product=%0d actual product=%0d",
                          a16, b16, expected, product16);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_booth_radix4_mult.vcd");
            $dumpvars(0, tb_booth_radix4_mult);
        end

        for (ai = 0; ai < 64; ai = ai + 1)
            for (bi = 0; bi < 64; bi = bi + 1) begin
                a6 = ai[5:0]; b6 = bi[5:0];
                check6;
            end

        for (r = 0; r < 3000; r = r + 1) begin
            a16 = $random; b16 = $random;
            check16;
        end
        // corners: most-negative operand(s), max positive, zero
        a16 = -16'sd32768; b16 = -16'sd32768; check16;
        a16 = -16'sd32768; b16 =  16'sd32767; check16;
        a16 =  16'sd32767; b16 =  16'sd32767; check16;
        a16 =  16'sd0;     b16 = -16'sd32768; check16;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
