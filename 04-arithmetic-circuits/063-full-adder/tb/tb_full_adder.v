`timescale 1ns / 1ps

// tb_full_adder: exhaustive 3-bit input space (a,b,cin) checked against
// the integer sum a+b+cin split into {carry_out,sum}.
module tb_full_adder;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  a, b, cin;
    wire sum, carry_out;

    full_adder dut (.a(a), .b(b), .cin(cin), .sum(sum), .carry_out(carry_out));

    task check;
        reg [1:0] expected;
        begin
            #1;
            expected = a + b + cin;
            checks = checks + 1;
            if (sum !== expected[0] || carry_out !== expected[1]) begin
                errors = errors + 1;
                $display("ERROR: a=%b b=%b cin=%b expected sum=%b carry=%b actual sum=%b carry=%b",
                          a, b, cin, expected[0], expected[1], sum, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_full_adder.vcd");
            $dumpvars(0, tb_full_adder);
        end

        for (i = 0; i < 8; i = i + 1) begin
            {a, b, cin} = i[2:0];
            check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
