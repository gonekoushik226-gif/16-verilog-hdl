`timescale 1ns / 1ps

// tb_popcount: exhaustive WIDTH=8 sweep and random WIDTH=32 sweep, checked
// against a flat bit-summation reference model independent of the RTL's
// recursive adder-tree structure.
module tb_popcount;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer i, n, b;

    reg  [7:0] data8;
    wire [3:0] count8;

    reg  [31:0] data32;
    wire [5:0]  count32;

    popcount #(.WIDTH(8))  dut8  (.data(data8),  .count(count8));
    popcount #(.WIDTH(32)) dut32 (.data(data32), .count(count32));

    task check8(input [7:0] d);
        integer exp;
        begin
            data8 = d;
            #1;
            exp = 0;
            for (b = 0; b < 8; b = b + 1)
                exp = exp + d[b];
            checks = checks + 1;
            if (count8 !== exp[3:0]) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=8 data=%b expected count=%0d actual=%0d", d, exp, count8);
            end
        end
    endtask

    task check32(input [31:0] d);
        integer exp;
        begin
            data32 = d;
            #1;
            exp = 0;
            for (b = 0; b < 32; b = b + 1)
                exp = exp + d[b];
            checks = checks + 1;
            if (count32 !== exp[5:0]) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=32 data=%h expected count=%0d actual=%0d", d, exp, count32);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_popcount.vcd");
            $dumpvars(0, tb_popcount);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("WIDTH=8 exhaustive sweep (256 values)...");
        for (i = 0; i < 256; i = i + 1)
            check8(i[7:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("WIDTH=32 directed corners (all-zero, all-ones, single bits)...");
        check32(32'h00000000);
        check32(32'hFFFFFFFF);
        for (i = 0; i < 32; i = i + 1)
            check32(32'b1 << i);

        $display("WIDTH=32 random sweep, seed=%0d (2000 vectors)...", seed);
        for (n = 0; n < 2000; n = n + 1)
            check32({$random(seed), $random(seed)});
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
