`timescale 1ns / 1ps

// tb_gray_converters: exhaustive round-trip check (bin -> gray -> bin) for
// WIDTH=8, an independent reference-model check of gray2bin using a
// different (shift-doubling) algorithm than the RTL's ripple chain, and a
// check of Gray code's defining one-bit-change property across every
// consecutive pair of values.
module tb_gray_converters;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  [WIDTH-1:0] bin_in;
    wire [WIDTH-1:0] gray_out;
    reg  [WIDTH-1:0] gray_in;
    wire [WIDTH-1:0] bin_out;

    bin2gray #(.WIDTH(WIDTH)) dut_b2g (.bin(bin_in),  .gray(gray_out));
    gray2bin #(.WIDTH(WIDTH)) dut_g2b (.gray(gray_in), .bin(bin_out));

    // Independent reference model for binary -> Gray -> binary, using the
    // standard shift-doubling inverse rather than the RTL's ripple chain.
    function [WIDTH-1:0] gray2bin_model(input [WIDTH-1:0] g);
        integer k;
        reg [WIDTH-1:0] b;
        begin
            b = g;
            for (k = 1; k < WIDTH; k = k * 2)
                b = b ^ (b >> k);
            gray2bin_model = b;
        end
    endfunction

    task check_roundtrip(input [WIDTH-1:0] b);
        reg [WIDTH-1:0] expected_gray, model_bin;
        begin
            bin_in = b;
            #1;
            expected_gray = b ^ (b >> 1);
            checks = checks + 1;
            if (gray_out !== expected_gray) begin
                errors = errors + 1;
                $display("ERROR: bin2gray bin=%b expected gray=%b actual=%b", b, expected_gray, gray_out);
            end

            gray_in = gray_out;
            #1;
            model_bin = gray2bin_model(gray_out);
            checks = checks + 1;
            if (bin_out !== b || bin_out !== model_bin) begin
                errors = errors + 1;
                $display("ERROR: gray2bin gray=%b expected bin=%b (model=%b) actual=%b",
                          gray_out, b, model_bin, bin_out);
            end
        end
    endtask

    task check_one_bit_change(input [WIDTH-1:0] n);
        reg [WIDTH-1:0] gray_n, gray_n1, diff;
        integer popcount;
        integer k;
        begin
            bin_in = n;      #1; gray_n  = gray_out;
            bin_in = n + 1;  #1; gray_n1 = gray_out;
            diff = gray_n ^ gray_n1;
            popcount = 0;
            for (k = 0; k < WIDTH; k = k + 1)
                popcount = popcount + diff[k];
            checks = checks + 1;
            if (popcount != 1) begin
                errors = errors + 1;
                $display("ERROR: one-bit-change property violated: gray(%0d)=%b gray(%0d)=%b differ in %0d bits",
                          n, gray_n, n + 1, gray_n1, popcount);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_gray_converters.vcd");
            $dumpvars(0, tb_gray_converters);
        end

        $display("exhaustive bin->gray->bin round trip (%0d values)...", 256);
        for (i = 0; i < 256; i = i + 1)
            check_roundtrip(i[WIDTH-1:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("one-bit-change property across all consecutive pairs (%0d pairs)...", 255);
        for (i = 0; i < 255; i = i + 1)
            check_one_bit_change(i[WIDTH-1:0]);
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
