`timescale 1ns / 1ps

module tb_mux_n;

    integer errors = 0;
    integer checks = 0;
    integer i, n, k;

    // ---- Instance A: N=4, WIDTH=1 -- exhaustive over sel and all data bits
    localparam NA = 4;
    localparam WA = 1;
    reg  [$clog2(NA)-1:0] selA;
    reg  [NA*WA-1:0]      dataA;
    wire [WA-1:0]         yA;

    mux_n #(.WIDTH(WA), .N(NA)) dutA (.sel(selA), .data(dataA), .y(yA));

    // ---- Instance B: N=8, WIDTH=8 -- random data, full select sweep -------
    localparam NB = 8;
    localparam WB = 8;
    reg  [$clog2(NB)-1:0] selB;
    reg  [NB*WB-1:0]      dataB;
    wire [WB-1:0]         yB;
    reg  [WB-1:0]         elemB [0:NB-1];

    mux_n #(.WIDTH(WB), .N(NB)) dutB (.sel(selB), .data(dataB), .y(yB));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mux_n.vcd");
            $dumpvars(0, tb_mux_n);
        end

        // Exhaustive: N=4, WIDTH=1 -> {sel[1:0], data[3:0]} = 64 combinations
        $display("N=4 WIDTH=1 exhaustive (64 combinations):");
        for (i = 0; i < 64; i = i + 1) begin
            {selA, dataA} = i[5:0];
            #1;
            checks = checks + 1;
            if (yA !== dataA[selA*WA +: WA]) begin
                errors = errors + 1;
                $display("ERROR: N=4 sel=%0d data=%b expected=%b actual=%b",
                          selA, dataA, dataA[selA*WA +: WA], yA);
            end
        end

        // Random: N=8, WIDTH=8 -- 200 random data sets x all 8 sel values
        $display("N=8 WIDTH=8 random (200 data sets x 8 sel values):");
        for (n = 0; n < 200; n = n + 1) begin
            dataB = {NB*WB{1'b0}};
            for (k = 0; k < NB; k = k + 1) begin
                elemB[k] = $random;
                dataB[k*WB +: WB] = elemB[k];
            end
            for (k = 0; k < NB; k = k + 1) begin
                selB = k[$clog2(NB)-1:0];
                #1;
                checks = checks + 1;
                if (yB !== elemB[k]) begin
                    errors = errors + 1;
                    $display("ERROR: N=8 sel=%0d expected=%h actual=%h", selB, elemB[k], yB);
                end
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
