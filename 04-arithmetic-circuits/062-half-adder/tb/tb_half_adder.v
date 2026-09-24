`timescale 1ns / 1ps

// tb_half_adder: exhaustive 2-bit input space (a,b) checked against the
// integer sum a+b split into {carry,sum}.
module tb_half_adder;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  a, b;
    wire sum, carry;

    half_adder dut (.a(a), .b(b), .sum(sum), .carry(carry));

    task check;
        reg [1:0] expected;
        begin
            #1;
            expected = a + b;
            checks = checks + 1;
            if (sum !== expected[0] || carry !== expected[1]) begin
                errors = errors + 1;
                $display("ERROR: a=%b b=%b expected sum=%b carry=%b actual sum=%b carry=%b",
                          a, b, expected[0], expected[1], sum, carry);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_half_adder.vcd");
            $dumpvars(0, tb_half_adder);
        end

        for (i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
