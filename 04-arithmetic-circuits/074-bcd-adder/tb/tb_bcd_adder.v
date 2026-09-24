`timescale 1ns / 1ps

// tb_bcd_adder: two independent DUTs. dut_digit exhaustively covers
// every valid single-digit BCD pair (10 x 10 x 2 cin = 200 cases)
// against a decimal reference. dut4 covers 2000 random 4-digit decimal
// numbers (0000-9999) added together, decoded digit by digit and
// compared against a plain integer reference built from those digits.
module tb_bcd_adder;

    integer errors = 0;
    integer checks = 0;
    integer da, db, ci, r, d;

    // ---- single digit, exhaustive ----
    reg  [3:0] a1, b1;
    reg        cin1;
    wire [3:0] sum1;
    wire       cout1;

    bcd_digit_adder dut_digit (.a(a1), .b(b1), .cin(cin1), .sum(sum1), .cout(cout1));

    // ---- 4-digit, random ----
    reg  [15:0] a4, b4;
    reg         cin4;
    wire [15:0] sum4;
    wire        cout4;

    bcd_adder #(.DIGITS(4)) dut4 (.a(a4), .b(b4), .cin(cin4), .sum(sum4), .cout(cout4));

    task check_digit;
        integer expected;
        begin
            #1;
            checks = checks + 1;
            expected = da + db + ci;
            if (sum1 != expected % 10 || cout1 != (expected >= 10)) begin
                errors = errors + 1;
                $display("ERROR(digit): a=%0d b=%0d cin=%0d expected sum=%0d cout=%0d actual sum=%0d cout=%0d",
                          da, db, ci, expected % 10, expected >= 10, sum1, cout1);
            end
        end
    endtask

    function integer bcd_to_int;
        input [15:0] bcd;
        begin
            bcd_to_int = bcd[3:0] + bcd[7:4]*10 + bcd[11:8]*100 + bcd[15:12]*1000;
        end
    endfunction

    task check4;
        integer expected;
        begin
            #1;
            checks = checks + 1;
            expected = bcd_to_int(a4) + bcd_to_int(b4) + cin4;
            if (bcd_to_int(sum4) + cout4*10000 !== expected) begin
                errors = errors + 1;
                $display("ERROR(4-digit): a=%0d b=%0d cin=%0d expected total=%0d actual sum=%0d cout=%0d",
                          bcd_to_int(a4), bcd_to_int(b4), cin4, expected, bcd_to_int(sum4), cout4);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bcd_adder.vcd");
            $dumpvars(0, tb_bcd_adder);
        end

        for (da = 0; da < 10; da = da + 1)
            for (db = 0; db < 10; db = db + 1)
                for (ci = 0; ci < 2; ci = ci + 1) begin
                    a1 = da[3:0]; b1 = db[3:0]; cin1 = ci[0];
                    check_digit;
                end

        for (r = 0; r < 2000; r = r + 1) begin
            // build random-but-valid BCD digits (each nibble 0-9)
            a4 = 0; b4 = 0;
            for (d = 0; d < 4; d = d + 1) begin
                a4 = a4 | (($random % 10 + 10) % 10) << (d*4);
                b4 = b4 | (($random % 10 + 10) % 10) << (d*4);
            end
            cin4 = $random;
            check4;
        end
        // corner case: 9999 + 9999 + 1
        a4 = 16'h9999; b4 = 16'h9999; cin4 = 1'b1; check4;
        a4 = 16'h0000; b4 = 16'h0000; cin4 = 1'b0; check4;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
