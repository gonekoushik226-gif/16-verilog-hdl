`timescale 1ns / 1ps

// tb_ff_conversions: checks each converted flip-flop against the
// characteristic equation of the flip-flop type it is emulating.
// jk_from_d is checked against the JK table exhaustively from both
// starting states (same methodology as program 090); t_from_d against
// the toggle/hold table; d_from_jk against a plain behavioral D
// flip-flop reference, confirming the D-to-JK-and-back-to-D round trip
// is exactly identity (see d_from_jk.v's header comment for the
// algebraic proof this exercises).
module tb_ff_conversions;

    integer errors = 0;
    integer checks = 0;
    integer ji, ki, i;

    reg clk = 0;
    always #5 clk = ~clk;

    // ---- jk_from_d ----
    reg  rst_n1, j, k;
    wire q1;
    jk_from_d dut1 (.clk(clk), .rst_n(rst_n1), .j(j), .k(k), .q(q1));

    // ---- t_from_d ----
    reg  rst_n2, t;
    wire q2;
    t_from_d dut2 (.clk(clk), .rst_n(rst_n2), .t(t), .q(q2));

    // ---- d_from_jk vs plain d_ff reference ----
    reg  rst_n3, d;
    wire q3;
    reg  ref_q;
    d_from_jk dut3 (.clk(clk), .rst_n(rst_n3), .d(d), .q(q3));
    always @(posedge clk or negedge rst_n3) begin
        if (!rst_n3) ref_q <= 1'b0;
        else         ref_q <= d;
    end

    task check1(input expected);
        begin
            checks = checks + 1;
            if (q1 !== expected) begin
                errors = errors + 1;
                $display("ERROR(jk_from_d): time=%0t j=%b k=%b expected q=%b actual q=%b", $time, j, k, expected, q1);
            end
        end
    endtask

    task check2(input expected);
        begin
            checks = checks + 1;
            if (q2 !== expected) begin
                errors = errors + 1;
                $display("ERROR(t_from_d): time=%0t t=%b expected q=%b actual q=%b", $time, t, expected, q2);
            end
        end
    endtask

    task check3;
        begin
            checks = checks + 1;
            if (q3 !== ref_q) begin
                errors = errors + 1;
                $display("ERROR(d_from_jk): time=%0t d=%b expected q=%b actual q=%b", $time, d, ref_q, q3);
            end
        end
    endtask

    task set_q1(input val);
        begin
            rst_n1 = 0; @(negedge clk); rst_n1 = 1;
            if (val) begin j = 1; k = 0; @(posedge clk); #1; end
            j = 0; k = 0; #1;
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_ff_conversions.vcd");
            $dumpvars(0, tb_ff_conversions);
        end

        // ---- jk_from_d: exhaustive JK table from both starting states ----
        for (ji = 0; ji < 2; ji = ji + 1)
            for (ki = 0; ki < 2; ki = ki + 1) begin
                set_q1(0); check1(1'b0);
                j = ji[0]; k = ki[0]; #1; @(posedge clk); #1;
                case ({ji[0], ki[0]})
                    2'b00: check1(1'b0);
                    2'b01: check1(1'b0);
                    2'b10: check1(1'b1);
                    2'b11: check1(1'b1);
                endcase

                set_q1(1); check1(1'b1);
                j = ji[0]; k = ki[0]; #1; @(posedge clk); #1;
                case ({ji[0], ki[0]})
                    2'b00: check1(1'b1);
                    2'b01: check1(1'b0);
                    2'b10: check1(1'b1);
                    2'b11: check1(1'b0);
                endcase
            end

        // ---- t_from_d: hold and toggle ----
        rst_n2 = 0; t = 0; @(negedge clk); check2(1'b0);
        rst_n2 = 1;
        for (i = 0; i < 3; i = i + 1) begin @(posedge clk); #1; check2(1'b0); end
        t = 1;
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk); #1; check2(i[0] == 1'b0);
        end
        // t=0 now: q2 last toggled at i=7 (odd), so it should read 0;
        // one more edge with t=0 must leave it unchanged at 0
        t = 0; @(posedge clk); #1; check2(1'b0);

        // ---- d_from_jk vs behavioral d_ff reference ----
        rst_n3 = 0; d = 1; @(negedge clk); check3;
        rst_n3 = 1;
        for (i = 0; i < 12; i = i + 1) begin
            d = $random; @(posedge clk); #1; check3;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
