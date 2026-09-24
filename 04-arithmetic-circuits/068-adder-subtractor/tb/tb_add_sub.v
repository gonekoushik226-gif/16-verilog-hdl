`timescale 1ns / 1ps

// tb_add_sub: exhaustive over 4-bit a, 4-bit b and sub (2^9 = 512 cases).
// result/carry_out are checked against unsigned arithmetic; overflow and
// negative are checked against a signed 4-bit two's-complement model;
// zero is checked directly.
module tb_add_sub;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi, si;

    reg  [3:0] a, b;
    reg        sub;
    wire [3:0] result;
    wire       carry_out, overflow, zero, negative;

    add_sub dut (.a(a), .b(b), .sub(sub), .result(result), .carry_out(carry_out),
                 .overflow(overflow), .zero(zero), .negative(negative));

    task check;
        reg [4:0] unsigned_expected;      // a+b or a-b (mod 32, bit4 = carry/~borrow)
        reg signed [4:0] signed_a, signed_b, signed_expected;
        reg expected_ovf;
        begin
            #1;
            checks = checks + 1;

            if (!sub) unsigned_expected = a + b;
            // two's-complement subtract = a + (~b) + 1; widen a to 5 bits
            // with a leading 1 so bit4 of the result reads back as
            // "no borrow" (1) or "borrow occurred" (0), matching carry_out.
            else      unsigned_expected = {1'b1, a} - b;

            signed_a = {{1{a[3]}}, a};
            signed_b = {{1{b[3]}}, b};
            signed_expected = sub ? (signed_a - signed_b) : (signed_a + signed_b);
            expected_ovf = (signed_expected > 5'sd7) || (signed_expected < -5'sd8);

            if (result   !== unsigned_expected[3:0] ||
                carry_out!== unsigned_expected[4]   ||
                overflow !== expected_ovf            ||
                zero     !== (result == 4'b0)        ||
                negative !== result[3]) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d sub=%b expected result=%0d carry=%b ovf=%b actual result=%0d carry=%b ovf=%b zero=%b neg=%b",
                          a, b, sub, unsigned_expected[3:0], unsigned_expected[4], expected_ovf,
                          result, carry_out, overflow, zero, negative);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_add_sub.vcd");
            $dumpvars(0, tb_add_sub);
        end

        for (ai = 0; ai < 16; ai = ai + 1)
            for (bi = 0; bi < 16; bi = bi + 1)
                for (si = 0; si < 2; si = si + 1) begin
                    a = ai[3:0]; b = bi[3:0]; sub = si[0];
                    check;
                end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
