`timescale 1ns / 1ps

module tb_demux_n;

    integer errors = 0;
    integer checks = 0;
    integer i, k;

    // ---- Parameter set A: N=4, WIDTH=4 -- exhaustive {sel,d} (64 combos) ---
    localparam NA = 4;
    localparam WA = 4;
    reg  [$clog2(NA)-1:0] selA;
    reg  [WA-1:0]         dA;
    wire [NA*WA-1:0]      yA;
    reg  [WA-1:0]         expA;
    integer                mismatchA;

    demux_n #(.WIDTH(WA), .N(NA)) dutA (.sel(selA), .d(dA), .y(yA));

    // ---- Parameter set B: N=8, WIDTH=2 -- exhaustive {sel,d} (32 combos) ---
    localparam NB = 8;
    localparam WB = 2;
    reg  [$clog2(NB)-1:0] selB;
    reg  [WB-1:0]         dB;
    wire [NB*WB-1:0]      yB;
    reg  [WB-1:0]         expB;
    integer                mismatchB;

    demux_n #(.WIDTH(WB), .N(NB)) dutB (.sel(selB), .d(dB), .y(yB));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_demux_n.vcd");
            $dumpvars(0, tb_demux_n);
        end

        // Exhaustive: N=4, WIDTH=4 -> sel(4) x d(16) = 64 combinations
        $display("N=4 WIDTH=4 exhaustive (64 combinations):");
        for (i = 0; i < NA; i = i + 1) begin
            for (k = 0; k < (1 << WA); k = k + 1) begin
                selA = i[$clog2(NA)-1:0];
                dA   = k[WA-1:0];
                #1;
                checks = checks + 1;
                mismatchA = 0;
                // Every output slot must equal d if its index matches sel, else 0
                begin : checkA
                    integer j;
                    for (j = 0; j < NA; j = j + 1) begin
                        expA = (j == selA) ? dA : {WA{1'b0}};
                        if (yA[j*WA +: WA] !== expA) mismatchA = 1;
                    end
                end
                if (mismatchA) begin
                    errors = errors + 1;
                    $display("ERROR: N=4 sel=%0d d=%h y=%h", selA, dA, yA);
                end
            end
        end

        // Exhaustive: N=8, WIDTH=2 -> sel(8) x d(4) = 32 combinations
        $display("N=8 WIDTH=2 exhaustive (32 combinations):");
        for (i = 0; i < NB; i = i + 1) begin
            for (k = 0; k < (1 << WB); k = k + 1) begin
                selB = i[$clog2(NB)-1:0];
                dB   = k[WB-1:0];
                #1;
                checks = checks + 1;
                mismatchB = 0;
                begin : checkB
                    integer j;
                    for (j = 0; j < NB; j = j + 1) begin
                        expB = (j == selB) ? dB : {WB{1'b0}};
                        if (yB[j*WB +: WB] !== expB) mismatchB = 1;
                    end
                end
                if (mismatchB) begin
                    errors = errors + 1;
                    $display("ERROR: N=8 sel=%0d d=%h y=%h", selB, dB, yB);
                end
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
