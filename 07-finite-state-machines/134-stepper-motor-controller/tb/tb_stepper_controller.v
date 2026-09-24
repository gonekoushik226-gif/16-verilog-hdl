`timescale 1ns / 1ps

// tb_stepper_controller: resets before each mode/direction scenario (so
// the coil sequence always starts deterministically at index 0), then
// collects every DISTINCT coil value seen over a run (with the cycle
// index of each change) and checks both the resulting sequence against
// the expected full-step/half-step, forward/reverse pattern, and that
// each pattern is held for exactly SPEED_DIV cycles before advancing.
module tb_stepper_controller;

    localparam SPEED_DIV = 4;

    integer errors = 0;
    integer checks = 0;
    integer cycle_count = 0;

    reg clk = 0;
    reg rst_n, enable, dir, half_step;
    wire [3:0] coil;

    stepper_controller #(.SPEED_DIV(SPEED_DIV)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable), .dir(dir),
        .half_step(half_step), .coil(coil)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    reg [3:0] observed [0:63];
    integer   change_cycle [0:63];
    integer   observed_len;

    task do_reset;
        begin
            rst_n = 0; enable = 0; dir = 1; half_step = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task collect(input integer n_cycles);
        integer k;
        reg [3:0] prev;
        begin
            observed_len = 0;
            prev = coil;
            observed[observed_len]     = prev;
            change_cycle[observed_len] = cycle_count;
            observed_len = observed_len + 1;
            for (k = 0; k < n_cycles; k = k + 1) begin
                @(posedge clk); #1;
                if (coil !== prev) begin
                    observed[observed_len]     = coil;
                    change_cycle[observed_len] = cycle_count;
                    observed_len = observed_len + 1;
                    prev = coil;
                end
            end
        end
    endtask

    task check_sequence(input [4*16-1:0] expected_flat, input integer expected_len, input [255:0] label);
        integer k;
        reg [3:0] exp_val;
        begin
            checks = checks + 1;
            if (observed_len < expected_len) begin
                errors = errors + 1;
                $display("ERROR: %0s observed only %0d transitions, expected >= %0d",
                          label, observed_len, expected_len);
            end else begin
                for (k = 0; k < expected_len; k = k + 1) begin
                    exp_val = expected_flat[4*(expected_len-1-k) +: 4];
                    checks = checks + 1;
                    if (observed[k] !== exp_val) begin
                        errors = errors + 1;
                        $display("ERROR: %0s step#%0d coil=%b expected=%b",
                                  label, k, observed[k], exp_val);
                    end
                    if (k > 0) begin
                        checks = checks + 1;
                        if (change_cycle[k] - change_cycle[k-1] !== SPEED_DIV) begin
                            errors = errors + 1;
                            $display("ERROR: %0s step#%0d spacing=%0d expected=%0d",
                                      label, k, change_cycle[k] - change_cycle[k-1], SPEED_DIV);
                        end
                    end
                end
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_stepper_controller.vcd");
            $dumpvars(0, tb_stepper_controller);
        end

        // --- full-step forward: 1000 -> 0100 -> 0010 -> 0001 -> 1000 ---
        do_reset; enable = 1; dir = 1; half_step = 0;
        collect(5 * SPEED_DIV + 2);
        check_sequence({16'h0, 4'b1000, 4'b0100, 4'b0010, 4'b0001, 4'b1000}, 5, "full-step forward");

        // --- full-step reverse: 1000 -> 0001 -> 0010 -> 0100 -> 1000 ---
        do_reset; enable = 1; dir = 0; half_step = 0;
        collect(5 * SPEED_DIV + 2);
        check_sequence({16'h0, 4'b1000, 4'b0001, 4'b0010, 4'b0100, 4'b1000}, 5, "full-step reverse");

        // --- half-step forward: all 8 table positions, in order ---
        do_reset; enable = 1; dir = 1; half_step = 1;
        collect(9 * SPEED_DIV + 2);
        check_sequence({4'b1000, 4'b1100, 4'b0100, 4'b0110, 4'b0010, 4'b0011, 4'b0001, 4'b1001, 4'b1000},
                        9, "half-step forward");

        // --- half-step reverse: all 8 table positions, reverse order ---
        do_reset; enable = 1; dir = 0; half_step = 1;
        collect(9 * SPEED_DIV + 2);
        check_sequence({4'b1000, 4'b1001, 4'b0001, 4'b0011, 4'b0010, 4'b0110, 4'b0100, 4'b1100, 4'b1000},
                        9, "half-step reverse");

        // --- enable=0 holds the current pattern (no stepping) ---
        do_reset; enable = 1; dir = 1; half_step = 0;
        repeat (2 * SPEED_DIV) begin @(posedge clk); #1; end   // step forward a bit
        enable = 0;
        begin : hold_check
            reg [3:0] held;
            integer k;
            held = coil;
            for (k = 0; k < 3 * SPEED_DIV; k = k + 1) begin
                @(posedge clk); #1;
                checks = checks + 1;
                if (coil !== held) begin
                    errors = errors + 1;
                    $display("ERROR: coil changed while disabled: %b -> %b", held, coil);
                end
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
