`timescale 1ns / 1ps

// tb_fsm_encoding: drives the same serial bit stream into all three state
// encodings of the "1011" Moore detector (binary, gray, one-hot) in
// lock-step and checks, every single cycle, that all three `detected`
// outputs agree with each other AND with an independent reference model
// -- proving the encoding choice is purely an implementation detail with
// no behavioral effect.
module tb_fsm_encoding;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg in_bit;
    wire det_bin, det_gray, det_onehot;

    reg [0:511] hist;
    integer hist_len;

    fsm_binary  u_bin  (.clk(clk), .rst_n(rst_n), .in_bit(in_bit), .detected(det_bin));
    fsm_gray    u_gray (.clk(clk), .rst_n(rst_n), .in_bit(in_bit), .detected(det_gray));
    fsm_onehot  u_oh   (.clk(clk), .rst_n(rst_n), .in_bit(in_bit), .detected(det_onehot));

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; in_bit = 0; hist_len = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task feed_bit(input b);
        reg expected;
        begin
            in_bit = b;
            @(posedge clk); #1;
            hist[hist_len] = b;
            hist_len = hist_len + 1;
            expected = 1'b0;
            if (hist_len >= 4 &&
                hist[hist_len-4] == 1'b1 && hist[hist_len-3] == 1'b0 &&
                hist[hist_len-2] == 1'b1 && hist[hist_len-1] == 1'b1)
                expected = 1'b1;

            checks = checks + 1;
            if (det_bin !== expected) begin
                errors = errors + 1;
                $display("ERROR: bit#%0d binary detected=%b expected=%b", hist_len, det_bin, expected);
            end
            checks = checks + 1;
            if (det_gray !== expected) begin
                errors = errors + 1;
                $display("ERROR: bit#%0d gray detected=%b expected=%b", hist_len, det_gray, expected);
            end
            checks = checks + 1;
            if (det_onehot !== expected) begin
                errors = errors + 1;
                $display("ERROR: bit#%0d onehot detected=%b expected=%b", hist_len, det_onehot, expected);
            end
            // cross-check: all three encodings must agree with each other
            checks = checks + 1;
            if (!((det_bin === det_gray) && (det_gray === det_onehot))) begin
                errors = errors + 1;
                $display("ERROR: bit#%0d encodings disagree: bin=%b gray=%b onehot=%b",
                          hist_len, det_bin, det_gray, det_onehot);
            end
        end
    endtask

    task feed_stream(input [0:127] bits, input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                feed_bit(bits[i]);
        end
    endtask

    integer seed = 32'hFACE0FF;
    integer r, i;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_fsm_encoding.vcd");
            $dumpvars(0, tb_fsm_encoding);
        end

        do_reset;
        feed_stream(128'b0010110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 16);

        do_reset;
        feed_stream(128'b1011011011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 10);

        do_reset;
        for (i = 0; i < 20; i = i + 1) feed_bit(1'b0);
        do_reset;
        for (i = 0; i < 20; i = i + 1) feed_bit(1'b1);

        for (r = 0; r < 4; r = r + 1) begin
            do_reset;
            for (i = 0; i < 60; i = i + 1) begin
                seed = seed * 1103515245 + 12345;
                feed_bit(seed[29]);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
