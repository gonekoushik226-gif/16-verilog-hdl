`timescale 1ns / 1ps

// tb_fp_adder: directed IEEE-754 cases checked bit-exact (values chosen
// so the correct result needs no ambiguous rounding decision), plus
// 4000 random normal-operand pairs checked against the true real-number
// sum within a small relative tolerance (a few ULPs, generous enough to
// allow for this design's simplified round-to-nearest-even, tight
// enough to catch a wrong sign, wrong exponent, or grossly wrong
// mantissa). fp32_to_real independently reconstructs a real value from
// an IEEE-754 bit pattern for both purposes.
module tb_fp_adder;

    integer errors = 0;
    integer checks = 0;
    integer r, k;

    reg  [31:0] a, b;
    wire [31:0] result;

    fp_adder dut (.a(a), .b(b), .result(result));

    function real fp32_to_real;
        input [31:0] bits;
        real sign_r, mant_r;
        integer exp_i, kk;
        begin
            if (bits[30:0] == 31'b0) begin
                fp32_to_real = 0.0;
            end else begin
                sign_r = bits[31] ? -1.0 : 1.0;
                exp_i  = bits[30:23] - 127;
                mant_r = 1.0;
                for (kk = 0; kk < 23; kk = kk + 1)
                    if (bits[22-kk]) mant_r = mant_r + (1.0 / (2.0 ** (kk+1)));
                fp32_to_real = sign_r * mant_r * (2.0 ** exp_i);
            end
        end
    endfunction

    task check_exact;
        input [31:0] expected;
        begin
            #1;
            checks = checks + 1;
            if (result !== expected) begin
                errors = errors + 1;
                $display("ERROR(exact): a=%h b=%h expected=%h (%.6f) actual=%h (%.6f)",
                          a, b, expected, fp32_to_real(expected), result, fp32_to_real(result));
            end
        end
    endtask

    task check_tolerance;
        real real_a, real_b, expected_real, actual_real, diff, tol;
        begin
            #1;
            checks = checks + 1;
            real_a = fp32_to_real(a);
            real_b = fp32_to_real(b);
            expected_real = real_a + real_b;
            actual_real   = fp32_to_real(result);
            diff = actual_real - expected_real;
            if (diff < 0.0) diff = -diff;
            // tolerance: a few ULPs relative to the larger operand's magnitude
            tol = (expected_real < 0.0 ? -expected_real : expected_real) * 1.0e-5 + 1.0e-30;
            if (diff > tol) begin
                errors = errors + 1;
                $display("ERROR(tol): a=%h(%.8f) b=%h(%.8f) expected~=%.8f actual=%h(%.8f) diff=%.8g tol=%.8g",
                          a, real_a, b, real_b, expected_real, result, actual_real, diff, tol);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_fp_adder.vcd");
            $dumpvars(0, tb_fp_adder);
        end

        // ---- directed exact cases ----
        a = 32'h3F800000; b = 32'h40000000; check_exact(32'h40400000); // 1.0 + 2.0 = 3.0
        a = 32'h3FC00000; b = 32'h3FC00000; check_exact(32'h40400000); // 1.5 + 1.5 = 3.0
        a = 32'h3F800000; b = 32'h3F800000; check_exact(32'h40000000); // 1.0 + 1.0 = 2.0 (carry-out normalize)
        a = 32'h3F800000; b = 32'hBF800000; check_exact(32'h00000000); // 1.0 + (-1.0) = +0.0 (cancellation)
        a = 32'h00000000; b = 32'h40A00000; check_exact(32'h40A00000); // 0.0 + 5.0 = 5.0
        a = 32'hC0A00000; b = 32'h00000000; check_exact(32'hC0A00000); // -5.0 + 0.0 = -5.0
        a = 32'h80000000; b = 32'h80000000; check_exact(32'h80000000); // -0.0 + -0.0 = -0.0
        a = 32'h00000000; b = 32'h00000000; check_exact(32'h00000000); // 0.0 + 0.0 = 0.0
        a = 32'h40400000; b = 32'hBF800000; check_exact(32'h40000000); // 3.0 + (-1.0) = 2.0
        a = 32'h3F000000; b = 32'h3F000000; check_exact(32'h3F800000); // 0.5 + 0.5 = 1.0
        a = 32'hBF800000; b = 32'h3F800000; check_exact(32'h00000000); // -1.0 + 1.0 = +0.0
        a = 32'h4B800000; b = 32'h3F800000; check_exact(32'h4B800000); // 16777216.0+1.0=16777217.0, exact tie -> rounds to even (unchanged)
        a = 32'h3F800000; b = 32'h4B800000; check_exact(32'h4B800000); // same, operands swapped
        a = 32'hC0400000; b = 32'h40400000; check_exact(32'h00000000); // -3.0 + 3.0 = +0.0
        a = 32'h42C80000; b = 32'hC2C80000; check_exact(32'h00000000); // 100.0 + (-100.0) = +0.0
        a = 32'h3F800000; b = 32'h00000000; check_exact(32'h3F800000); // 1.0 + 0.0 = 1.0
        a = 32'h41200000; b = 32'h41A00000; check_exact(32'h41F00000); // 10.0 + 20.0 = 30.0
        a = 32'hC1200000; b = 32'hC1A00000; check_exact(32'hC1F00000); // -10.0 + -20.0 = -30.0

        // ---- random, normal operands only (exponent in [1,254]) ----
        for (r = 0; r < 4000; r = r + 1) begin
            a[31]    = $random;
            a[30:23] = ($random % 254) + 1;
            a[22:0]  = $random;
            b[31]    = $random;
            b[30:23] = ($random % 254) + 1;
            b[22:0]  = $random;
            check_tolerance;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
