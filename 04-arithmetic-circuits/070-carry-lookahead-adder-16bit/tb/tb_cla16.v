`timescale 1ns / 1ps

// tb_cla16: 2000 random (a,b,cin) triples plus directed corner cases,
// checked against Verilog's own wide-integer + operator.
module tb_cla16;

    integer errors = 0;
    integer checks = 0;
    integer r;

    reg  [15:0] a, b;
    reg         cin;
    wire [15:0] sum;
    wire        carry_out;

    cla16 dut (.a(a), .b(b), .cin(cin), .sum(sum), .carry_out(carry_out));

    task check;
        reg [16:0] expected;
        begin
            #1;
            expected = a + b + cin;
            checks = checks + 1;
            if (sum !== expected[15:0] || carry_out !== expected[16]) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d cin=%b expected sum=%0d carry=%b actual sum=%0d carry=%b",
                          a, b, cin, expected[15:0], expected[16], sum, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_cla16.vcd");
            $dumpvars(0, tb_cla16);
        end

        for (r = 0; r < 2000; r = r + 1) begin
            a = $random; b = $random; cin = $random;
            check;
        end

        // corner cases: max propagation chains and boundary values
        a = 16'h0000; b = 16'h0000; cin = 1'b0; check;   // 0+0+0
        a = 16'hFFFF; b = 16'h0000; cin = 1'b1; check;   // all-propagate chain, wraps to 0
        a = 16'hFFFF; b = 16'hFFFF; cin = 1'b1; check;   // maximum carry generation
        a = 16'h8000; b = 16'h8000; cin = 1'b0; check;   // MSB-only overflow
        a = 16'h7FFF; b = 16'h0001; cin = 1'b0; check;   // ripple across nibble boundary
        a = 16'h0FFF; b = 16'h0001; cin = 1'b0; check;   // ripple across nibble boundary

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
