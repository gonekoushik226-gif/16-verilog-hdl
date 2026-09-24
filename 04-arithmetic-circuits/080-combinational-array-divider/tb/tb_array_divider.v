`timescale 1ns / 1ps

// tb_array_divider: exhaustive over all 64x64=4096 combinations of 6-bit
// dividend and divisor (including divisor=0), checked against a
// reference model matching this design's documented divide-by-zero
// contract (quotient saturates to all-1s, remainder = dividend).
module tb_array_divider;

    integer errors = 0;
    integer checks = 0;
    integer di, vi;

    reg  [5:0] dividend, divisor;
    wire [5:0] quotient, remainder;
    wire       div_by_zero;

    array_divider #(.WIDTH(6)) dut (
        .dividend(dividend), .divisor(divisor),
        .quotient(quotient), .remainder(remainder), .div_by_zero(div_by_zero)
    );

    task check;
        reg [5:0] expected_q, expected_r;
        begin
            #1;
            checks = checks + 1;
            if (divisor == 6'd0) begin
                expected_q = 6'h3F;
                expected_r = dividend;
            end else begin
                expected_q = dividend / divisor;
                expected_r = dividend % divisor;
            end
            if (quotient !== expected_q || remainder !== expected_r
                || div_by_zero !== (divisor == 6'd0)) begin
                errors = errors + 1;
                $display("ERROR: dividend=%0d divisor=%0d expected q=%0d r=%0d dbz=%b actual q=%0d r=%0d dbz=%b",
                          dividend, divisor, expected_q, expected_r, (divisor == 6'd0),
                          quotient, remainder, div_by_zero);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_array_divider.vcd");
            $dumpvars(0, tb_array_divider);
        end

        for (di = 0; di < 64; di = di + 1)
            for (vi = 0; vi < 64; vi = vi + 1) begin
                dividend = di[5:0]; divisor = vi[5:0];
                check;
            end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
