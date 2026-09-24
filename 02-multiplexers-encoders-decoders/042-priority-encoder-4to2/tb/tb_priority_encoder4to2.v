`timescale 1ns / 1ps

module tb_priority_encoder4to2;

    reg  [3:0] d;
    wire [1:0] y;
    wire       valid;

    integer errors = 0;
    integer checks = 0;
    integer i, b;
    reg  [1:0] expected_y;
    reg        expected_valid;

    priority_encoder4to2 dut (.d(d), .y(y), .valid(valid));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_priority_encoder4to2.vcd");
            $dumpvars(0, tb_priority_encoder4to2);
        end

        $display("d3 d2 d1 d0 | y1 y0 valid");
        for (i = 0; i < 16; i = i + 1) begin
            d = i[3:0];
            #1;

            expected_valid = |d;
            expected_y     = 2'b00;
            for (b = 0; b < 4; b = b + 1)
                if (d[b]) expected_y = b[1:0];   // highest index wins (loop runs low to high)

            checks = checks + 1;
            $display(" %b  %b  %b  %b  |  %b  %b   %b", d[3], d[2], d[1], d[0], y[1], y[0], valid);
            if (valid !== expected_valid || (expected_valid && y !== expected_y)) begin
                errors = errors + 1;
                $display("ERROR: t=%0t d=%b expected valid=%b y=%b actual valid=%b y=%b",
                          $time, d, expected_valid, expected_y, valid, y);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
