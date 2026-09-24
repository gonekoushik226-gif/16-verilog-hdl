`timescale 1ns / 1ps

module tb_arith_ops;

    reg  [3:0] a, b;
    wire [4:0] sum;
    wire [3:0] diff, quotient, remainder, shl, shr, ashr;
    wire [7:0] product;
    wire       borrow, div_by_zero, lt, le, gt, ge, eq, ne;

    integer errors = 0;
    integer checks = 0;
    integer i, j, sh, e_ashr, e_diff;

    arith_ops dut (
        .a(a), .b(b), .sum(sum), .diff(diff), .borrow(borrow), .product(product),
        .quotient(quotient), .remainder(remainder), .div_by_zero(div_by_zero),
        .lt(lt), .le(le), .gt(gt), .ge(ge), .eq(eq), .ne(ne),
        .shl(shl), .shr(shr), .ashr(ashr)
    );

    // Integer (32-bit) reference model
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_arith_ops.vcd");
            $dumpvars(0, tb_arith_ops);
        end

        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                a = i; b = j;
                #1;
                sh = j % 4;
                e_diff = (i - j + 16) % 16;
                // arithmetic shift of the 4-bit two's complement value of i
                e_ashr = ((i >= 8) ? i - 16 : i);
                e_ashr = (e_ashr >>> sh) & 15;   // integer is signed, >>> sign-fills
                checks = checks + 1;
                if (sum !== i + j || diff !== e_diff || borrow !== (i < j) ||
                    product !== i * j ||
                    quotient  !== ((j == 0) ? 0 : i / j) ||
                    remainder !== ((j == 0) ? 0 : i % j) ||
                    div_by_zero !== (j == 0) ||
                    lt !== (i < j) || le !== (i <= j) || gt !== (i > j) ||
                    ge !== (i >= j) || eq !== (i == j) || ne !== (i != j) ||
                    shl !== ((i << sh) & 15) || shr !== (i >> sh) || ashr !== e_ashr) begin
                    errors = errors + 1;
                    $display("ERROR: a=%0d b=%0d sum=%0d diff=%0d prod=%0d q=%0d r=%0d shl=%b shr=%b ashr=%b(exp %b)",
                             a, b, sum, diff, product, quotient, remainder, shl, shr, ashr, e_ashr[3:0]);
                end
            end

        $display("  a  b | sum diff brw prod  q  r dz | lt eq gt | shl  shr  ashr");
        a = 4'd13; b = 4'd6; #1
        $display(" %2d %2d | %2d  %2d   %b  %3d %2d %2d  %b |  %b  %b  %b | %b %b %b", a, b, sum, diff, borrow, product, quotient, remainder, div_by_zero, lt, eq, gt, shl, shr, ashr);
        a = 4'd3;  b = 4'd9; #1
        $display(" %2d %2d | %2d  %2d   %b  %3d %2d %2d  %b |  %b  %b  %b | %b %b %b", a, b, sum, diff, borrow, product, quotient, remainder, div_by_zero, lt, eq, gt, shl, shr, ashr);
        a = 4'd15; b = 4'd15; #1
        $display(" %2d %2d | %2d  %2d   %b  %3d %2d %2d  %b |  %b  %b  %b | %b %b %b", a, b, sum, diff, borrow, product, quotient, remainder, div_by_zero, lt, eq, gt, shl, shr, ashr);
        a = 4'd9;  b = 4'd0; #1
        $display(" %2d %2d | %2d  %2d   %b  %3d %2d %2d  %b |  %b  %b  %b | %b %b %b", a, b, sum, diff, borrow, product, quotient, remainder, div_by_zero, lt, eq, gt, shl, shr, ashr);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
