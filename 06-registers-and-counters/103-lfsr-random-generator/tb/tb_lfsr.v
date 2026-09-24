`timescale 1ns / 1ps

// tb_lfsr: for each of the two LFSR styles, runs 255 cycles from the
// reset seed and checks (a) it never re-visits a state before all 255
// have been seen (a "visited" bitmap catches both premature repeats and
// getting stuck), (b) it never lands on the all-zero locked state, and
// (c) it returns exactly to the seed on cycle 255, confirming the full
// maximal-length period.
module tb_lfsr;

    localparam WIDTH = 8;
    localparam PERIOD = 255;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n;
    wire [WIDTH-1:0] qf, qg;

    reg visited_f [0:255];
    reg visited_g [0:255];

    lfsr_fibonacci #(.WIDTH(WIDTH)) dut_f (.clk(clk), .rst_n(rst_n), .q(qf));
    lfsr_galois     #(.WIDTH(WIDTH)) dut_g (.clk(clk), .rst_n(rst_n), .q(qg));

    always #5 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_lfsr.vcd");
            $dumpvars(0, tb_lfsr);
        end

        for (i = 0; i < 256; i = i + 1) begin
            visited_f[i] = 1'b0;
            visited_g[i] = 1'b0;
        end

        rst_n = 0; @(negedge clk); rst_n = 1;

        checks = checks + 1;
        if (qf !== 8'h01 || qg !== 8'h01) begin
            errors = errors + 1;
            $display("ERROR: reset seed mismatch qf=%h qg=%h", qf, qg);
        end
        visited_f[qf] = 1'b1;
        visited_g[qg] = 1'b1;

        for (i = 1; i <= PERIOD; i = i + 1) begin
            @(posedge clk); #1;

            checks = checks + 1;
            if (qf == 8'h00) begin
                errors = errors + 1;
                $display("ERROR: Fibonacci LFSR reached the locked all-zero state at cycle %0d", i);
            end else if (i < PERIOD && visited_f[qf]) begin
                errors = errors + 1;
                $display("ERROR: Fibonacci LFSR repeated state %h early, at cycle %0d", qf, i);
            end
            visited_f[qf] = 1'b1;

            checks = checks + 1;
            if (qg == 8'h00) begin
                errors = errors + 1;
                $display("ERROR: Galois LFSR reached the locked all-zero state at cycle %0d", i);
            end else if (i < PERIOD && visited_g[qg]) begin
                errors = errors + 1;
                $display("ERROR: Galois LFSR repeated state %h early, at cycle %0d", qg, i);
            end
            visited_g[qg] = 1'b1;
        end

        // after exactly PERIOD=255 cycles, both must be back at the seed
        checks = checks + 1;
        if (qf !== 8'h01) begin
            errors = errors + 1;
            $display("ERROR: Fibonacci LFSR did not return to seed after %0d cycles, qf=%h", PERIOD, qf);
        end
        checks = checks + 1;
        if (qg !== 8'h01) begin
            errors = errors + 1;
            $display("ERROR: Galois LFSR did not return to seed after %0d cycles, qg=%h", PERIOD, qg);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
