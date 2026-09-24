`timescale 1ns / 1ps

// tb_cska: 3000 random (a,b,cin) combinations plus directed cases that
// force each block's block_p to 1 (a = ~b within that nibble, so every
// bit propagates and the skip mux path is exercised instead of the
// ripple path), checked against a 9-bit Verilog reference a+b+cin.
module tb_cska;

    integer errors = 0;
    integer checks = 0;
    integer r;

    reg  [7:0] a, b;
    reg        cin;
    wire [7:0] sum;
    wire       carry_out;

    cska dut (.a(a), .b(b), .cin(cin), .sum(sum), .carry_out(carry_out));

    task check;
        reg [8:0] expected;
        begin
            #1;
            expected = a + b + cin;
            checks = checks + 1;
            if (sum !== expected[7:0] || carry_out !== expected[8]) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d cin=%b expected sum=%0d carry=%b actual sum=%0d carry=%b",
                          a, b, cin, expected[7:0], expected[8], sum, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_cska.vcd");
            $dumpvars(0, tb_cska);
        end

        for (r = 0; r < 3000; r = r + 1) begin
            a = $random; b = $random; cin = $random;
            check;
        end

        // both nibbles fully propagate (a = ~b in each nibble): exercises
        // the skip mux path in both blocks, for both values of cin
        a = 8'b0101_0101; b = 8'b1010_1010; cin = 1'b0; check;
        a = 8'b0101_0101; b = 8'b1010_1010; cin = 1'b1; check;
        // low nibble propagates, high nibble does not
        a = 8'b1100_0011; b = 8'b0011_0011; cin = 1'b1; check;
        // no bits propagate anywhere (a = b in each nibble)
        a = 8'b1111_0000; b = 8'b1111_0000; cin = 1'b1; check;
        // full-width corners
        a = 8'hFF; b = 8'hFF; cin = 1'b1; check;
        a = 8'h00; b = 8'h00; cin = 1'b0; check;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
