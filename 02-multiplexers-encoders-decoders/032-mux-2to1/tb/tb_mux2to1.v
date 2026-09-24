`timescale 1ns / 1ps

module tb_mux2to1;

    integer errors = 0;
    integer checks = 0;
    integer i, n;

    // ---- 1-bit instance: exhaustive over sel/d0/d1 ------------------------
    reg  sel1;
    reg  d0_1, d1_1;
    wire y1;
    reg  expected1;

    mux2to1 #(.WIDTH(1)) dut1 (.sel(sel1), .d0(d0_1), .d1(d1_1), .y(y1));

    // ---- 8-bit instance: random data, both sel values ----------------------
    reg          sel8;
    reg  [7:0]   d0_8, d1_8;
    wire [7:0]   y8;
    reg  [7:0]   expected8;

    mux2to1 #(.WIDTH(8)) dut8 (.sel(sel8), .d0(d0_8), .d1(d1_8), .y(y8));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mux2to1.vcd");
            $dumpvars(0, tb_mux2to1);
        end

        // Exhaustive 1-bit: sel, d0, d1 each 0/1 -> 8 combinations
        $display("WIDTH=1 exhaustive:");
        $display("sel d0 d1 | y");
        for (i = 0; i < 8; i = i + 1) begin
            {sel1, d0_1, d1_1} = i[2:0];
            #1;
            expected1 = sel1 ? d1_1 : d0_1;
            checks = checks + 1;
            $display(" %b   %b  %b  | %b", sel1, d0_1, d1_1, y1);
            if (y1 !== expected1) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d0=%b d1=%b expected=%b actual=%b",
                          $time, sel1, d0_1, d1_1, expected1, y1);
            end
        end

        // Random 8-bit: 200 vectors per sel value
        $display("WIDTH=8 random (200 vectors x 2 sel values):");
        for (n = 0; n < 200; n = n + 1) begin
            d0_8 = $random;
            d1_8 = $random;
            sel8 = 1'b0;
            #1;
            expected8 = sel8 ? d1_8 : d0_8;
            checks = checks + 1;
            if (y8 !== expected8) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d0=%h d1=%h expected=%h actual=%h",
                          $time, sel8, d0_8, d1_8, expected8, y8);
            end

            sel8 = 1'b1;
            #1;
            expected8 = sel8 ? d1_8 : d0_8;
            checks = checks + 1;
            if (y8 !== expected8) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d0=%h d1=%h expected=%h actual=%h",
                          $time, sel8, d0_8, d1_8, expected8, y8);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
