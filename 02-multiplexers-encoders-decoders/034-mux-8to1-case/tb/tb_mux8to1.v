`timescale 1ns / 1ps

module tb_mux8to1;

    localparam WIDTH = 8;

    reg  [2:0]       sel;
    reg  [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7;
    wire [WIDTH-1:0] y;

    integer errors = 0;
    integer checks = 0;
    integer n, s;
    reg  [WIDTH-1:0] data [0:7];
    reg  [WIDTH-1:0] expected;

    mux8to1 #(.WIDTH(WIDTH)) dut (
        .sel(sel), .d0(d0), .d1(d1), .d2(d2), .d3(d3),
        .d4(d4), .d5(d5), .d6(d6), .d7(d7), .y(y)
    );

    task apply_data;
        begin
            d0 = data[0]; d1 = data[1]; d2 = data[2]; d3 = data[3];
            d4 = data[4]; d5 = data[5]; d6 = data[6]; d7 = data[7];
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mux8to1.vcd");
            $dumpvars(0, tb_mux8to1);
        end

        // Directed: distinct, easily-recognisable values on every input
        for (s = 0; s < 8; s = s + 1) data[s] = s + 8'hA0;
        apply_data;
        for (s = 0; s < 8; s = s + 1) begin
            sel = s[2:0];
            #1;
            expected = data[s];
            checks = checks + 1;
            $display("sel=%0d -> y=%h (expected %h)", s, y, expected);
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t sel=%0d expected=%h actual=%h", $time, s, expected, y);
            end
        end

        // Random data, exhaustive select: 300 random data sets x 8 sel values
        for (n = 0; n < 300; n = n + 1) begin
            for (s = 0; s < 8; s = s + 1) data[s] = $random;
            apply_data;
            for (s = 0; s < 8; s = s + 1) begin
                sel = s[2:0];
                #1;
                expected = data[s];
                checks = checks + 1;
                if (y !== expected) begin
                    errors = errors + 1;
                    $display("ERROR: t=%0t sel=%0d expected=%h actual=%h", $time, s, expected, y);
                end
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
