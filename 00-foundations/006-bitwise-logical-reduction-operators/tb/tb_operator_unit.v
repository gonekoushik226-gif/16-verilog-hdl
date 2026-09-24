`timescale 1ns / 1ps

module tb_operator_unit;

    reg  [3:0] a, b;
    wire [3:0] and_bw, or_bw, xor_bw, not_a;
    wire       and_log, or_log, not_log;
    wire       red_and, red_or, red_xor, red_nand, red_nor, red_xnor;

    integer errors = 0;
    integer checks = 0;
    integer i, j, k;

    // expected values built one bit at a time with if-statements only
    reg [3:0] e_and, e_or, e_xor, e_not;
    reg       e_andl, e_orl, e_notl, e_rand, e_ror, e_rxor;
    integer   ones_a;

    operator_unit dut (
        .a(a), .b(b), .and_bw(and_bw), .or_bw(or_bw), .xor_bw(xor_bw), .not_a(not_a),
        .and_log(and_log), .or_log(or_log), .not_log(not_log),
        .red_and(red_and), .red_or(red_or), .red_xor(red_xor),
        .red_nand(red_nand), .red_nor(red_nor), .red_xnor(red_xnor)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_operator_unit.vcd");
            $dumpvars(0, tb_operator_unit);
        end

        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j;
                #1;
                ones_a = 0;
                for (k = 0; k < 4; k = k + 1) begin
                    e_and[k] = (a[k] == 1 && b[k] == 1) ? 1'b1 : 1'b0;
                    e_or[k]  = (a[k] == 1 || b[k] == 1) ? 1'b1 : 1'b0;
                    e_xor[k] = (a[k] != b[k])           ? 1'b1 : 1'b0;
                    e_not[k] = (a[k] == 0)              ? 1'b1 : 1'b0;
                    ones_a   = ones_a + a[k];
                end
                e_andl = (i != 0) && (j != 0);
                e_orl  = (i != 0) || (j != 0);
                e_notl = (i == 0);
                e_rand = (ones_a == 4);
                e_ror  = (ones_a != 0);
                e_rxor = (ones_a % 2 == 1);
                checks = checks + 1;
                if (and_bw !== e_and || or_bw !== e_or || xor_bw !== e_xor || not_a !== e_not ||
                    and_log !== e_andl || or_log !== e_orl || not_log !== e_notl ||
                    red_and !== e_rand || red_or !== e_ror || red_xor !== e_rxor ||
                    red_nand !== ~e_rand || red_nor !== ~e_ror || red_xnor !== ~e_rxor) begin
                    errors = errors + 1;
                    $display("ERROR: a=%b b=%b", a, b);
                end
            end

        // A few rows that show the difference between the families
        $display("   a    b  | a&b  a&&b | a|b  a||b | ~a   !a | &a |a ^a");
        a = 4'b0101; b = 4'b1010; #1
        $display(" %b %b | %b   %b  | %b   %b  | %b  %b |  %b  %b  %b", a, b, and_bw, and_log, or_bw, or_log, not_a, not_log, red_and, red_or, red_xor);
        a = 4'b0000; b = 4'b1111; #1
        $display(" %b %b | %b   %b  | %b   %b  | %b  %b |  %b  %b  %b", a, b, and_bw, and_log, or_bw, or_log, not_a, not_log, red_and, red_or, red_xor);
        a = 4'b1111; b = 4'b0001; #1
        $display(" %b %b | %b   %b  | %b   %b  | %b  %b |  %b  %b  %b", a, b, and_bw, and_log, or_bw, or_log, not_a, not_log, red_and, red_or, red_xor);
        a = 4'b0111; b = 4'b1000; #1
        $display(" %b %b | %b   %b  | %b   %b  | %b  %b |  %b  %b  %b", a, b, and_bw, and_log, or_bw, or_log, not_a, not_log, red_and, red_or, red_xor);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
