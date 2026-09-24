`timescale 1ns / 1ps

// tb_barrel_rotator: all shift amounts against directed and random data, in
// both directions, checked against a shift-and-OR reference model
// (rotate_left(d,n) = (d<<n)|(d>>(WIDTH-n))) independent of the RTL's
// double-width windowing technique.
module tb_barrel_rotator;

    localparam WIDTH = 8;
    localparam SW    = $clog2(WIDTH);

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer s, n;

    reg  [WIDTH-1:0] data;
    reg  [SW-1:0]    shamt;
    reg              left;
    wire [WIDTH-1:0] result;

    barrel_rotator #(.WIDTH(WIDTH)) dut (.data(data), .shamt(shamt), .left(left), .result(result));

    task check_roundtrip;
        reg [WIDTH-1:0] original, rotated;
        reg [SW-1:0]    k;
        begin
            original = $random(seed);
            k = $random(seed);
            data = original; shamt = k; left = 1'b1;
            #1; rotated = result;
            data = rotated; shamt = k; left = 1'b0;
            #1;
            checks = checks + 1;
            if (result !== original) begin
                errors = errors + 1;
                $display("ERROR: round-trip failed: original=%b k=%0d rotated=%b restored=%b",
                          original, k, rotated, result);
            end
        end
    endtask

    task check(input [WIDTH-1:0] d, input [SW-1:0] sh, input l);
        reg [WIDTH-1:0] exp;
        begin
            data = d; shamt = sh; left = l;
            #1;
            if (l)
                exp = (d << sh) | (d >> (WIDTH - sh));
            else
                exp = (d >> sh) | (d << (WIDTH - sh));
            checks = checks + 1;
            if (result !== exp) begin
                errors = errors + 1;
                $display("ERROR: data=%b shamt=%0d left=%b expected=%b actual=%b",
                          d, sh, l, exp, result);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_barrel_rotator.vcd");
            $dumpvars(0, tb_barrel_rotator);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("directed all-zero/all-one/walking-one patterns x all shift amounts x both directions...");
        for (s = 0; s < WIDTH; s = s + 1) begin
            check(8'h00, s[SW-1:0], 1'b1); check(8'h00, s[SW-1:0], 1'b0);
            check(8'hFF, s[SW-1:0], 1'b1); check(8'hFF, s[SW-1:0], 1'b0);
        end
        for (n = 0; n < WIDTH; n = n + 1)
            for (s = 0; s < WIDTH; s = s + 1) begin
                check(8'h01 << n, s[SW-1:0], 1'b1);
                check(8'h01 << n, s[SW-1:0], 1'b0);
            end
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("random data x all shift amounts x both directions, seed=%0d...", seed);
        for (n = 0; n < 500; n = n + 1) begin
            data = $random(seed);
            for (s = 0; s < WIDTH; s = s + 1) begin
                check(data, s[SW-1:0], 1'b1);
                check(data, s[SW-1:0], 1'b0);
            end
        end
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        // property check: rotating all the way around by WIDTH-1 then 1
        // more step (using two rotations) must return to the original value
        $display("round-trip property: rotate left by k then right by k...");
        for (n = 0; n < 500; n = n + 1)
            check_roundtrip;
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
