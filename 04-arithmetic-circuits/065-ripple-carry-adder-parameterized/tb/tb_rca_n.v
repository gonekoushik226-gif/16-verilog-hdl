`timescale 1ns / 1ps

// tb_rca_n: two instances — WIDTH=4 exhaustive (2^9 = 512 cases) and
// WIDTH=32 with 2000 random operand/cin combinations — each checked
// against a wide-integer reference sum.
module tb_rca_n;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi, ci, r;

    // ---- WIDTH = 4, exhaustive ----
    reg  [3:0] a4, b4;
    reg        cin4;
    wire [3:0] sum4;
    wire       carry4;

    rca_n #(.WIDTH(4)) dut4 (.a(a4), .b(b4), .cin(cin4), .sum(sum4), .carry_out(carry4));

    // ---- WIDTH = 32, random ----
    reg  [31:0] a32, b32;
    reg         cin32;
    wire [31:0] sum32;
    wire        carry32;

    rca_n #(.WIDTH(32)) dut32 (.a(a32), .b(b32), .cin(cin32), .sum(sum32), .carry_out(carry32));

    task check4;
        reg [4:0] expected;
        begin
            #1;
            expected = a4 + b4 + cin4;
            checks = checks + 1;
            if (sum4 !== expected[3:0] || carry4 !== expected[4]) begin
                errors = errors + 1;
                $display("ERROR(W4): a=%0d b=%0d cin=%b expected sum=%0d carry=%b actual sum=%0d carry=%b",
                          a4, b4, cin4, expected[3:0], expected[4], sum4, carry4);
            end
        end
    endtask

    task check32;
        reg [32:0] expected;
        begin
            #1;
            expected = a32 + b32 + cin32;
            checks = checks + 1;
            if (sum32 !== expected[31:0] || carry32 !== expected[32]) begin
                errors = errors + 1;
                $display("ERROR(W32): a=%0d b=%0d cin=%b expected sum=%0d carry=%b actual sum=%0d carry=%b",
                          a32, b32, cin32, expected[31:0], expected[32], sum32, carry32);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_rca_n.vcd");
            $dumpvars(0, tb_rca_n);
        end

        for (ai = 0; ai < 16; ai = ai + 1)
            for (bi = 0; bi < 16; bi = bi + 1)
                for (ci = 0; ci < 2; ci = ci + 1) begin
                    a4 = ai[3:0]; b4 = bi[3:0]; cin4 = ci[0];
                    check4;
                end

        for (r = 0; r < 2000; r = r + 1) begin
            a32 = $random; b32 = $random; cin32 = $random;
            check32;
        end
        // corner cases: all-ones + 1, zero + zero + cin
        a32 = 32'hFFFF_FFFF; b32 = 32'd1; cin32 = 1'b0; check32;
        a32 = 32'hFFFF_FFFF; b32 = 32'hFFFF_FFFF; cin32 = 1'b1; check32;
        a32 = 32'd0; b32 = 32'd0; cin32 = 1'b0; check32;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
