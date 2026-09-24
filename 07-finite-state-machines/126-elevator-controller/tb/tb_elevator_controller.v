`timescale 1ns / 1ps

// tb_elevator_controller: exercises the INTEGRATED design (FSM +
// request_register + door_timer). Rather than hand-computing exact
// cycle counts for a multi-floor SCAN dispatch (fragile and hard to
// read), this testbench checks the SEQUENCE of floors the elevator
// stops at against the expected SCAN order for each multi-request
// scenario, plus the door's open dwell time and a same-floor
// immediate-open case.
module tb_elevator_controller;

    localparam FLOORS = 4, MOVE_TIME = 3, OPEN_TIME = 4;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg [FLOORS-1:0] request_in;
    wire [1:0] current_floor;
    wire moving_up, moving_down, door_open;
    wire [FLOORS-1:0] pending_out;

    elevator_controller #(
        .FLOORS(FLOORS), .MOVE_TIME(MOVE_TIME), .OPEN_TIME(OPEN_TIME)
    ) dut (
        .clk(clk), .rst_n(rst_n), .request_in(request_in),
        .current_floor(current_floor), .moving_up(moving_up),
        .moving_down(moving_down), .door_open(door_open),
        .pending_out(pending_out)
    );

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; request_in = {FLOORS{1'b0}};
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task press(input integer floor);
        begin
            @(negedge clk);
            request_in = ({{(FLOORS-1){1'b0}}, 1'b1} << floor);
            @(posedge clk); #1;
            request_in = {FLOORS{1'b0}};
        end
    endtask

    task press_multi(input [FLOORS-1:0] mask);
        begin
            @(negedge clk);
            request_in = mask;
            @(posedge clk); #1;
            request_in = {FLOORS{1'b0}};
        end
    endtask

    task wait_door_open(output integer floor_seen);
        integer watchdog;
        reg found;
        begin
            watchdog = 0; found = 0; floor_seen = -1;
            while (!found) begin
                @(posedge clk); #1;
                watchdog = watchdog + 1;
                if (door_open) begin
                    found = 1;
                    floor_seen = current_floor;
                end else if (watchdog > 500) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for door_open");
                    found = 1;
                end
            end
        end
    endtask

    task wait_door_close(output integer dwell);
        integer watchdog;
        reg done_wait;
        begin
            watchdog = 0; done_wait = 0; dwell = 0;
            while (!done_wait) begin
                @(posedge clk); #1;
                watchdog = watchdog + 1;
                dwell = dwell + 1;
                if (!door_open) done_wait = 1;
                else if (watchdog > 500) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout waiting for door_close");
                    done_wait = 1;
                end
            end
        end
    endtask

    task check_visit(input integer got_floor, input integer expected_floor, input [255:0] label);
        begin
            checks = checks + 1;
            if (got_floor !== expected_floor) begin
                errors = errors + 1;
                $display("ERROR: %0s stopped at floor=%0d expected=%0d",
                          label, got_floor, expected_floor);
            end
        end
    endtask

    integer got, dwell;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_elevator_controller.vcd");
            $dumpvars(0, tb_elevator_controller);
        end

        // --- Scenario A: single request from idle at floor 0 ---
        do_reset;
        press(2);
        wait_door_open(got); check_visit(got, 2, "Scenario A single request");
        wait_door_close(dwell);
        checks = checks + 1;
        if (dwell !== OPEN_TIME + 1) begin
            errors = errors + 1;
            $display("ERROR: Scenario A door dwell=%0d expected=%0d", dwell, OPEN_TIME + 1);
        end

        // --- Scenario B: two simultaneous requests while moving up,
        // SCAN must visit them in floor order (1, then 3) ---
        do_reset;
        press_multi(({{(FLOORS-1){1'b0}}, 1'b1} << 1) | ({{(FLOORS-1){1'b0}}, 1'b1} << 3));
        wait_door_open(got); check_visit(got, 1, "Scenario B first stop");
        wait_door_close(dwell);
        wait_door_open(got); check_visit(got, 3, "Scenario B second stop");
        wait_door_close(dwell);

        // --- Scenario C: a request for an intermediate floor arrives
        // WHILE the elevator is already moving toward a farther one ---
        do_reset;
        press(3);       // starts moving up toward floor 3
        press(1);       // added mid-transit, well before arrival at floor 1
        wait_door_open(got); check_visit(got, 1, "Scenario C intermediate stop");
        wait_door_close(dwell);
        wait_door_open(got); check_visit(got, 3, "Scenario C final stop");
        wait_door_close(dwell);

        // --- Scenario D: from the top floor, two requests below ->
        // SCAN reverses direction and visits them in descending order ---
        press(3);       // still at floor 3 (idle); re-open at current floor
        wait_door_open(got); check_visit(got, 3, "Scenario D re-open at current floor");
        wait_door_close(dwell);
        press_multi(({{(FLOORS-1){1'b0}}, 1'b1} << 2) | ({{(FLOORS-1){1'b0}}, 1'b1} << 0));
        wait_door_open(got); check_visit(got, 2, "Scenario D first stop (descending)");
        wait_door_close(dwell);
        wait_door_open(got); check_visit(got, 0, "Scenario D second stop (descending)");
        wait_door_close(dwell);

        // --- Scenario E: request for the current floor while idle ->
        // immediate door open, no movement ---
        press(0);
        wait_door_open(got); check_visit(got, 0, "Scenario E immediate open at current floor");
        wait_door_close(dwell);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
