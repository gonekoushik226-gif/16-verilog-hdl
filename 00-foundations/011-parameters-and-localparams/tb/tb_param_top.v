`timescale 1ns / 1ps

module tb_param_top;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        en = 1'b0;
    wire [3:0] tenths, hex_count;
    wire [5:0] seconds;
    wire       minute_tick;

    integer errors = 0;
    integer checks = 0;
    integer cycle;
    integer m_tenths = 0, m_seconds = 0, m_hex = 0, ticks = 0;

    param_top dut (
        .clk(clk), .rst_n(rst_n), .en(en), .tenths(tenths),
        .seconds(seconds), .hex_count(hex_count), .minute_tick(minute_tick)
    );

    always #5 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_param_top.vcd");
            $dumpvars(0, tb_param_top);
        end

        // The widths are derived by $clog2 inside the counter
        $display("derived widths: tenths=%0d seconds=%0d hex=%0d bits",
                 dut.u_tenths.WIDTH, dut.u_seconds.WIDTH, dut.u_hex.WIDTH);
        checks = checks + 1;
        if (dut.u_tenths.WIDTH != 4 || dut.u_seconds.WIDTH != 6 || dut.u_hex.WIDTH != 4) begin
            errors = errors + 1;
            $display("ERROR: unexpected derived WIDTH");
        end

        #12 rst_n = 1'b1;
        // 1300 cycles: more than two full minutes, with en low 1 cycle in 7
        for (cycle = 0; cycle < 1300; cycle = cycle + 1) begin
            @(negedge clk);
            en = (cycle % 7 != 3);
            // model the outputs that the next rising edge will produce
            @(posedge clk);
            if (en) begin
                if (m_tenths == 9) begin
                    m_tenths = 0;
                    if (m_seconds == 59) begin m_seconds = 0; ticks = ticks + 1; end
                    else m_seconds = m_seconds + 1;
                end else m_tenths = m_tenths + 1;
                m_hex = (m_hex + 1) % 16;
            end
            #1;
            checks = checks + 1;
            if (tenths !== m_tenths || seconds !== m_seconds || hex_count !== m_hex) begin
                errors = errors + 1;
                $display("ERROR: cycle %0d tenths=%0d(%0d) seconds=%0d(%0d) hex=%0d(%0d)",
                         cycle, tenths, m_tenths, seconds, m_seconds, hex_count, m_hex);
            end
            if (cycle % 200 == 199)
                $display("after %4d cycles: tenths=%0d seconds=%0d hex=%0d", cycle + 1, tenths, seconds, hex_count);
        end
        $display("minute ticks modelled: %0d", ticks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #100000 $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
