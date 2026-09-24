`timescale 1ns / 1ps

module tb_decoder2to4;

    reg  [1:0] a;
    reg        en;
    wire [3:0] y;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg  [3:0] expected;

    decoder2to4 dut (.a(a), .en(en), .y(y));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_decoder2to4.vcd");
            $dumpvars(0, tb_decoder2to4);
        end

        $display("en a1 a0 | y3 y2 y1 y0");
        for (i = 0; i < 8; i = i + 1) begin
            {en, a} = i[2:0];
            #1;
            expected = en ? (4'b0001 << a) : 4'b0000;
            checks = checks + 1;
            $display(" %b   %b  %b  |  %b   %b   %b   %b", en, a[1], a[0], y[3], y[2], y[1], y[0]);
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t en=%b a=%b expected=%b actual=%b",
                          $time, en, a, expected, y);
            end
            // Invariant: exactly one bit set when enabled
            if (en && ((y[0] + y[1] + y[2] + y[3]) != 1)) begin
                errors = errors + 1;
                $display("ERROR: t=%0t enabled output is not one-hot: y=%b", $time, y);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
