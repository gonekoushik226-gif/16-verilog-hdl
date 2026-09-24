`timescale 1ns / 1ps

module tb_decoder3to8;

    reg  [2:0] a;
    reg        en;
    wire [7:0] y;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg  [7:0] expected;

    decoder3to8 dut (.a(a), .en(en), .y(y));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_decoder3to8.vcd");
            $dumpvars(0, tb_decoder3to8);
        end

        $display("en a2 a1 a0 | y");
        for (i = 0; i < 16; i = i + 1) begin
            {en, a} = i[3:0];
            #1;
            expected = en ? (8'b0000_0001 << a) : 8'b0000_0000;
            checks = checks + 1;
            $display(" %b   %b  %b  %b  | %b", en, a[2], a[1], a[0], y);
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t en=%b a=%b expected=%b actual=%b",
                          $time, en, a, expected, y);
            end
            // Invariant: exactly one bit set when enabled, none when disabled
            if (en && ((y[0]+y[1]+y[2]+y[3]+y[4]+y[5]+y[6]+y[7]) != 1)) begin
                errors = errors + 1;
                $display("ERROR: t=%0t enabled output is not one-hot: y=%b", $time, y);
            end
            if (!en && y !== 8'b0) begin
                errors = errors + 1;
                $display("ERROR: t=%0t disabled output is not all-zero: y=%b", $time, y);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
