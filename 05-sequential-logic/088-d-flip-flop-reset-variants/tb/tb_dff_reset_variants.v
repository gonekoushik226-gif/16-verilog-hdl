`timescale 1ns / 1ps

// tb_dff_reset_variants: runs all three reset styles side by side with
// identical d/clk stimulus, then asserts each reset *between* clock
// edges and checks the defining difference: the two asynchronous
// variants react immediately (before the next clock edge), while the
// synchronous variant keeps its old value until the next posedge clk.
module tb_dff_reset_variants;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_ah, rst_n_al, rst_sync;   // active-high async, active-low async, active-high sync
    reg d;

    wire qa, qan, qs;

    dff_async_reset   u_a  (.clk(clk), .rst(rst_ah),      .d(d), .q(qa));
    dff_async_reset_n u_an (.clk(clk), .rst_n(rst_n_al),  .d(d), .q(qan));
    dff_sync_reset    u_s  (.clk(clk), .rst(rst_sync),    .d(d), .q(qs));

    always #5 clk = ~clk;

    task check(input exp_a, input exp_an, input exp_s);
        begin
            checks = checks + 1;
            if (qa !== exp_a || qan !== exp_an || qs !== exp_s) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected qa=%b qan=%b qs=%b actual qa=%b qan=%b qs=%b",
                          $time, exp_a, exp_an, exp_s, qa, qan, qs);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_dff_reset_variants.vcd");
            $dumpvars(0, tb_dff_reset_variants);
        end

        rst_ah = 1; rst_n_al = 0; rst_sync = 1; d = 0;
        #1;
        // the async variants reset immediately; the sync variant's q is
        // still undefined until its first clock edge, so it is checked
        // separately right after that edge below
        checks = checks + 1;
        if (qa !== 1'b0 || qan !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR: time=%0t expected qa=0 qan=0 actual qa=%b qan=%b", $time, qa, qan);
        end
        @(posedge clk); #1; check(1'b0, 1'b0, 1'b0);   // sync variant now reset too

        rst_ah = 0; rst_n_al = 1; rst_sync = 0;
        d = 1; @(posedge clk); #1; check(1'b1, 1'b1, 1'b1);
        d = 0; @(posedge clk); #1; check(1'b0, 1'b0, 1'b0);
        d = 1; @(posedge clk); #1; check(1'b1, 1'b1, 1'b1);

        // assert all three resets between clock edges (mid-low-phase)
        @(negedge clk);
        #2;
        rst_ah = 1; rst_n_al = 0; rst_sync = 1;
        #1;
        // asynchronous variants react immediately; synchronous does not
        check(1'b0, 1'b0, 1'b1);

        // at the next posedge, the synchronous variant also resets
        @(posedge clk); #1;
        check(1'b0, 1'b0, 1'b0);

        // release resets and confirm normal operation resumes together
        rst_ah = 0; rst_n_al = 1; rst_sync = 0;
        d = 1; @(posedge clk); #1; check(1'b1, 1'b1, 1'b1);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
