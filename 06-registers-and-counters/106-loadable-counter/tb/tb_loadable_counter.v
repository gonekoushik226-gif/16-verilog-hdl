`timescale 1ns / 1ps

// tb_loadable_counter: checks load, counting, tc asserting exactly at
// the maximum value, wraparound, and load taking priority over enable.
module tb_loadable_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n, load, en;
    reg [WIDTH-1:0] load_val;
    wire [WIDTH-1:0] count;
    wire tc;

    loadable_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .load(load), .en(en),
                                            .load_val(load_val), .count(count), .tc(tc));

    always #5 clk = ~clk;

    task check(input [WIDTH-1:0] exp_count, input exp_tc);
        begin
            checks = checks + 1;
            if (count !== exp_count || tc !== exp_tc) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected count=%0d tc=%b actual count=%0d tc=%b",
                          $time, exp_count, exp_tc, count, tc);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_loadable_counter.vcd");
            $dumpvars(0, tb_loadable_counter);
        end

        rst_n = 0; load = 0; en = 0; load_val = 0;
        @(negedge clk); check(0, 1'b0);
        rst_n = 1;

        // load a value near the top
        load = 1; load_val = 4'd13; @(posedge clk); #1; check(4'd13, 1'b0);
        load = 0; en = 1;
        @(posedge clk); #1; check(4'd14, 1'b0);
        @(posedge clk); #1; check(4'd15, 1'b1);   // terminal count
        @(posedge clk); #1; check(4'd0, 1'b0);    // wraps, tc drops

        // load takes priority over enable when both asserted
        load = 1; en = 1; load_val = 4'd5;
        @(posedge clk); #1; check(4'd5, 1'b0);

        load = 0;
        @(posedge clk); #1; check(4'd6, 1'b0);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
