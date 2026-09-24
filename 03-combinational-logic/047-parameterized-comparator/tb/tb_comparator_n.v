`timescale 1ns / 1ps

// tb_comparator_n: exhaustive 4-bit and random 16-bit coverage, each in
// both unsigned and signed configurations of the same comparator_n RTL.
module tb_comparator_n;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer i, n;

    // ---- WIDTH=4: exhaustive, unsigned and signed -------------------------
    reg  [3:0] a4, b4;
    wire       gtU4, ltU4, eqU4;
    wire       gtS4, ltS4, eqS4;

    comparator_n #(.WIDTH(4), .SIGNED(0)) dutU4 (.a(a4), .b(b4), .gt(gtU4), .lt(ltU4), .eq(eqU4));
    comparator_n #(.WIDTH(4), .SIGNED(1)) dutS4 (.a(a4), .b(b4), .gt(gtS4), .lt(ltS4), .eq(eqS4));

    // ---- WIDTH=16: random, unsigned and signed -----------------------------
    reg  [15:0] a16, b16;
    wire        gtU16, ltU16, eqU16;
    wire        gtS16, ltS16, eqS16;

    comparator_n #(.WIDTH(16), .SIGNED(0)) dutU16 (.a(a16), .b(b16), .gt(gtU16), .lt(ltU16), .eq(eqU16));
    comparator_n #(.WIDTH(16), .SIGNED(1)) dutS16 (.a(a16), .b(b16), .gt(gtS16), .lt(ltS16), .eq(eqS16));

    task check4(input [3:0] av, input [3:0] bv);
        reg expU_gt, expU_lt, expU_eq;
        reg expS_gt, expS_lt, expS_eq;
        begin
            a4 = av; b4 = bv;
            #1;
            expU_gt = (av > bv);       expU_lt = (av < bv);       expU_eq = (av == bv);
            expS_gt = ($signed(av) > $signed(bv));
            expS_lt = ($signed(av) < $signed(bv));
            expS_eq = ($signed(av) == $signed(bv));
            checks = checks + 1;
            if (gtU4 !== expU_gt || ltU4 !== expU_lt || eqU4 !== expU_eq) begin
                errors = errors + 1;
                $display("ERROR: unsigned4 a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          av, bv, expU_gt, expU_lt, expU_eq, gtU4, ltU4, eqU4);
            end
            checks = checks + 1;
            if (gtS4 !== expS_gt || ltS4 !== expS_lt || eqS4 !== expS_eq) begin
                errors = errors + 1;
                $display("ERROR: signed4 a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          $signed(av), $signed(bv), expS_gt, expS_lt, expS_eq, gtS4, ltS4, eqS4);
            end
        end
    endtask

    task check16(input [15:0] av, input [15:0] bv);
        reg expU_gt, expU_lt, expU_eq;
        reg expS_gt, expS_lt, expS_eq;
        begin
            a16 = av; b16 = bv;
            #1;
            expU_gt = (av > bv);       expU_lt = (av < bv);       expU_eq = (av == bv);
            expS_gt = ($signed(av) > $signed(bv));
            expS_lt = ($signed(av) < $signed(bv));
            expS_eq = ($signed(av) == $signed(bv));
            checks = checks + 1;
            if (gtU16 !== expU_gt || ltU16 !== expU_lt || eqU16 !== expU_eq) begin
                errors = errors + 1;
                $display("ERROR: unsigned16 a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          av, bv, expU_gt, expU_lt, expU_eq, gtU16, ltU16, eqU16);
            end
            checks = checks + 1;
            if (gtS16 !== expS_gt || ltS16 !== expS_lt || eqS16 !== expS_eq) begin
                errors = errors + 1;
                $display("ERROR: signed16 a=%0d b=%0d expected {gt,lt,eq}=%b%b%b actual=%b%b%b",
                          $signed(av), $signed(bv), expS_gt, expS_lt, expS_eq, gtS16, ltS16, eqS16);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_comparator_n.vcd");
            $dumpvars(0, tb_comparator_n);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("exhaustive WIDTH=4 sweep, unsigned + signed (256 pairs)...");
        for (i = 0; i < 16; i = i + 1)
            for (n = 0; n < 16; n = n + 1)
                check4(i[3:0], n[3:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("random WIDTH=16 sweep, unsigned + signed, seed=%0d (3000 pairs)...", seed);
        for (n = 0; n < 3000; n = n + 1)
            check16({$random(seed), $random(seed)}, {$random(seed), $random(seed)});
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        $display("directed WIDTH=16 sign-boundary corners...");
        check16(16'h0000, 16'h0000); check16(16'hFFFF, 16'hFFFF);
        check16(16'h7FFF, 16'h8000); check16(16'h8000, 16'h7FFF);   // max positive vs min negative
        check16(16'h0000, 16'hFFFF); check16(16'hFFFF, 16'h0000);   // 0 vs -1
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
