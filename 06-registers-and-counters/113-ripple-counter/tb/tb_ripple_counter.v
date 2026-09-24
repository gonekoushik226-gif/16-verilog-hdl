`timescale 1ns / 1ps

// tb_ripple_counter: samples q well after each clock edge (letting the
// ripple fully settle through all stages within the same simulation
// time step) and checks the settled value against a standard binary
// count sequence over more than one full cycle. Zero-delay simulation
// cannot show the *transient* glitching a real ripple counter produces
// while each stage's delay is still propagating (see README.md SS13);
// this testbench verifies the functionally correct settled sequence,
// which is what the structural ripple topology is built to (eventually)
// produce.
module tb_ripple_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n;
    wire [WIDTH-1:0] q;

    reg [WIDTH-1:0] ref_count;

    ripple_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .q(q));

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (q !== ref_count) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected q=%0d actual q=%0d", $time, ref_count, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_ripple_counter.vcd");
            $dumpvars(0, tb_ripple_counter);
        end

        rst_n = 0; ref_count = 0;
        @(negedge clk); check;
        rst_n = 1;

        for (i = 0; i < 20; i = i + 1) begin   // full cycle (16) + 4 more to confirm wrap
            ref_count = ref_count + 1;
            @(posedge clk); #2; check;   // extra settling margin for the ripple chain
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
