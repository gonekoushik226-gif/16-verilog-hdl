`timescale 1ns / 1ps

// tb_tick_generator: checks tick pulse spacing (exactly PERIOD cycles
// apart) and width (exactly 1 cycle) over several periods, plus a hold
// check with en=0.
module tb_tick_generator;

    localparam PERIOD = 5;

    integer errors = 0;
    integer checks = 0;
    integer i, gap;

    reg clk = 0;
    reg rst_n, en;
    wire tick;

    integer last_tick_cycle;
    integer cycle_num;

    tick_generator #(.PERIOD(PERIOD)) dut (.clk(clk), .rst_n(rst_n), .en(en), .tick(tick));

    always #5 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_tick_generator.vcd");
            $dumpvars(0, tb_tick_generator);
        end

        rst_n = 0; en = 0; cycle_num = 0; last_tick_cycle = -1;
        @(negedge clk);
        checks = checks + 1;
        if (tick !== 1'b0) begin errors = errors + 1; $display("ERROR: tick asserted during reset"); end
        rst_n = 1; en = 1;

        for (i = 0; i < 4*PERIOD; i = i + 1) begin
            @(posedge clk); #1;
            cycle_num = cycle_num + 1;
            checks = checks + 1;
            if (tick) begin
                if (last_tick_cycle != -1) begin
                    gap = cycle_num - last_tick_cycle;
                    if (gap != PERIOD) begin
                        errors = errors + 1;
                        $display("ERROR: cycle=%0d tick spacing=%0d expected %0d", cycle_num, gap, PERIOD);
                    end
                end
                last_tick_cycle = cycle_num;
            end
        end
        // must have seen at least 3 ticks in 4*PERIOD cycles
        if (last_tick_cycle == -1) begin
            errors = errors + 1;
            $display("ERROR: no tick observed at all");
        end

        // hold: disable and confirm no further ticks
        en = 0;
        for (i = 0; i < PERIOD; i = i + 1) begin
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
