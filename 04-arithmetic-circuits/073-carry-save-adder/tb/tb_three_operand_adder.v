`timescale 1ns / 1ps

// tb_three_operand_adder: 3000 random 8-bit (a,b,c) triples plus the
// all-maximum corner case, checked against a wide Verilog reference
// a+b+c.
module tb_three_operand_adder;

    integer errors = 0;
    integer checks = 0;
    integer r;

    reg  [7:0] a, b, c;
    wire [9:0] sum;

    three_operand_adder #(.WIDTH(8)) dut (.a(a), .b(b), .c(c), .sum(sum));

    task check;
        reg [9:0] expected;
        begin
            #1;
            expected = a + b + c;
            checks = checks + 1;
            if (sum !== expected) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d c=%0d expected sum=%0d actual sum=%0d",
                          a, b, c, expected, sum);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_three_operand_adder.vcd");
            $dumpvars(0, tb_three_operand_adder);
        end

        for (r = 0; r < 3000; r = r + 1) begin
            a = $random; b = $random; c = $random;
            check;
        end

        a = 8'hFF; b = 8'hFF; c = 8'hFF; check;   // maximum sum: 765
        a = 8'h00; b = 8'h00; c = 8'h00; check;
        a = 8'hFF; b = 8'h00; c = 8'h00; check;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
