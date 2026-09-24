`timescale 1ns / 1ps

// tb_edge_detector: drives sig_in through a pattern covering every kind
// of transition (rising, falling, held-high, held-low, back-to-back
// changes), checking all three pulses appear on the correct cycle using
// a two-stage shadow reference model (mirroring the DUT's own two
// register stages) maintained independently in the testbench.
module tb_edge_detector;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, sig_in;
    wire rising, falling, any_edge;

    reg [0:15] pattern = 16'b0110_0111_1000_0101;
    reg ref_sync, ref_prev;

    edge_detector dut (.clk(clk), .rst_n(rst_n), .sig_in(sig_in),
                        .rising(rising), .falling(falling), .any_edge(any_edge));

    always #5 clk = ~clk;

    task check;
        reg exp_rising, exp_falling, exp_any;
        begin
            // mirror the DUT's own two-stage shadow update
            ref_prev = ref_sync;
            ref_sync = sig_in;

            checks = checks + 1;
            exp_rising  = ref_sync & ~ref_prev;
            exp_falling = ~ref_sync & ref_prev;
            exp_any     = ref_sync ^ ref_prev;
            if (rising !== exp_rising || falling !== exp_falling || any_edge !== exp_any) begin
                errors = errors + 1;
                $display("ERROR: time=%0t sig_in=%b sync=%b prev=%b expected rising=%b falling=%b any=%b actual rising=%b falling=%b any=%b",
                          $time, sig_in, ref_sync, ref_prev, exp_rising, exp_falling, exp_any, rising, falling, any_edge);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_edge_detector.vcd");
            $dumpvars(0, tb_edge_detector);
        end

        rst_n = 0; sig_in = 0; ref_sync = 0; ref_prev = 0;
        @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 16; i = i + 1) begin
            sig_in = pattern[i];
            @(posedge clk); #1;
            check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
