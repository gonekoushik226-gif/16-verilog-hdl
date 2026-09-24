`timescale 1ns / 1ps

// tb_clock_divider_even: for several even DIV values, measures the
// actual period and duty cycle of clk_out directly from simulation time
// (waiting on real edges of clk_out, not just sampling the internal
// counter), checking period == DIV*Tclk and duty == exactly 50%.
module tb_clock_divider_even;

    localparam TCLK = 10;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    always #(TCLK/2) clk = ~clk;

    task run_case;
        input integer div;
        integer t_rise1, t_fall, t_rise2;
        begin
            rst_n = 0; @(negedge clk); rst_n = 1;

            @(posedge uut_out);
            t_rise1 = $time;
            @(negedge uut_out);
            t_fall = $time;
            @(posedge uut_out);
            t_rise2 = $time;

            checks = checks + 1;
            if ((t_rise2 - t_rise1) !== div*TCLK) begin
                errors = errors + 1;
                $display("ERROR: DIV=%0d expected period=%0d actual=%0d", div, div*TCLK, t_rise2-t_rise1);
            end
            checks = checks + 1;
            if ((t_fall - t_rise1) !== (div*TCLK)/2) begin
                errors = errors + 1;
                $display("ERROR: DIV=%0d expected high-time=%0d actual=%0d", div, (div*TCLK)/2, t_fall-t_rise1);
            end
        end
    endtask

    // instance selection is done per-case via generate-free re-wiring:
    // simplest robust approach is one DUT per DIV value, checked in turn
    wire out4, out6, out8;
    reg  sel;
    wire uut_out;

    clock_divider_even #(.DIV(4)) dut4 (.clk(clk), .rst_n(rst_n), .clk_out(out4));
    clock_divider_even #(.DIV(6)) dut6 (.clk(clk), .rst_n(rst_n), .clk_out(out6));
    clock_divider_even #(.DIV(8)) dut8 (.clk(clk), .rst_n(rst_n), .clk_out(out8));

    reg [1:0] which;
    assign uut_out = (which == 0) ? out4 : (which == 1) ? out6 : out8;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_clock_divider_even.vcd");
            $dumpvars(0, tb_clock_divider_even);
        end

        which = 0; run_case(4);
        which = 1; run_case(6);
        which = 2; run_case(8);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
