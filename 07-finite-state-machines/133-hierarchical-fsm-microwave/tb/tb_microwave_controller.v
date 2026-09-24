`timescale 1ns / 1ps

// tb_microwave_controller: exercises the INTEGRATED design (main FSM +
// door_monitor + countdown_timer). Scenarios: a full cook cycle with
// exact dwell; a door-open pause mid-cook, verifying the total time to
// done_beep grows by exactly the paused duration; cancel from both
// S_COOKING and S_PAUSED; the door-open start interlock; and clearing
// done_beep back to idle via start or cancel.
module tb_microwave_controller;

    localparam WIDTH = 8, COOK_TIME = 10;

    integer errors = 0;
    integer checks = 0;
    integer cycle_count = 0;

    reg clk = 0;
    reg rst_n, start, cancel, door_open_raw;
    reg [WIDTH-1:0] cook_time;
    wire cooking, paused, done_beep, idle;

    microwave_controller #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .cancel(cancel),
        .door_open_raw(door_open_raw), .cook_time(cook_time),
        .cooking(cooking), .paused(paused), .done_beep(done_beep), .idle(idle)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    // 0=IDLE,1=COOKING,2=PAUSED,3=DONE,-1=invalid
    function integer phase_code;
        input i, c, p, d;
        begin
            if (i && !c && !p && !d) phase_code = 0;
            else if (!i && c && !p && !d) phase_code = 1;
            else if (!i && !c && p && !d) phase_code = 2;
            else if (!i && !c && !p && d) phase_code = 3;
            else phase_code = -1;
        end
    endfunction

    task expect_valid;
        begin
            checks = checks + 1;
            if (phase_code(idle, cooking, paused, done_beep) == -1) begin
                errors = errors + 1;
                $display("ERROR: invalid phase combo at cycle %0d", cycle_count);
            end
        end
    endtask

    task do_reset;
        begin
            rst_n = 0; start = 0; cancel = 0; door_open_raw = 0; cook_time = COOK_TIME;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk); start = 1'b1;
            @(posedge clk); #1; start = 1'b0;
        end
    endtask

    task pulse_cancel;
        begin
            @(negedge clk); cancel = 1'b1;
            @(posedge clk); #1; cancel = 1'b0;
        end
    endtask

    task wait_until_phase(input integer expected, output integer elapsed);
        integer start_cycle, watchdog;
        reg found;
        begin
            start_cycle = cycle_count;
            watchdog = 0; found = 0;
            while (!found) begin
                @(posedge clk); #1;
                expect_valid;
                watchdog = watchdog + 1;
                if (phase_code(idle, cooking, paused, done_beep) == expected) found = 1;
                else if (watchdog > 500) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for phase=%0d", expected);
                    found = 1;
                end
            end
            elapsed = cycle_count - start_cycle;
        end
    endtask

    integer elapsed;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_microwave_controller.vcd");
            $dumpvars(0, tb_microwave_controller);
        end

        do_reset;
        checks = checks + 1;
        if (!idle) begin errors = errors + 1; $display("ERROR: not idle after reset"); end

        // --- full cook cycle, door closed throughout ---
        pulse_start;
        wait_until_phase(3, elapsed);   // -> DONE
        checks = checks + 1;
        if (elapsed !== COOK_TIME + 1) begin
            errors = errors + 1;
            $display("ERROR: cook dwell=%0d expected=%0d", elapsed, COOK_TIME + 1);
        end

        // clearing DONE via start begins a fresh cook
        pulse_start;
        checks = checks + 1;
        if (!cooking) begin errors = errors + 1; $display("ERROR: expected cooking after start from DONE"); end

        // --- cancel mid-cook returns immediately to idle ---
        pulse_cancel;
        checks = checks + 1;
        if (!idle) begin errors = errors + 1; $display("ERROR: expected idle immediately after cancel"); end

        // --- door-open pause mid-cook: total time to DONE grows by
        // exactly the paused duration ---
        begin : cook_with_pause
            integer start_cycle, pause_len;
            pulse_start;
            start_cycle = cycle_count;
            pause_len = 6;
            repeat (3) begin @(posedge clk); #1; expect_valid; end
            checks = checks + 1;
            if (!cooking) begin errors = errors + 1; $display("ERROR: expected still cooking before door opens"); end

            door_open_raw = 1'b1;
            wait_until_phase(2, elapsed);        // -> PAUSED
            repeat (pause_len) begin @(posedge clk); #1; expect_valid; end
            door_open_raw = 1'b0;

            wait_until_phase(1, elapsed);        // -> resumes COOKING
            wait_until_phase(3, elapsed);         // -> DONE
            elapsed = cycle_count - start_cycle;
            checks = checks + 1;
            // total = normal dwell (COOK_TIME+1) + two cycles of registered
            // latency before the timer actually freezes (door_monitor's own
            // registration, then the timer's pre-edge read of door_open)
            // + the paused duration itself, all added on top
            if (elapsed !== (COOK_TIME + 1) + 2 + pause_len) begin
                errors = errors + 1;
                $display("ERROR: cook-with-pause total=%0d expected=%0d",
                          elapsed, (COOK_TIME + 1) + 2 + pause_len);
            end
        end

        // clear DONE
        pulse_cancel;

        // --- cancel while PAUSED returns to idle ---
        pulse_start;
        repeat (2) begin @(posedge clk); #1; end
        door_open_raw = 1'b1;
        wait_until_phase(2, elapsed);   // -> PAUSED
        pulse_cancel;
        checks = checks + 1;
        if (!idle) begin errors = errors + 1; $display("ERROR: expected idle after cancel while paused"); end
        door_open_raw = 1'b0;
        @(posedge clk); #1;

        // --- safety interlock: cannot start while door is open ---
        door_open_raw = 1'b1;
        @(posedge clk); #1;   // let door_monitor register it
        pulse_start;
        checks = checks + 1;
        if (!idle) begin
            errors = errors + 1;
            $display("ERROR: expected to stay idle when starting with door open, got cooking=%b", cooking);
        end
        door_open_raw = 1'b0;
        @(posedge clk); #1;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
