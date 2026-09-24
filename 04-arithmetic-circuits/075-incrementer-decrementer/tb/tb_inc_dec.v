`timescale 1ns / 1ps

// tb_inc_dec: exhaustive over all 256 values of an 8-bit a and both
// values of dec (512 cases), checked against a+1 / a-1 with correct
// 8-bit wrap-around and the expected wrap flag.
module tb_inc_dec;

    integer errors = 0;
    integer checks = 0;
    integer ai, di;

    reg  [7:0] a;
    reg        dec;
    wire [7:0] result;
    wire       wrap;

    inc_dec #(.WIDTH(8)) dut (.a(a), .dec(dec), .result(result), .wrap(wrap));

    task check;
        reg [8:0] expected_inc, expected_dec;
        begin
            #1;
            checks = checks + 1;
            expected_inc = a + 9'd1;
            expected_dec = a - 9'd1;
            if (!dec) begin
                if (result !== expected_inc[7:0] || wrap !== expected_inc[8]) begin
                    errors = errors + 1;
                    $display("ERROR(inc): a=%0d expected result=%0d wrap=%b actual result=%0d wrap=%b",
                              a, expected_inc[7:0], expected_inc[8], result, wrap);
                end
            end else begin
                if (result !== expected_dec[7:0] || wrap !== expected_dec[8]) begin
                    errors = errors + 1;
                    $display("ERROR(dec): a=%0d expected result=%0d wrap=%b actual result=%0d wrap=%b",
                              a, expected_dec[7:0], expected_dec[8], result, wrap);
                end
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_inc_dec.vcd");
            $dumpvars(0, tb_inc_dec);
        end

        for (ai = 0; ai < 256; ai = ai + 1)
            for (di = 0; di < 2; di = di + 1) begin
                a = ai[7:0]; dec = di[0];
                check;
            end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
