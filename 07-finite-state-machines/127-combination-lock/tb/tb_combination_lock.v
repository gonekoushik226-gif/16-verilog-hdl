`timescale 1ns / 1ps

// tb_combination_lock: directed scenarios covering correct entry,
// incorrect entry (with recovery to a fresh attempt), lockout after
// MAX_FAILS consecutive failures (verifying input is ignored during
// lockout, even a fully correct digit), automatic unlock after the
// lockout period, and relocking.
module tb_combination_lock;

    localparam MAX_FAILS = 3, LOCKOUT_TIME = 8;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg enter, relock;
    reg [3:0] digit_in;
    wire unlocked, locked_out;
    wire [1:0] fail_count_out;

    combination_lock #(
        .CODE_0(4'd3), .CODE_1(4'd1), .CODE_2(4'd4), .CODE_3(4'd1),
        .MAX_FAILS(MAX_FAILS), .LOCKOUT_TIME(LOCKOUT_TIME)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enter(enter), .digit_in(digit_in),
        .relock(relock), .unlocked(unlocked), .locked_out(locked_out),
        .fail_count_out(fail_count_out)
    );

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; enter = 0; relock = 0; digit_in = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task enter_digit(input [3:0] d);
        begin
            @(negedge clk);
            enter = 1'b1; digit_in = d;
            @(posedge clk); #1;
            enter = 1'b0;
        end
    endtask

    task pulse_relock;
        begin
            @(negedge clk); relock = 1'b1;
            @(posedge clk); #1; relock = 1'b0;
        end
    endtask

    task check(input exp_unlocked, input exp_locked_out, input [1:0] exp_fail, input [255:0] label);
        begin
            checks = checks + 1;
            if (unlocked !== exp_unlocked || locked_out !== exp_locked_out
                || fail_count_out !== exp_fail) begin
                errors = errors + 1;
                $display("ERROR: %0s unlocked=%b(exp %b) locked_out=%b(exp %b) fail=%0d(exp %0d)",
                          label, unlocked, exp_unlocked, locked_out, exp_locked_out,
                          fail_count_out, exp_fail);
            end
        end
    endtask

    integer k;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_combination_lock.vcd");
            $dumpvars(0, tb_combination_lock);
        end

        // --- Scenario 1: correct code entry (3,1,4,1) ---
        do_reset;
        check(1'b0, 1'b0, 2'd0, "reset");
        enter_digit(4'd3); check(1'b0, 1'b0, 2'd0, "after digit 1 correct");
        enter_digit(4'd1); check(1'b0, 1'b0, 2'd0, "after digit 2 correct");
        enter_digit(4'd4); check(1'b0, 1'b0, 2'd0, "after digit 3 correct");
        enter_digit(4'd1); check(1'b1, 1'b0, 2'd0, "after digit 4 correct -> unlocked");

        // --- Scenario 2: relock, then a wrong digit resets to S0 with
        // fail_count incremented, and a subsequent correct attempt
        // still succeeds since MAX_FAILS was not reached ---
        pulse_relock;
        check(1'b0, 1'b0, 2'd0, "after relock");
        enter_digit(4'd3);                       // correct 1st digit
        enter_digit(4'd9);                       // WRONG 2nd digit
        check(1'b0, 1'b0, 2'd1, "after 1 wrong attempt");
        enter_digit(4'd3); enter_digit(4'd1); enter_digit(4'd4); enter_digit(4'd1);
        check(1'b1, 1'b0, 2'd0, "recovers and unlocks, fail_count cleared");

        // --- Scenario 3: MAX_FAILS consecutive wrong attempts -> lockout ---
        pulse_relock;
        for (k = 0; k < MAX_FAILS; k = k + 1) begin
            enter_digit(4'd0);                   // wrong 1st digit every time
        end
        // fail_count holds MAX_FAILS while locked out -- it is only
        // cleared once the lockout timer actually expires
        check(1'b0, 1'b1, MAX_FAILS[1:0], "locked out after MAX_FAILS wrong attempts");

        // during lockout, even the FULLY correct sequence is ignored
        enter_digit(4'd3); enter_digit(4'd1); enter_digit(4'd4); enter_digit(4'd1);
        check(1'b0, 1'b1, MAX_FAILS[1:0], "still locked out, correct code ignored");

        // wait out the remaining lockout cycles, then confirm it clears
        // and normal entry works again
        for (k = 0; k < LOCKOUT_TIME + 2; k = k + 1) begin
            @(posedge clk); #1;
        end
        check(1'b0, 1'b0, 2'd0, "lockout expired, back to S0");
        enter_digit(4'd3); enter_digit(4'd1); enter_digit(4'd4); enter_digit(4'd1);
        check(1'b1, 1'b0, 2'd0, "unlocks normally after lockout expired");

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
