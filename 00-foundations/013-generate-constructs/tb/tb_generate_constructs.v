`timescale 1ns / 1ps

module tb_generate_constructs;

    // Two widths of the Gray converters, chained so that bin -> gray -> bin
    reg  [3:0] bin4;
    wire [3:0] gray4, back4;
    reg  [7:0] bin8;
    wire [7:0] gray8, back8;

    // Both adder architectures at WIDTH = 8
    reg  [7:0] a, b;
    reg        cin;
    wire [7:0] sum_r, sum_b;
    wire       cout_r, cout_b;

    integer errors = 0;
    integer checks = 0;
    integer n;
    reg [8:0] expected;

    bin2gray_gen #(.WIDTH(4)) u_b2g4 (.bin(bin4), .gray(gray4));
    gray2bin_gen #(.WIDTH(4)) u_g2b4 (.gray(gray4), .bin(back4));
    bin2gray_gen #(.WIDTH(8)) u_b2g8 (.bin(bin8), .gray(gray8));
    gray2bin_gen #(.WIDTH(8)) u_g2b8 (.gray(gray8), .bin(back8));

    configurable_adder #(.WIDTH(8), .ARCH(0)) u_ripple (.a(a), .b(b), .cin(cin), .sum(sum_r), .cout(cout_r));
    configurable_adder #(.WIDTH(8), .ARCH(1)) u_behav  (.a(a), .b(b), .cin(cin), .sum(sum_b), .cout(cout_b));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_generate_constructs.vcd");
            $dumpvars(0, tb_generate_constructs);
        end

        // Gray code: expected gray = bin ^ (bin >> 1); round trip must restore bin
        $display("bin  gray back");
        for (n = 0; n < 16; n = n + 1) begin
            bin4 = n;
            #1;
            if (n < 8) $display("%b %b %b", bin4, gray4, back4);
            checks = checks + 1;
            if (gray4 !== (bin4 ^ (bin4 >> 1)) || back4 !== bin4) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=4 bin=%b gray=%b back=%b", bin4, gray4, back4);
            end
        end
        for (n = 0; n < 256; n = n + 1) begin
            bin8 = n;
            #1;
            checks = checks + 1;
            if (gray8 !== (bin8 ^ (bin8 >> 1)) || back8 !== bin8) begin
                errors = errors + 1;
                $display("ERROR: WIDTH=8 bin=%b gray=%b back=%b", bin8, gray8, back8);
            end
        end
        $display("Gray converters: WIDTH=4 and WIDTH=8 checked exhaustively");

        // Adders: all 2^17 input combinations for both architectures
        for (n = 0; n < (1 << 17); n = n + 1) begin
            {cin, a, b} = n[16:0];
            #1;
            expected = a + b + cin;
            checks = checks + 1;
            if ({cout_r, sum_r} !== expected || {cout_b, sum_b} !== expected) begin
                errors = errors + 1;
                if (errors < 10)
                    $display("ERROR: %0d+%0d+%0d ripple=%0d behavioral=%0d", a, b, cin,
                             {cout_r, sum_r}, {cout_b, sum_b});
            end
        end
        $display("Adders: ripple (generate-for) and behavioral checked for all %0d input combinations", 1 << 17);
        // Hierarchical path into a generate block: instance.block.signal
        $display("u_ripple.g_ripple.carry after last vector = %b", u_ripple.g_ripple.carry);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
