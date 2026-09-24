`timescale 1ns / 1ps

module tb_demux1to4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    // ---- WIDTH=1: fully exhaustive over sel and d ---------------------------
    reg  [1:0] sel1;
    reg        d1;
    wire       y0_1, y1_1, y2_1, y3_1;
    reg        e0, e1, e2, e3;

    demux1to4 #(.WIDTH(1)) dut1 (
        .sel(sel1), .d(d1), .y0(y0_1), .y1(y1_1), .y2(y2_1), .y3(y3_1)
    );

    // ---- WIDTH=4: exhaustive over sel and d (4 x 16 = 64 combinations) -----
    reg  [1:0] sel4;
    reg  [3:0] d4;
    wire [3:0] y0_4, y1_4, y2_4, y3_4;
    reg  [3:0] e0_4, e1_4, e2_4, e3_4;

    demux1to4 #(.WIDTH(4)) dut4 (
        .sel(sel4), .d(d4), .y0(y0_4), .y1(y1_4), .y2(y2_4), .y3(y3_4)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_demux1to4.vcd");
            $dumpvars(0, tb_demux1to4);
        end

        // Exhaustive WIDTH=1: {sel, d} -> 8 combinations
        $display("WIDTH=1 exhaustive:");
        $display("sel d | y0 y1 y2 y3");
        for (i = 0; i < 8; i = i + 1) begin
            {sel1, d1} = i[2:0];
            #1;
            e0 = (sel1 == 2'b00) ? d1 : 1'b0;
            e1 = (sel1 == 2'b01) ? d1 : 1'b0;
            e2 = (sel1 == 2'b10) ? d1 : 1'b0;
            e3 = (sel1 == 2'b11) ? d1 : 1'b0;
            checks = checks + 1;
            $display(" %b   %b  |  %b  %b  %b  %b", sel1, d1, y0_1, y1_1, y2_1, y3_1);
            if ({y0_1, y1_1, y2_1, y3_1} !== {e0, e1, e2, e3}) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d=%b expected y0..y3=%b%b%b%b actual=%b%b%b%b",
                          $time, sel1, d1, e0, e1, e2, e3, y0_1, y1_1, y2_1, y3_1);
            end
            // Exactly one active output whenever d=1, none active when d=0
            if (d1 && ((y0_1 + y1_1 + y2_1 + y3_1) != 1)) begin
                errors = errors + 1;
                $display("ERROR: t=%0t more than one output active with d=1", $time);
            end
        end

        // Exhaustive WIDTH=4: sel (4) x d (16) = 64 combinations
        $display("WIDTH=4 exhaustive (64 combinations):");
        for (i = 0; i < 64; i = i + 1) begin
            {sel4, d4} = i[5:0];
            #1;
            e0_4 = (sel4 == 2'b00) ? d4 : 4'b0;
            e1_4 = (sel4 == 2'b01) ? d4 : 4'b0;
            e2_4 = (sel4 == 2'b10) ? d4 : 4'b0;
            e3_4 = (sel4 == 2'b11) ? d4 : 4'b0;
            checks = checks + 1;
            if ({y0_4, y1_4, y2_4, y3_4} !== {e0_4, e1_4, e2_4, e3_4}) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d=%h expected y0..y3=%h %h %h %h actual=%h %h %h %h",
                          $time, sel4, d4, e0_4, e1_4, e2_4, e3_4, y0_4, y1_4, y2_4, y3_4);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
