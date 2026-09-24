`timescale 1ns / 1ps

module tb_signed_ops;

    reg  signed [3:0] a, b;
    wire signed [4:0] sum_full, neg_a;
    wire signed [3:0] sum_wrap;
    wire signed [7:0] sext_a, product;
    wire        [7:0] zext_a;
    wire        [3:0] abs_a;
    wire              overflow, lt_signed, lt_unsigned;

    integer errors = 0;
    integer checks = 0;
    integer i, j, va, vb, s, s_wrap, ua, ub;

    signed_ops dut (
        .a(a), .b(b), .sum_full(sum_full), .sum_wrap(sum_wrap), .overflow(overflow),
        .neg_a(neg_a), .abs_a(abs_a), .sext_a(sext_a), .zext_a(zext_a),
        .lt_signed(lt_signed), .lt_unsigned(lt_unsigned), .product(product)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_signed_ops.vcd");
            $dumpvars(0, tb_signed_ops);
        end

        for (i = -8; i < 8; i = i + 1)
            for (j = -8; j < 8; j = j + 1) begin
                a = i; b = j;
                #1;
                va = i; vb = j; s = i + j;
                s_wrap = (s > 7) ? s - 16 : (s < -8) ? s + 16 : s;
                ua = (i < 0) ? i + 16 : i;     // same bit pattern read as unsigned
                ub = (j < 0) ? j + 16 : j;
                checks = checks + 1;
                if (sum_full !== s || sum_wrap !== s_wrap || overflow !== (s > 7 || s < -8) ||
                    neg_a !== -va || abs_a !== ((va < 0) ? -va : va) ||
                    sext_a !== va || zext_a !== ua ||
                    lt_signed !== (va < vb) || lt_unsigned !== (ua < ub) ||
                    product !== va * vb) begin
                    errors = errors + 1;
                    $display("ERROR: a=%0d b=%0d sum_full=%0d sum_wrap=%0d ovf=%b neg=%0d abs=%0d sext=%0d zext=%0d lts=%b ltu=%b prod=%0d",
                             a, b, sum_full, sum_wrap, overflow, neg_a, abs_a, sext_a, zext_a,
                             lt_signed, lt_unsigned, product);
                end
            end

        $display("  a  b | sum_full sum_wrap ovf | -a |a| | sext_a    zext_a   | a<b(s) a<b(u) | a*b");
        a = 4'sd7;  b = 4'sd3;  #1
        $display(" %2d %2d |   %3d      %3d     %b  | %2d  %0d  | %b %b |   %b      %b    | %0d", a, b, sum_full, sum_wrap, overflow, neg_a, abs_a, sext_a, zext_a, lt_signed, lt_unsigned, product);
        a = -4'sd8; b = -4'sd1; #1
        $display(" %2d %2d |   %3d      %3d     %b  | %2d  %0d  | %b %b |   %b      %b    | %0d", a, b, sum_full, sum_wrap, overflow, neg_a, abs_a, sext_a, zext_a, lt_signed, lt_unsigned, product);
        a = -4'sd3; b = 4'sd2;  #1
        $display(" %2d %2d |   %3d      %3d     %b  | %2d  %0d  | %b %b |   %b      %b    | %0d", a, b, sum_full, sum_wrap, overflow, neg_a, abs_a, sext_a, zext_a, lt_signed, lt_unsigned, product);
        a = -4'sd8; b = -4'sd8; #1
        $display(" %2d %2d |   %3d      %3d     %b  | %2d  %0d  | %b %b |   %b      %b    | %0d", a, b, sum_full, sum_wrap, overflow, neg_a, abs_a, sext_a, zext_a, lt_signed, lt_unsigned, product);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
