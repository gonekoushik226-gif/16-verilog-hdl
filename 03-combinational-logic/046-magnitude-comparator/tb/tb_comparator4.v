`timescale 1ns / 1ps

// tb_comparator4: exhaustive check of the standalone 4-bit comparator
// (cascade tied to the "equal" idle state), plus a directed cascading test
// that chains two comparator4 instances into an 8-bit comparator to prove
// the 7485-style cascade inputs actually work across module boundaries.
module tb_comparator4;

    integer errors = 0;
    integer checks = 0;

    // ------------------------------------------------------------------
    // Part 1: exhaustive 4-bit comparator, cascade tied idle
    // ------------------------------------------------------------------
    reg  [3:0] a, b;
    wire       gt, lt, eq;

    comparator4 dut (
        .a(a), .b(b),
        .cin_gt(1'b0), .cin_lt(1'b0), .cin_eq(1'b1),
        .gt(gt), .lt(lt), .eq(eq)
    );

    task check4(input [3:0] av, input [3:0] bv);
        reg exp_gt, exp_lt, exp_eq;
        begin
            a = av; b = bv;
            #1;
            exp_gt = (av > bv);
            exp_lt = (av < bv);
            exp_eq = (av == bv);
            checks = checks + 1;
            if (gt !== exp_gt || lt !== exp_lt || eq !== exp_eq) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          av, bv, exp_gt, exp_lt, exp_eq, gt, lt, eq);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Part 2: two comparator4 cells cascaded into an 8-bit comparator
    //   {a_hi,a_lo} vs {b_hi,b_lo}: the high stage is evaluated first and
    //   feeds its gt/lt/eq into the low stage's cascade inputs, exactly
    //   as multiple 74LS85 packages are chained for wider buses.
    // ------------------------------------------------------------------
    reg  [3:0] a_hi, a_lo, b_hi, b_lo;
    wire       hi_gt, hi_lt, hi_eq;
    wire       cas_gt, cas_lt, cas_eq;

    comparator4 stage_hi (
        .a(a_hi), .b(b_hi),
        .cin_gt(1'b0), .cin_lt(1'b0), .cin_eq(1'b1),
        .gt(hi_gt), .lt(hi_lt), .eq(hi_eq)
    );
    comparator4 stage_lo (
        .a(a_lo), .b(b_lo),
        .cin_gt(hi_gt), .cin_lt(hi_lt), .cin_eq(hi_eq),
        .gt(cas_gt), .lt(cas_lt), .eq(cas_eq)
    );

    task check8(input [7:0] av, input [7:0] bv);
        reg exp_gt, exp_lt, exp_eq;
        begin
            {a_hi, a_lo} = av; {b_hi, b_lo} = bv;
            #1;
            exp_gt = (av > bv);
            exp_lt = (av < bv);
            exp_eq = (av == bv);
            checks = checks + 1;
            if (cas_gt !== exp_gt || cas_lt !== exp_lt || cas_eq !== exp_eq) begin
                errors = errors + 1;
                $display("ERROR: cascaded a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          av, bv, exp_gt, exp_lt, exp_eq, cas_gt, cas_lt, cas_eq);
            end
        end
    endtask

    integer i, j;
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_comparator4.vcd");
            $dumpvars(0, tb_comparator4);
        end

        $display("exhaustive 4-bit comparator sweep (256 pairs)...");
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                check4(i[3:0], j[3:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("directed 8-bit cascade test...");
        check8(8'h00, 8'h00); check8(8'hFF, 8'hFF); check8(8'h00, 8'hFF);
        check8(8'hFF, 8'h00); check8(8'h7F, 8'h80); check8(8'h80, 8'h7F);
        check8(8'h55, 8'h55); check8(8'hAA, 8'h55); check8(8'h0F, 8'hF0);
        // every case where the high nibble is equal so the low-nibble
        // comparison, gated by the cascade, must decide the outcome
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                check8({4'h5, i[3:0]}, {4'h5, j[3:0]});
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
