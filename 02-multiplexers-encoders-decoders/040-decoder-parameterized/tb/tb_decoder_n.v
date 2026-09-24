`timescale 1ns / 1ps

module tb_decoder_n;

    integer errors = 0;
    integer checks = 0;
    integer i;

    // ---- N=3: exhaustive over {en, a} (16 combinations) --------------------
    localparam N3 = 3;
    reg  [N3-1:0]        a3;
    reg                  en3;
    wire [(1<<N3)-1:0]   y3;
    reg  [(1<<N3)-1:0]   exp3;

    decoder_n #(.N(N3)) dut3 (.a(a3), .en(en3), .y(y3));

    // ---- N=4: exhaustive over {en, a} (32 combinations) --------------------
    localparam N4 = 4;
    reg  [N4-1:0]        a4;
    reg                  en4;
    wire [(1<<N4)-1:0]   y4;
    reg  [(1<<N4)-1:0]   exp4;

    decoder_n #(.N(N4)) dut4 (.a(a4), .en(en4), .y(y4));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_decoder_n.vcd");
            $dumpvars(0, tb_decoder_n);
        end

        // N=3: {en, a} -> 16 combinations
        $display("N=3 exhaustive (16 combinations):");
        for (i = 0; i < 16; i = i + 1) begin
            {en3, a3} = i[3:0];
            #1;
            exp3 = en3 ? ({{(1<<N3)-1{1'b0}}, 1'b1} << a3) : {(1<<N3){1'b0}};
            checks = checks + 1;
            if (y3 !== exp3) begin
                errors = errors + 1;
                $display("ERROR: N=3 en=%b a=%0d expected=%b actual=%b", en3, a3, exp3, y3);
            end
            if (en3 && (y3 == 0 || (y3 & (y3 - 1'b1)) != 0)) begin
                errors = errors + 1;
                $display("ERROR: N=3 enabled output not one-hot: y=%b", y3);
            end
        end

        // N=4: {en, a} -> 32 combinations
        $display("N=4 exhaustive (32 combinations):");
        for (i = 0; i < 32; i = i + 1) begin
            {en4, a4} = i[4:0];
            #1;
            exp4 = en4 ? ({{(1<<N4)-1{1'b0}}, 1'b1} << a4) : {(1<<N4){1'b0}};
            checks = checks + 1;
            if (y4 !== exp4) begin
                errors = errors + 1;
                $display("ERROR: N=4 en=%b a=%0d expected=%b actual=%b", en4, a4, exp4, y4);
            end
            if (en4 && (y4 == 0 || (y4 & (y4 - 1'b1)) != 0)) begin
                errors = errors + 1;
                $display("ERROR: N=4 enabled output not one-hot: y=%b", y4);
            end
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
