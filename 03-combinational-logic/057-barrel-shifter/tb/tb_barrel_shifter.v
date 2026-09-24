`timescale 1ns / 1ps

// tb_barrel_shifter: every shift amount against directed and random data,
// in both directions, checked against Verilog's native << and >> operators
// as the reference ("operator model").
module tb_barrel_shifter;

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

    barrel_shifter #(.WIDTH(WIDTH)) dut (.data(data), .shamt(shamt), .left(left), .result(result));

    task check(input [WIDTH-1:0] d, input [SW-1:0] sh, input l);
        reg [WIDTH-1:0] exp;
        begin
            data = d; shamt = sh; left = l;
            #1;
            exp = l ? (d << sh) : (d >> sh);
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
            $dumpfile("build/tb_barrel_shifter.vcd");
            $dumpvars(0, tb_barrel_shifter);
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

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
