`timescale 1ns / 1ps

module tb_func_demo;

    reg  [7:0] data;
    wire [3:0] ones;
    wire       parity;
    wire [7:0] reversed;
    wire [2:0] lowest_one;
    wire       any_one;

    integer errors = 0;
    integer checks = 0;
    integer n;

    func_demo dut (
        .data(data), .ones(ones), .parity(parity), .reversed(reversed),
        .lowest_one(lowest_one), .any_one(any_one)
    );

    // Recursive reference model: requires an AUTOMATIC function so that each
    // call gets its own copy of the argument and local storage.
    function automatic integer ref_popcount(input integer v);
        begin
            if (v == 0) ref_popcount = 0;
            else        ref_popcount = (v & 1) + ref_popcount(v >> 1);
        end
    endfunction

    function automatic integer ref_lowest(input integer v);
        begin
            if (v == 0)           ref_lowest = 0;
            else if (v & 1)       ref_lowest = 0;
            else                  ref_lowest = 1 + ref_lowest(v >> 1);
        end
    endfunction

    // Task: drive one stimulus, wait, compare every output.
    task apply_and_check(input [7:0] value);
        integer k;
        reg [7:0] e_rev;
        begin
            data = value;
            #1;
            for (k = 0; k < 8; k = k + 1) e_rev[7 - k] = value[k];
            checks = checks + 1;
            if (ones !== ref_popcount(value) || parity !== (ref_popcount(value) % 2) ||
                reversed !== e_rev || any_one !== (value != 0) ||
                lowest_one !== ref_lowest(value)) begin
                errors = errors + 1;
                $display("ERROR: data=%b ones=%0d parity=%b reversed=%b lowest=%0d any=%b",
                         data, ones, parity, reversed, lowest_one, any_one);
            end
        end
    endtask

    // Task calling another task, then printing a table row
    task show(input [7:0] value);
        begin
            apply_and_check(value);
            $display("%b |  %0d     %b    %b     %0d     %b", data, ones, parity, reversed, lowest_one, any_one);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_func_demo.vcd");
            $dumpvars(0, tb_func_demo);
        end
        $display("  data   | ones par reversed lowest any");
        show(8'b0000_0000);
        show(8'b0000_0001);
        show(8'b1000_0000);
        show(8'b1011_0100);
        show(8'b1111_1111);
        for (n = 0; n < 256; n = n + 1)
            apply_and_check(n[7:0]);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
