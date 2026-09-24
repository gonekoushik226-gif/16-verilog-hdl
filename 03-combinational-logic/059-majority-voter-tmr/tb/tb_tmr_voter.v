`timescale 1ns / 1ps

// tb_tmr_voter: checks the no-fault case, then injects single-copy faults
// (which TMR must mask completely) and same-bit double-copy faults (which
// TMR cannot mask, since two faulty copies then form the majority) —
// demonstrating both what TMR guarantees and its fundamental limit.
module tb_tmr_voter;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer g, copy_i, copy_j, bit_i;
    reg  [WIDTH-1:0] golden;

    reg  [WIDTH-1:0] a, b, c;
    wire [WIDTH-1:0] voted;
    wire              disagree;

    tmr_voter #(.WIDTH(WIDTH)) dut (.a(a), .b(b), .c(c), .voted(voted), .disagree(disagree));

    task check_no_fault(input [WIDTH-1:0] golden);
        begin
            a = golden; b = golden; c = golden;
            #1;
            checks = checks + 1;
            if (voted !== golden || disagree !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR: no-fault golden=%b expected voted=%b disagree=0 actual voted=%b disagree=%b",
                          golden, golden, voted, disagree);
            end
        end
    endtask

    // Flips exactly one bit of exactly one of the three copies. TMR's
    // 2-of-3 majority must still recover the golden value at every bit.
    task check_single_fault(input [WIDTH-1:0] golden, input integer copy, input integer bp);
        reg [WIDTH-1:0] fa, fb, fc;
        begin
            fa = golden; fb = golden; fc = golden;
            case (copy)
                0: fa[bp] = ~fa[bp];
                1: fb[bp] = ~fb[bp];
                default: fc[bp] = ~fc[bp];
            endcase
            a = fa; b = fb; c = fc;
            #1;
            checks = checks + 1;
            if (voted !== golden || disagree !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: single-fault golden=%b copy=%0d bit=%0d expected voted=%b disagree=1 actual voted=%b disagree=%b",
                          golden, copy, bp, golden, voted, disagree);
            end
        end
    endtask

    // Flips the SAME bit position in two of the three copies. The two
    // faulty copies now agree with each other and outvote the one good
    // copy at that bit, so TMR cannot recover the golden value there —
    // this is the fault TMR is fundamentally unable to correct.
    task check_double_fault_same_bit(input [WIDTH-1:0] golden, input integer ci, input integer cj, input integer bp);
        reg [WIDTH-1:0] fa, fb, fc;
        reg [WIDTH-1:0] expected;
        begin
            fa = golden; fb = golden; fc = golden;
            case (ci)
                0: fa[bp] = ~fa[bp];
                1: fb[bp] = ~fb[bp];
                default: fc[bp] = ~fc[bp];
            endcase
            case (cj)
                0: fa[bp] = ~fa[bp];
                1: fb[bp] = ~fb[bp];
                default: fc[bp] = ~fc[bp];
            endcase
            a = fa; b = fb; c = fc;
            #1;
            expected = golden;
            expected[bp] = ~golden[bp];   // the two faulty copies outvote the good one at this bit
            checks = checks + 1;
            if (voted !== expected || disagree !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: double-fault golden=%b copies={%0d,%0d} bit=%0d expected voted=%b disagree=1 actual voted=%b disagree=%b",
                          golden, ci, cj, bp, expected, voted, disagree);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_tmr_voter.vcd");
            $dumpvars(0, tb_tmr_voter);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("no-fault sweep: directed + random golden values...");
        check_no_fault(8'h00); check_no_fault(8'hFF);
        check_no_fault(8'hAA); check_no_fault(8'h55);
        for (g = 0; g < 200; g = g + 1)
            check_no_fault($random(seed));
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("single-copy-fault sweep: every copy x every bit x directed/random goldens...");
        for (g = 0; g < 20; g = g + 1) begin
            golden = (g == 0) ? 8'h00 : (g == 1) ? 8'hFF : $random(seed);
            for (copy_i = 0; copy_i < 3; copy_i = copy_i + 1)
                for (bit_i = 0; bit_i < WIDTH; bit_i = bit_i + 1)
                    check_single_fault(golden, copy_i, bit_i);
        end
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        $display("double-copy-fault (same bit) sweep: every copy pair x every bit x directed/random goldens...");
        for (g = 0; g < 20; g = g + 1) begin
            golden = (g == 0) ? 8'h00 : (g == 1) ? 8'hFF : $random(seed);
            for (copy_i = 0; copy_i < 3; copy_i = copy_i + 1)
                for (copy_j = copy_i + 1; copy_j < 3; copy_j = copy_j + 1)
                    for (bit_i = 0; bit_i < WIDTH; bit_i = bit_i + 1)
                        check_double_fault_same_bit(golden, copy_i, copy_j, bit_i);
        end
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
