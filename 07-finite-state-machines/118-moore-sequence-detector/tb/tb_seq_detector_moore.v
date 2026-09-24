`timescale 1ns / 1ps

// tb_seq_detector_moore: feeds directed patterns (including back-to-back
// overlapping matches) plus a pseudo-random stream, one bit per cycle.
// The reference model keeps every bit received since the last reset and
// checks it against a plain textual match of the last 4 bits -- fully
// independent of the DUT's state encoding.
module tb_seq_detector_moore;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg in_bit;
    wire detected;

    // history of bits seen since the last reset (large enough for every test)
    reg [0:511] hist;
    integer hist_len;

    seq_detector_moore dut (
        .clk(clk), .rst_n(rst_n), .in_bit(in_bit), .detected(detected)
    );

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; in_bit = 0; hist_len = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    // drive one bit, then check `detected` against the reference model
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
            if (detected !== expected) begin
                errors = errors + 1;
                $display("ERROR: bit#%0d in=%b detected=%b expected=%b",
                          hist_len, b, detected, expected);
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

    integer seed = 32'hC0FFEE;
    integer r, i;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_seq_detector_moore.vcd");
            $dumpvars(0, tb_seq_detector_moore);
        end

        // Case 1: exact pattern once ("0010110...") -> one match, mid-stream
        do_reset;
        feed_stream(128'b0010110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 16);

        // Case 2: back-to-back overlapping matches, "1011011011"
        // (three occurrences of "1011", each shifted 3 bits, overlapping)
        do_reset;
        feed_stream(128'b1011011011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 10);

        // Case 3: pattern straddling a reset (reset must clear partial match)
        do_reset;
        feed_bit(1'b1); feed_bit(1'b0); feed_bit(1'b1);  // "101" partial match
        do_reset;                   // reset clears the partial state
        feed_bit(1'b1);             // if reset didn't clear, "1101" would false-detect
        checks = checks; // (checked inside feed_bit)

        // Case 4: never matches (all zeros, all ones)
        do_reset;
        for (i = 0; i < 20; i = i + 1) feed_bit(1'b0);
        do_reset;
        for (i = 0; i < 20; i = i + 1) feed_bit(1'b1);

        // Case 5: pseudo-random long stream, several resets in between
        for (r = 0; r < 4; r = r + 1) begin
            do_reset;
            for (i = 0; i < 60; i = i + 1) begin
                seed = seed * 1103515245 + 12345;
                feed_bit(seed[30]);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
