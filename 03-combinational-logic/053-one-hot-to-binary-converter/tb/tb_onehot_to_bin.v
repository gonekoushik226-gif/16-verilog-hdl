`timescale 1ns / 1ps

// tb_onehot_to_bin: exhaustive WIDTH=8 sweep (all one-hot and all invalid
// codes), plus a random + directed WIDTH=16 sweep to confirm the OR-tree
// generalizes beyond the exhaustively-checked width.
module tb_onehot_to_bin;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer i, n, b, popcount, bit_idx;

    // ---- WIDTH=8: exhaustive ------------------------------------------------
    reg  [7:0] oh8;
    wire [2:0] bin8;
    wire       valid8;

    onehot_to_bin #(.WIDTH(8)) dut8 (.onehot(oh8), .bin(bin8), .valid(valid8));

    // ---- WIDTH=16: random + directed ----------------------------------------
    reg  [15:0] oh16;
    wire [3:0]  bin16;
    wire        valid16;

    onehot_to_bin #(.WIDTH(16)) dut16 (.onehot(oh16), .bin(bin16), .valid(valid16));

    task check8(input [7:0] v);
        reg [2:0] exp_bin;
        reg       exp_valid;
        begin
            oh8 = v;
            #1;
            popcount = 0; bit_idx = 0;
            for (b = 0; b < 8; b = b + 1)
                if (v[b]) begin popcount = popcount + 1; bit_idx = b; end
            exp_valid = (popcount == 1);
            exp_bin   = exp_valid ? bit_idx[2:0] : 3'b000;
            checks = checks + 1;
            if (valid8 !== exp_valid || (exp_valid && bin8 !== exp_bin)) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=8 onehot=%b expected valid=%b bin=%0d actual valid=%b bin=%0d",
                          v, exp_valid, exp_bin, valid8, bin8);
            end
        end
    endtask

    task check16(input [15:0] v);
        reg [3:0] exp_bin;
        reg       exp_valid;
        begin
            oh16 = v;
            #1;
            popcount = 0; bit_idx = 0;
            for (b = 0; b < 16; b = b + 1)
                if (v[b]) begin popcount = popcount + 1; bit_idx = b; end
            exp_valid = (popcount == 1);
            exp_bin   = exp_valid ? bit_idx[3:0] : 4'b0000;
            checks = checks + 1;
            if (valid16 !== exp_valid || (exp_valid && bin16 !== exp_bin)) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=16 onehot=%b expected valid=%b bin=%0d actual valid=%b bin=%0d",
                          v, exp_valid, exp_bin, valid16, bin16);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_onehot_to_bin.vcd");
            $dumpvars(0, tb_onehot_to_bin);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        $display("WIDTH=8 exhaustive sweep (256 codes: 8 one-hot + 248 invalid)...");
        for (i = 0; i < 256; i = i + 1)
            check8(i[7:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("WIDTH=16 directed one-hot codes (16 codes)...");
        for (i = 0; i < 16; i = i + 1)
            check16(16'b1 << i);
        $display("WIDTH=16 directed invalid codes (all-zero, all-ones, two-hot)...");
        check16(16'h0000);
        check16(16'hFFFF);
        for (i = 0; i < 15; i = i + 1)
            check16((16'b1 << i) | (16'b1 << (i + 1)));
        $display("WIDTH=16 random codes (2000 vectors)...");
        for (n = 0; n < 2000; n = n + 1)
            check16({$random(seed)} & 16'hFFFF);
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
