`timescale 1ns / 1ps

// tb_csla: 3000 random (a,b,cin) combinations plus directed carry-chain
// corner cases (values chosen to force each nibble's carry_out to both
// 0 and 1, and to exercise the mux selecting the cin=1 speculative
// path), checked against a 9-bit Verilog reference a+b+cin.
module tb_csla;

    integer errors = 0;
    integer checks = 0;
    integer r;

    reg  [7:0] a, b;
    reg        cin;
    wire [7:0] sum;
    wire       carry_out;

    csla dut (.a(a), .b(b), .cin(cin), .sum(sum), .carry_out(carry_out));

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
            $dumpfile("build/tb_csla.vcd");
            $dumpvars(0, tb_csla);
        end

        for (r = 0; r < 3000; r = r + 1) begin
            a = $random; b = $random; cin = $random;
            check;
        end

        // force low-nibble carry_out=0, selecting the cin=0 speculative high half
        a = 8'h01; b = 8'h01; cin = 1'b0; check;
        // force low-nibble carry_out=1, selecting the cin=1 speculative high half
        a = 8'h0F; b = 8'h01; cin = 1'b0; check;
        a = 8'h0F; b = 8'h0F; cin = 1'b1; check;
        // full-width propagate/generate corners
        a = 8'hFF; b = 8'h00; cin = 1'b1; check;
        a = 8'hFF; b = 8'hFF; cin = 1'b1; check;
        a = 8'h00; b = 8'h00; cin = 1'b0; check;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
