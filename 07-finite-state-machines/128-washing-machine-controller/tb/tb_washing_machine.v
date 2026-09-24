`timescale 1ns / 1ps

// tb_washing_machine: runs a complete FILL->WASH->RINSE->SPIN->DONE
// cycle (checking exact per-phase dwell, all TIME+1 cycles per the
// registered-timer-done pattern established in programs 124/126),
// a lid-open pause mid-phase (checking the paused phase's TOTAL dwell
// grows by exactly the paused duration, with no progress made while
// paused), and a cancel mid-phase (checking immediate return to IDLE).
module tb_washing_machine;

    localparam WIDTH = 8, FILL_TIME = 4, WASH_TIME = 8, RINSE_TIME = 5, SPIN_TIME = 6;

    integer errors = 0;
    integer checks = 0;
    integer cycle_count = 0;

    reg clk = 0;
    reg rst_n, start, cancel, lid_open;
    wire filling, washing, rinsing, spinning, done_light, idle;

    washing_machine #(
        .WIDTH(WIDTH), .FILL_TIME(FILL_TIME), .WASH_TIME(WASH_TIME),
        .RINSE_TIME(RINSE_TIME), .SPIN_TIME(SPIN_TIME)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .cancel(cancel), .lid_open(lid_open),
        .filling(filling), .washing(washing), .rinsing(rinsing),
        .spinning(spinning), .done_light(done_light), .idle(idle)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    // 0=IDLE,1=FILL,2=WASH,3=RINSE,4=SPIN,5=DONE,-1=invalid
    function integer phase_code;
        input i, f, w, r, s, d;
        begin
            if (i && !f && !w && !r && !s && !d) phase_code = 0;
            else if (!i && f && !w && !r && !s && !d) phase_code = 1;
            else if (!i && !f && w && !r && !s && !d) phase_code = 2;
            else if (!i && !f && !w && r && !s && !d) phase_code = 3;
            else if (!i && !f && !w && !r && s && !d) phase_code = 4;
            else if (!i && !f && !w && !r && !s && d) phase_code = 5;
            else phase_code = -1;
        end
    endfunction

    task expect_valid;
        begin
            checks = checks + 1;
            if (phase_code(idle, filling, washing, rinsing, spinning, done_light) == -1) begin
                errors = errors + 1;
                $display("ERROR: invalid phase combo at cycle %0d", cycle_count);
            end
        end
    endtask

    task do_reset;
        begin
            rst_n = 0; start = 0; cancel = 0; lid_open = 0;
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
                if (phase_code(idle, filling, washing, rinsing, spinning, done_light) == expected)
                    found = 1;
                else if (watchdog > 500) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for phase=%0d", expected);
                    found = 1;
                end
            end
            elapsed = cycle_count - start_cycle;
        end
    endtask

    task check_elapsed(input integer elapsed, input integer expected, input [255:0] label);
        begin
            checks = checks + 1;
            if (elapsed !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s elapsed=%0d expected=%0d", label, elapsed, expected);
            end
        end
    endtask

    integer elapsed, k;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_washing_machine.vcd");
            $dumpvars(0, tb_washing_machine);
        end

        do_reset;
        checks = checks + 1;
        if (!idle) begin errors = errors + 1; $display("ERROR: not idle after reset"); end

        // --- full cycle, no pause, no cancel: exact per-phase dwell ---
        // (pulse_start's own posedge IS the IDLE->FILL transition edge,
        // so the dwell measurement starts immediately after it returns --
        // an extra wait_until_phase(1,...) call here would consume one
        // more edge waiting on a condition already true, silently
        // shifting every subsequent elapsed-cycle measurement by one)
        pulse_start;
        wait_until_phase(2, elapsed); check_elapsed(elapsed, FILL_TIME + 1, "FILL dwell");   // -> WASH

        // --- lid-open pause mid-WASH: total dwell grows by exactly the
        // paused duration, with the timer frozen (not merely slowed) ---
        begin : wash_with_pause
            integer wash_start_cycle;
            integer pause_len;
            wash_start_cycle = cycle_count;
            pause_len = 5;
            repeat (2) begin @(posedge clk); #1; expect_valid; end
            lid_open = 1'b1;
            repeat (pause_len) begin @(posedge clk); #1; expect_valid; end
            lid_open = 1'b0;
            wait_until_phase(3, elapsed); // -> RINSE
            elapsed = cycle_count - wash_start_cycle;
            check_elapsed(elapsed, WASH_TIME + 1 + pause_len, "WASH dwell with pause");
        end

        wait_until_phase(4, elapsed); check_elapsed(elapsed, RINSE_TIME + 1, "RINSE dwell"); // -> SPIN

        // --- cancel mid-SPIN: immediate return to IDLE ---
        repeat (2) begin @(posedge clk); #1; expect_valid; end
        pulse_cancel;
        checks = checks + 1;
        if (!idle) begin
            errors = errors + 1;
            $display("ERROR: expected IDLE immediately after cancel");
        end

        // --- starting again from IDLE begins a fresh cycle ---
        pulse_start;
        wait_until_phase(1, elapsed); // -> FILL again

        // run the rest of a full cycle through DONE
        wait_until_phase(2, elapsed); // -> WASH
        wait_until_phase(3, elapsed); // -> RINSE
        wait_until_phase(4, elapsed); // -> SPIN
        wait_until_phase(5, elapsed); // -> DONE
        checks = checks + 1;
        if (!done_light) begin errors = errors + 1; $display("ERROR: expected done_light"); end

        // pressing start again from DONE begins a new cycle
        pulse_start;
        wait_until_phase(1, elapsed); // -> FILL

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
