`timescale 1ns / 1ps

// tb_traffic_light: verifies the exact dwell time of each phase (in
// clock cycles) against the module's parameters, and that exactly one
// of red/yellow/green is asserted at every sampled cycle, across
// several full RED->GREEN->YELLOW loops.
//
// Timing note: because `state` resets to RED asynchronously (not via a
// clock edge), the first RED phase is one post-edge sample shorter than
// RED_TIME when counting only post-posedge samples -- the missing
// sample is checked separately, immediately after reset, before any
// clock edge. Every later phase (including every later RED phase) is
// entered via a normal posedge transition, so its post-edge sample
// count matches its parameter exactly.
module tb_traffic_light;

    localparam RED_TIME = 4, GREEN_TIME = 6, YELLOW_TIME = 3;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    wire red, yellow, green;

    traffic_light #(
        .RED_TIME(RED_TIME), .GREEN_TIME(GREEN_TIME), .YELLOW_TIME(YELLOW_TIME)
    ) dut (
        .clk(clk), .rst_n(rst_n), .red(red), .yellow(yellow), .green(green)
    );

    always #5 clk = ~clk;

    // which: 0=red, 1=green, 2=yellow
    task check_now(input integer which);
        reg ok;
        begin
            case (which)
                0: ok = red && !green && !yellow;
                1: ok = !red && green && !yellow;
                2: ok = !red && !green && yellow;
                default: ok = 1'b0;
            endcase
            checks = checks + 1;
            if (!ok) begin
                errors = errors + 1;
                $display("ERROR: expected phase=%0d red=%b green=%b yellow=%b",
                          which, red, green, yellow);
            end
        end
    endtask

    task check_phase(input integer duration, input integer which);
        integer k;
        begin
            for (k = 0; k < duration; k = k + 1) begin
                @(posedge clk); #1;
                check_now(which);
            end
        end
    endtask

    integer loop;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_traffic_light.vcd");
            $dumpvars(0, tb_traffic_light);
        end

        rst_n = 0;
        @(negedge clk); @(negedge clk);
        rst_n = 1;

        // reset asserts RED asynchronously, before any clock edge
        #1;
        check_now(0);

        // remainder of the first RED dwell (RED_TIME-1 more cycles)
        check_phase(RED_TIME - 1, 0);
        check_phase(GREEN_TIME, 1);
        check_phase(YELLOW_TIME, 2);

        // subsequent full cycles: every phase entered via a normal
        // posedge transition, so full-duration checks apply throughout
        for (loop = 0; loop < 5; loop = loop + 1) begin
            check_phase(RED_TIME, 0);
            check_phase(GREEN_TIME, 1);
            check_phase(YELLOW_TIME, 2);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
