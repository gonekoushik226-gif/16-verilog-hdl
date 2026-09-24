`timescale 1ns / 1ps

// tb_prescaler: checks tick spacing for several different runtime
// reload values (including 0, the divide-by-1 edge case), each run
// fresh from reset, plus a hold check with en=0.
module tb_prescaler;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i, gap, r;
    integer last_tick_cycle, cycle_num;

    reg clk = 0;
    reg rst_n, en;
    reg [WIDTH-1:0] reload_val;
    wire tick;

    prescaler #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en),
                                     .reload_val(reload_val), .tick(tick));

    always #5 clk = ~clk;

    task run_case(input [WIDTH-1:0] reload, input integer num_cycles);
        begin
            rst_n = 0; en = 0; reload_val = reload;
            @(negedge clk); rst_n = 1; en = 1;
            cycle_num = 0; last_tick_cycle = -1;
            for (i = 0; i < num_cycles; i = i + 1) begin
                @(posedge clk); #1;
                cycle_num = cycle_num + 1;
                checks = checks + 1;
                if (tick) begin
                    if (last_tick_cycle != -1) begin
                        gap = cycle_num - last_tick_cycle;
                        if (gap != reload + 1) begin
                            errors = errors + 1;
                            $display("ERROR: reload=%0d cycle=%0d spacing=%0d expected %0d",
                                      reload, cycle_num, gap, reload+1);
                        end
                    end
                    last_tick_cycle = cycle_num;
                end
            end
            if (last_tick_cycle == -1) begin
                errors = errors + 1;
                $display("ERROR: reload=%0d no tick observed", reload);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_prescaler.vcd");
            $dumpvars(0, tb_prescaler);
        end

        run_case(8'd0, 10);    // divide by 1: ticks every cycle
        run_case(8'd3, 30);    // divide by 4
        run_case(8'd9, 60);    // divide by 10
        run_case(8'd24, 130);  // divide by 25

        // hold: disable and confirm no further ticks
        en = 0;
        for (r = 0; r < 5; r = r + 1) begin
            @(posedge clk); #1;
            checks = checks + 1;
            if (tick) begin
                errors = errors + 1;
                $display("ERROR: tick asserted while en=0");
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
