`timescale 1ns / 1ps

// tb_clock_divider_odd: for several odd N values, samples clk_out at a
// settled point after every clk edge (half-clk-period resolution)
// rather than waiting on raw `posedge clk_out` events -- clk_out is
// combinationally derived from both a registered counter and the live
// `clk` signal, so a raw event-triggered wait can catch a momentary
// delta-cycle glitch at the exact instant clk and the counter update
// together, before the simulator finishes settling that time step (an
// earlier version of this testbench did exactly that and measured
// impossible sub-cycle "periods" as a result -- see README.md SS10).
// Sampling a fixed moment after each edge sidesteps that race entirely.
module tb_clock_divider_odd;

    localparam TCLK = 10;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    always #(TCLK/2) clk = ~clk;

    wire out3, out5, out7;
    reg [1:0] which;
    wire uut_out;

    clock_divider_odd #(.N(3)) dut3 (.clk(clk), .rst_n(rst_n), .clk_out(out3));
    clock_divider_odd #(.N(5)) dut5 (.clk(clk), .rst_n(rst_n), .clk_out(out5));
    clock_divider_odd #(.N(7)) dut7 (.clk(clk), .rst_n(rst_n), .clk_out(out7));

    assign uut_out = (which == 0) ? out3 : (which == 1) ? out5 : out7;

    task run_case;
        input integer n;
        integer half, k, edge_count;
        integer t_edges [0:31];
        reg prev_val, cur_val;
        integer period, high_time;
        begin
            rst_n = 0; @(negedge clk); rst_n = 1;
            // let one full period pass so any reset-phase irregularity
            // (the very first cycle can be short -- see README.md SS13)
            // is gone before measuring
            repeat (2*n) @(posedge clk);
            @(negedge clk);

            prev_val = uut_out;
            edge_count = 0;
            for (k = 0; k < 6*n; k = k + 1) begin   // 3 full periods, half-clk resolution
                // alternate waiting on a real clk edge (not a blind time
                // delay) so every sample lands a settled #1 after an
                // actual posedge/negedge, regardless of TCLK's value
                if (k[0] == 1'b0) @(posedge clk); else @(negedge clk);
                #1;
                cur_val = uut_out;
                if (cur_val !== prev_val) begin
                    t_edges[edge_count] = $time;
                    edge_count = edge_count + 1;
                end
                prev_val = cur_val;
            end

            // expect exactly 6 edges (3 rises + 3 falls) in 3 periods
            checks = checks + 1;
            if (edge_count < 4) begin
                errors = errors + 1;
                $display("ERROR: N=%0d too few edges observed (%0d)", n, edge_count);
            end else begin
                period    = t_edges[2] - t_edges[0];
                high_time = t_edges[1] - t_edges[0];
                checks = checks + 1;
                if (period !== n*TCLK) begin
                    errors = errors + 1;
                    $display("ERROR: N=%0d expected period=%0d actual=%0d", n, n*TCLK, period);
                end
                checks = checks + 1;
                if (high_time !== (n*TCLK)/2) begin
                    errors = errors + 1;
                    $display("ERROR: N=%0d expected high-time=%0d actual=%0d", n, (n*TCLK)/2, high_time);
                end
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_clock_divider_odd.vcd");
            $dumpvars(0, tb_clock_divider_odd);
        end

        which = 0; run_case(3);
        which = 1; run_case(5);
        which = 2; run_case(7);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
