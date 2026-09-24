`timescale 1ns / 1ps

// tb_leading_zero_counter: exhaustive WIDTH=8 sweep and random WIDTH=32
// sweep, checking lzc_loop and lzc_tree against each other and against an
// independently written reference model.
module tb_leading_zero_counter;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer i, n, b;

    // ---- WIDTH=8: exhaustive -------------------------------------------------
    reg  [7:0] data8;
    wire [3:0] count_loop8, count_tree8;
    wire       az_loop8, az_tree8;

    lzc_loop #(.WIDTH(8)) dutLoop8 (.data(data8), .count(count_loop8), .all_zero(az_loop8));
    lzc_tree #(.WIDTH(8)) dutTree8 (.data(data8), .count(count_tree8), .all_zero(az_tree8));

    // ---- WIDTH=32: random -----------------------------------------------------
    reg  [31:0] data32;
    wire [5:0]  count_loop32, count_tree32;
    wire        az_loop32, az_tree32;

    lzc_loop #(.WIDTH(32)) dutLoop32 (.data(data32), .count(count_loop32), .all_zero(az_loop32));
    lzc_tree #(.WIDTH(32)) dutTree32 (.data(data32), .count(count_tree32), .all_zero(az_tree32));

    task check8(input [7:0] d);
        reg [3:0] exp_count;
        reg       exp_az;
        reg       found;
        begin
            data8 = d;
            #1;
            exp_az = (d == 8'b0);
            exp_count = 8;
            found = 1'b0;
            for (b = 7; b >= 0; b = b - 1)
                if (d[b] && !found) begin
                    exp_count = (7 - b);
                    found = 1'b1;
                end
            checks = checks + 1;
            if (count_loop8 !== exp_count || az_loop8 !== exp_az) begin
                errors = errors + 1;
                $display("ERROR: lzc_loop WIDTH=8 data=%b expected count=%0d all_zero=%b actual count=%0d all_zero=%b",
                          d, exp_count, exp_az, count_loop8, az_loop8);
            end
            checks = checks + 1;
            if (count_tree8 !== exp_count || az_tree8 !== exp_az) begin
                errors = errors + 1;
                $display("ERROR: lzc_tree WIDTH=8 data=%b expected count=%0d all_zero=%b actual count=%0d all_zero=%b",
                          d, exp_count, exp_az, count_tree8, az_tree8);
            end
        end
    endtask

    task check32(input [31:0] d);
        reg [5:0] exp_count;
        reg       exp_az;
        reg       found;
        begin
            data32 = d;
            #1;
            exp_az = (d == 32'b0);
            exp_count = 32;
            found = 1'b0;
            for (b = 31; b >= 0; b = b - 1)
                if (d[b] && !found) begin
                    exp_count = (31 - b);
                    found = 1'b1;
                end
            checks = checks + 1;
            if (count_loop32 !== exp_count || az_loop32 !== exp_az) begin
                errors = errors + 1;
                $display("ERROR: lzc_loop WIDTH=32 data=%h expected count=%0d all_zero=%b actual count=%0d all_zero=%b",
                          d, exp_count, exp_az, count_loop32, az_loop32);
            end
            checks = checks + 1;
            if (count_tree32 !== exp_count || az_tree32 !== exp_az) begin
                errors = errors + 1;
                $display("ERROR: lzc_tree WIDTH=32 data=%h expected count=%0d all_zero=%b actual count=%0d all_zero=%b",
                          d, exp_count, exp_az, count_tree32, az_tree32);
            end
            // cross-check: the two implementations must always agree with each other
            checks = checks + 1;
            if (count_loop32 !== count_tree32 || az_loop32 !== az_tree32) begin
                errors = errors + 1;
                $display("ERROR: lzc_loop/lzc_tree disagree WIDTH=32 data=%h loop={%0d,%b} tree={%0d,%b}",
                          d, count_loop32, az_loop32, count_tree32, az_tree32);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_leading_zero_counter.vcd");
            $dumpvars(0, tb_leading_zero_counter);
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
