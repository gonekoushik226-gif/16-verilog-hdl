`timescale 1ns / 1ps

// tb_gray_counter: runs a full 2^WIDTH cycle, checking two properties
// every cycle -- the one-bit-change property (gray_count differs from
// its immediately previous value in exactly one bit) and that the
// value matches the standard binary-to-Gray conversion of a software
// reference binary counter.
module tb_gray_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    wire [WIDTH-1:0] gray_count;

    reg [WIDTH-1:0] ref_bin;
    reg [WIDTH-1:0] prev_gray;

    function integer popcount;
        input [WIDTH-1:0] v;
        integer k;
        begin
            popcount = 0;
            for (k = 0; k < WIDTH; k = k + 1) popcount = popcount + v[k];
        end
    endfunction

    gray_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .gray_count(gray_count));

    always #5 clk = ~clk;

    task check;
        reg [WIDTH-1:0] exp_gray;
        begin
            checks = checks + 1;
            exp_gray = ref_bin ^ (ref_bin >> 1);
            if (gray_count !== exp_gray) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected gray=%b actual=%b", $time, exp_gray, gray_count);
            end else if (popcount(gray_count ^ prev_gray) != 1) begin
                errors = errors + 1;
                $display("ERROR: time=%0t one-bit-change violated: prev=%b now=%b", $time, prev_gray, gray_count);
            end
            prev_gray = gray_count;
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_gray_counter.vcd");
            $dumpvars(0, tb_gray_counter);
        end

        rst_n = 0; en = 0; ref_bin = 0;
        @(negedge clk);
        prev_gray = gray_count;   // 0 at reset
        checks = checks + 1;
        if (gray_count !== {WIDTH{1'b0}}) begin
            errors = errors + 1;
            $display("ERROR: reset value expected 0, actual %b", gray_count);
        end

        rst_n = 1; en = 1;
        for (i = 0; i < 20; i = i + 1) begin   // full 16-value cycle + 4 more to confirm wrap
            ref_bin = ref_bin + 1;
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
