`timescale 1ns / 1ps

// tb_up_counter: runs a full count cycle (2^WIDTH values) plus a bit
// further to confirm the wrap back to 0, and checks hold when en=0.
module tb_up_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    wire [WIDTH-1:0] count;

    reg [WIDTH-1:0] ref_count;

    up_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .count(count));

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (count !== ref_count) begin
                errors = errors + 1;
                $display("ERROR: time=%0t en=%b expected count=%0d actual count=%0d", $time, en, ref_count, count);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_up_counter.vcd");
            $dumpvars(0, tb_up_counter);
        end

        rst_n = 0; en = 0; ref_count = 0;
        @(negedge clk); check;
        rst_n = 1;

        en = 1;
        for (i = 0; i < 20; i = i + 1) begin   // full cycle (16) + 4 more to confirm wrap
            ref_count = ref_count + 1;
            @(posedge clk); #1; check;
        end

        // hold
        en = 0;
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk); #1; check;
        end

        en = 1;
        ref_count = ref_count + 1;
        @(posedge clk); #1; check;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
