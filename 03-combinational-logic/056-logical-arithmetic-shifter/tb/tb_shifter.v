`timescale 1ns / 1ps

// tb_shifter: all shift amounts (0..WIDTH-1) for directed data patterns,
// covering all three modes (left, logical right, arithmetic right), plus
// a random-data sweep across all shift amounts and modes.
module tb_shifter;

    localparam WIDTH = 8;
    localparam SW    = $clog2(WIDTH);

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer s, n, p;

    reg  [WIDTH-1:0] data;
    reg  [SW-1:0]    shamt;
    reg              left, arith;
    wire [WIDTH-1:0] result;

    shifter #(.WIDTH(WIDTH)) dut (.data(data), .shamt(shamt), .left(left), .arith(arith), .result(result));

    task check(input [WIDTH-1:0] d, input [SW-1:0] sh, input l, input a);
        reg [WIDTH-1:0] exp;
        begin
            data = d; shamt = sh; left = l; arith = a;
            #1;
            if (l)
                exp = d << sh;
            else if (a)
                exp = $signed(d) >>> sh;
            else
                exp = d >> sh;
            checks = checks + 1;
            if (result !== exp) begin
                errors = errors + 1;
                $display("ERROR: data=%b shamt=%0d left=%b arith=%b expected=%b actual=%b",
                          d, sh, l, a, exp, result);
            end
        end
    endtask

    function [WIDTH-1:0] pattern(input integer idx);
        begin
            case (idx)
                0: pattern = 8'b00000000;
                1: pattern = 8'b11111111;
                2: pattern = 8'b10000000;   // negative (MSB set) for arithmetic shift
                3: pattern = 8'b01111111;   // positive, MSB clear
                4: pattern = 8'b10101010;
                default: pattern = 8'b01010101;
            endcase
        end
    endfunction

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_shifter.vcd");
            $dumpvars(0, tb_shifter);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("directed patterns x all shift amounts x all 3 modes...");
        for (p = 0; p < 6; p = p + 1)
            for (s = 0; s < WIDTH; s = s + 1) begin
                check(pattern(p), s[SW-1:0], 1'b1, 1'b0);   // left
                check(pattern(p), s[SW-1:0], 1'b0, 1'b0);   // logical right
                check(pattern(p), s[SW-1:0], 1'b0, 1'b1);   // arithmetic right
            end
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("random data x all shift amounts x all 3 modes, seed=%0d...", seed);
        for (n = 0; n < 500; n = n + 1) begin
            data = $random(seed);
            for (s = 0; s < WIDTH; s = s + 1) begin
                check(data, s[SW-1:0], 1'b1, 1'b0);
                check(data, s[SW-1:0], 1'b0, 1'b0);
                check(data, s[SW-1:0], 1'b0, 1'b1);
            end
        end
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
