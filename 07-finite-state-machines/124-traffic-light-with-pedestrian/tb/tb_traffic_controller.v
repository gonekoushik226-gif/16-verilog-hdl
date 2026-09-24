`timescale 1ns / 1ps

// tb_traffic_controller: exercises the INTEGRATED top-level design (FSM
// + timer + pedestrian_request instantiated inside it), not the helper
// modules in isolation. Drives `req_btn` at various phases (GREEN,
// YELLOW, RED, and even WALK itself) and checks the resulting phase
// sequence, that requests are correctly latched/serviced/cleared, and
// that outputs are always a mutually-exclusive valid combination.
module tb_traffic_controller;

    localparam WIDTH = 8, RED_TIME = 6, GREEN_TIME = 6, YELLOW_TIME = 3, WALK_TIME = 5;

    integer errors = 0;
    integer checks = 0;
    integer cycle_count = 0;

    reg clk = 0;
    reg rst_n, req_btn;
    wire red, yellow, green, walk;

    traffic_controller #(
        .WIDTH(WIDTH), .RED_TIME(RED_TIME), .GREEN_TIME(GREEN_TIME),
        .YELLOW_TIME(YELLOW_TIME), .WALK_TIME(WALK_TIME)
    ) dut (
        .clk(clk), .rst_n(rst_n), .req_btn(req_btn),
        .red(red), .yellow(yellow), .green(green), .walk(walk)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    // 0=GREEN, 1=YELLOW, 2=RED, 3=WALK, -1=invalid combination
    function integer phase_code(input g, input y, input r, input w);
        begin
            if (w && r && !g && !y)      phase_code = 3;
            else if (r && !w && !g && !y) phase_code = 2;
            else if (y && !g && !r && !w) phase_code = 1;
            else if (g && !y && !r && !w) phase_code = 0;
            else                           phase_code = -1;
        end
    endfunction

    task expect_valid_combo;
        begin
            checks = checks + 1;
            if (phase_code(green, yellow, red, walk) == -1) begin
                errors = errors + 1;
                $display("ERROR: invalid output combo g=%b y=%b r=%b w=%b at cycle %0d",
                          green, yellow, red, walk, cycle_count);
            end
        end
    endtask

    task wait_phase_change(input integer prev_code, output integer elapsed, output integer new_code);
        integer start_cycle;
        integer watchdog;
        reg done_wait;
        begin
            start_cycle = cycle_count;
            watchdog = 0;
            new_code = prev_code;
            done_wait = 0;
            while (!done_wait) begin
                @(posedge clk); #1;
                expect_valid_combo;
                new_code = phase_code(green, yellow, red, walk);
                watchdog = watchdog + 1;
                if (new_code != prev_code) begin
                    done_wait = 1;
                end else if (watchdog > 200) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for phase change from %0d", prev_code);
                    done_wait = 1;
                end
            end
            elapsed = cycle_count - start_cycle;
        end
    endtask

    task press_button;
        begin
            @(negedge clk); req_btn = 1'b1;
            @(negedge clk); req_btn = 1'b0;
        end
    endtask

    task check_elapsed(input integer elapsed, input integer expected, input [511:0] label);
        begin
            checks = checks + 1;
            if (elapsed !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s duration=%0d expected=%0d", label, elapsed, expected);
            end
        end
    endtask

    task check_phase(input integer got, input integer expected, input [511:0] label);
        begin
            checks = checks + 1;
            if (got !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s got phase=%0d expected=%0d", label, got, expected);
            end
        end
    endtask

    integer elapsed, newc, cur;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_traffic_controller.vcd");
            $dumpvars(0, tb_traffic_controller);
        end

        rst_n = 0; req_btn = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;

        @(posedge clk); #1;
        cur = phase_code(green, yellow, red, walk);
        check_phase(cur, 0, "post-reset first phase");

        // --- Scenario A: no request -> RED goes straight back to GREEN ---
        wait_phase_change(0, elapsed, newc);
        check_elapsed(elapsed, GREEN_TIME + 1, "GREEN (no request)");
        check_phase(newc, 1, "after GREEN (no request)");

        wait_phase_change(1, elapsed, newc);
        check_elapsed(elapsed, YELLOW_TIME + 1, "YELLOW (no request)");
        check_phase(newc, 2, "after YELLOW (no request)");

        wait_phase_change(2, elapsed, newc);
        check_elapsed(elapsed, RED_TIME + 1, "RED (no request)");
        check_phase(newc, 0, "after RED (no request) -> GREEN, no WALK");

        // --- Scenario B: press during GREEN -> WALK inserted after RED ---
        press_button;
        wait_phase_change(0, elapsed, newc);
        check_phase(newc, 1, "after GREEN (pressed during GREEN)");
        wait_phase_change(1, elapsed, newc);
        check_phase(newc, 2, "after YELLOW (pressed during GREEN)");
        wait_phase_change(2, elapsed, newc);
        check_elapsed(elapsed, RED_TIME + 1, "RED (request pending)");
        check_phase(newc, 3, "after RED -> WALK (pressed during GREEN)");
        wait_phase_change(3, elapsed, newc);
        check_elapsed(elapsed, WALK_TIME + 1, "WALK");
        check_phase(newc, 0, "after WALK -> GREEN");

        // --- Scenario C: request cleared -> next RED skips WALK again ---
        wait_phase_change(0, elapsed, newc);
        wait_phase_change(1, elapsed, newc);
        wait_phase_change(2, elapsed, newc);
        check_phase(newc, 0, "after RED, request cleared -> GREEN, no WALK");

        // --- Scenario D: press during YELLOW ---
        wait_phase_change(0, elapsed, newc);
        check_phase(newc, 1, "entered YELLOW for scenario D");
        press_button;
        wait_phase_change(1, elapsed, newc);
        check_phase(newc, 2, "after YELLOW (pressed during YELLOW)");
        wait_phase_change(2, elapsed, newc);
        check_phase(newc, 3, "after RED -> WALK (pressed during YELLOW)");
        wait_phase_change(3, elapsed, newc);
        check_phase(newc, 0, "after WALK -> GREEN (scenario D)");

        // --- Scenario E: press early during RED itself ---
        wait_phase_change(0, elapsed, newc);
        wait_phase_change(1, elapsed, newc);
        check_phase(newc, 2, "entered RED for scenario E");
        press_button;
        wait_phase_change(2, elapsed, newc);
        check_phase(newc, 3, "after RED -> WALK (pressed during RED)");
        wait_phase_change(3, elapsed, newc);
        check_phase(newc, 0, "after WALK -> GREEN (scenario E)");

        // --- Scenario F: a press WHILE already walking is redundant (the
        // pedestrian is already being serviced) and must NOT queue a
        // second WALK on the following cycle -- `req_clear` fires at the
        // end of every WALK phase and takes priority over a same-phase
        // `req_btn`, by design (see README Sec.13). ---
        wait_phase_change(0, elapsed, newc);
        wait_phase_change(1, elapsed, newc);
        press_button;                        // ensure this cycle also walks
        wait_phase_change(2, elapsed, newc);
        check_phase(newc, 3, "after RED -> WALK (setup for scenario F)");
        press_button;                        // redundant press WHILE walking
        wait_phase_change(3, elapsed, newc);
        check_phase(newc, 0, "after WALK -> GREEN (scenario F setup)");
        wait_phase_change(0, elapsed, newc);
        wait_phase_change(1, elapsed, newc);
        wait_phase_change(2, elapsed, newc);
        check_phase(newc, 0, "after RED -> GREEN, redundant WALK-time press absorbed, no extra WALK");

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
