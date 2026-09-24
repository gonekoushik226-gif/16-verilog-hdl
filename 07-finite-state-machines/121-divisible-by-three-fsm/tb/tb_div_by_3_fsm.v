`timescale 1ns / 1ps

// tb_div_by_3_fsm: for each test number, resets the FSM, then feeds the
// number serially MSB-first, checking `remainder` and `div_by_3` after
// EVERY bit (not just the last) against an independently accumulated
// value and Verilog's `%` operator -- exhaustive over all 8-bit values,
// plus randomized wider (20-bit) numbers.
module tb_div_by_3_fsm;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg bit_in;
    wire [1:0] remainder;
    wire div_by_3;

    div_by_3_fsm dut (
        .clk(clk), .rst_n(rst_n), .bit_in(bit_in),
        .remainder(remainder), .div_by_3(div_by_3)
    );

    always #5 clk = ~clk;

    task feed_number(input [31:0] val, input integer width);
        integer i;
        reg [31:0] acc;
        reg [1:0] expected_rem;
        begin
            rst_n = 0; bit_in = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
            acc = 0;
            for (i = width - 1; i >= 0; i = i - 1) begin
                bit_in = val[i];
                @(posedge clk); #1;
                acc = acc * 2 + val[i];
                expected_rem = acc % 3;

                checks = checks + 1;
                if (remainder !== expected_rem) begin
                    errors = errors + 1;
                    $display("ERROR: val=%0d width=%0d bit#%0d remainder=%0d expected=%0d",
                              val, width, width - i, remainder, expected_rem);
                end
                checks = checks + 1;
                if (div_by_3 !== (expected_rem == 2'd0)) begin
                    errors = errors + 1;
                    $display("ERROR: val=%0d width=%0d bit#%0d div_by_3=%b expected=%b",
                              val, width, width - i, div_by_3, (expected_rem == 2'd0));
                end
            end
        end
    endtask

    integer v;
    integer r;
    integer seed = 32'h1234ABCD;
    reg [31:0] rv;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_div_by_3_fsm.vcd");
            $dumpvars(0, tb_div_by_3_fsm);
        end

        // exhaustive: every 8-bit value
        for (v = 0; v < 256; v = v + 1)
            feed_number(v[7:0], 8);

        // randomized: 300 wider (20-bit) values, fixed seed
        for (r = 0; r < 300; r = r + 1) begin
            rv = $random(seed);
            feed_number(rv[19:0], 20);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
