`timescale 1ns / 1ps

module tb_mux4to1;

    integer errors = 0;
    integer checks = 0;
    integer i, n;

    // ---- 1-bit instance: exhaustive over sel and all four data bits -------
    reg  [1:0] sel1;
    reg        d0_1, d1_1, d2_1, d3_1;
    wire       y1;
    reg        expected1;

    mux4to1 #(.WIDTH(1)) dut1 (
        .sel(sel1), .d0(d0_1), .d1(d1_1), .d2(d2_1), .d3(d3_1), .y(y1)
    );

    // ---- 8-bit instance: random data, all four sel values ------------------
    reg  [1:0] sel8;
    reg  [7:0] d0_8, d1_8, d2_8, d3_8;
    wire [7:0] y8;
    reg  [7:0] expected8;

    mux4to1 #(.WIDTH(8)) dut8 (
        .sel(sel8), .d0(d0_8), .d1(d1_8), .d2(d2_8), .d3(d3_8), .y(y8)
    );

    function [0:0] pick1;
        input [1:0] s;
        input d0, d1, d2, d3;
        begin
            case (s)
                2'b00: pick1 = d0;
                2'b01: pick1 = d1;
                2'b10: pick1 = d2;
                default: pick1 = d3;
            endcase
        end
    endfunction

    function [7:0] pick8;
        input [1:0] s;
        input [7:0] d0, d1, d2, d3;
        begin
            case (s)
                2'b00: pick8 = d0;
                2'b01: pick8 = d1;
                2'b10: pick8 = d2;
                default: pick8 = d3;
            endcase
        end
    endfunction

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mux4to1.vcd");
            $dumpvars(0, tb_mux4to1);
        end

        // Exhaustive 1-bit: {sel, d0, d1, d2, d3} -> 64 combinations
        $display("WIDTH=1 exhaustive (64 combinations):");
        for (i = 0; i < 64; i = i + 1) begin
            {sel1, d0_1, d1_1, d2_1, d3_1} = i[5:0];
            #1;
            expected1 = pick1(sel1, d0_1, d1_1, d2_1, d3_1);
            checks = checks + 1;
            if (y1 !== expected1) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%b d0=%b d1=%b d2=%b d3=%b expected=%b actual=%b",
                          $time, sel1, d0_1, d1_1, d2_1, d3_1, expected1, y1);
            end
        end

        // Random 8-bit: 100 vectors, all four sel values each
        $display("WIDTH=8 random (100 vectors x 4 sel values):");
        for (n = 0; n < 100; n = n + 1) begin
            d0_8 = $random; d1_8 = $random; d2_8 = $random; d3_8 = $random;
            for (i = 0; i < 4; i = i + 1) begin
                sel8 = i[1:0];
                #1;
                expected8 = pick8(sel8, d0_8, d1_8, d2_8, d3_8);
                checks = checks + 1;
                if (y8 !== expected8) begin
                    errors = errors + 1;
                    $display("ERROR: t=%0t sel=%b d0=%h d1=%h d2=%h d3=%h expected=%h actual=%h",
                              $time, sel8, d0_8, d1_8, d2_8, d3_8, expected8, y8);
                end
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
