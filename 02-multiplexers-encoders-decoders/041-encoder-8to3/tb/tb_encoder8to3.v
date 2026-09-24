`timescale 1ns / 1ps

module tb_encoder8to3;

    reg  [7:0] d;
    wire [2:0] y;
    wire       valid;

    integer errors = 0;
    integer checks = 0;
    integer i, popcount, bit_idx, b;
    reg  [2:0] expected_y;
    reg        expected_valid;

    encoder8to3 dut (.d(d), .y(y), .valid(valid));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_encoder8to3.vcd");
            $dumpvars(0, tb_encoder8to3);
        end

        // Exhaustive: all 256 values of d, one-hot and invalid alike
        for (i = 0; i < 256; i = i + 1) begin
            d = i[7:0];
            #1;

            popcount = 0;
            bit_idx  = 0;
            for (b = 0; b < 8; b = b + 1) begin
                if (d[b]) begin
                    popcount = popcount + 1;
                    bit_idx  = b;
                end
            end

            expected_valid = (popcount == 1);
            expected_y     = expected_valid ? bit_idx[2:0] : 3'b000;

            checks = checks + 1;
            if (valid !== expected_valid || (expected_valid && y !== expected_y)) begin
                errors = errors + 1;
                $display("ERROR: t=%0t d=%b expected valid=%b y=%b actual valid=%b y=%b",
                          $time, d, expected_valid, expected_y, valid, y);
            end
        end
        $display("checked all 256 input codes (8 one-hot, 248 invalid)");
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
