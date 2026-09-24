`timescale 1ns / 1ps

// tb_cla4: exhaustive over all 4-bit a, 4-bit b and cin (2^9 = 512
// cases), checked against the integer sum a+b+cin split into
// {carry_out,sum} — identical test methodology to program 064's rca4,
// so the two architectures' correctness can be directly compared.
module tb_cla4;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi, ci;

    reg  [3:0] a, b;
    reg        cin;
    wire [3:0] sum;
    wire       carry_out;

    cla4 dut (.a(a), .b(b), .cin(cin), .sum(sum), .carry_out(carry_out));

    task check;
        reg [4:0] expected;
        begin
            #1;
            expected = a + b + cin;
            checks = checks + 1;
            if (sum !== expected[3:0] || carry_out !== expected[4]) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d cin=%b expected sum=%0d carry=%b actual sum=%0d carry=%b",
                          a, b, cin, expected[3:0], expected[4], sum, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_cla4.vcd");
            $dumpvars(0, tb_cla4);
        end

        for (ai = 0; ai < 16; ai = ai + 1)
            for (bi = 0; bi < 16; bi = bi + 1)
                for (ci = 0; ci < 2; ci = ci + 1) begin
                    a = ai[3:0]; b = bi[3:0]; cin = ci[0];
                    check;
                end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
