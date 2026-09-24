`timescale 1ns / 1ps

// tb_sr_ff: exhaustively drives all 4 (s,r) combinations from both
// starting states of q, checking against this design's documented
// hold/set/reset/invalid-holds policy and the invalid flag.
module tb_sr_ff;

    integer errors = 0;
    integer checks = 0;
    integer si, ri;

    reg clk = 0;
    reg rst_n, s, r;
    wire q, invalid;

    sr_ff dut (.clk(clk), .rst_n(rst_n), .s(s), .r(r), .q(q), .invalid(invalid));

    always #5 clk = ~clk;

    task check(input expected_q, input expected_invalid);
        begin
            checks = checks + 1;
            if (q !== expected_q || invalid !== expected_invalid) begin
                errors = errors + 1;
                $display("ERROR: time=%0t s=%b r=%b expected q=%b invalid=%b actual q=%b invalid=%b",
                          $time, s, r, expected_q, expected_invalid, q, invalid);
            end
        end
    endtask

    task set_q(input val);
        begin
            s = 0; r = 0;
            rst_n = 0; @(negedge clk);
            rst_n = 1;
            if (val) begin
                s = 1; r = 0; @(posedge clk); #1;
            end
            s = 0; r = 0; #1;
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_sr_ff.vcd");
            $dumpvars(0, tb_sr_ff);
        end

        for (si = 0; si < 2; si = si + 1)
            for (ri = 0; ri < 2; ri = ri + 1) begin
                // from q=0
                set_q(0); check(1'b0, 1'b0);
                s = si[0]; r = ri[0]; #1;
                check(1'b0, si[0] & ri[0]);   // invalid flag is combinational
                @(posedge clk); #1;
                case ({si[0], ri[0]})
                    2'b00: check(1'b0, 1'b0);
                    2'b01: check(1'b0, 1'b0);
                    2'b10: check(1'b1, 1'b0);
                    2'b11: check(1'b0, 1'b1);   // invalid: holds at 0
                endcase

                // from q=1
                set_q(1); check(1'b1, 1'b0);
                s = si[0]; r = ri[0]; #1;
                @(posedge clk); #1;
                case ({si[0], ri[0]})
                    2'b00: check(1'b1, 1'b0);
                    2'b01: check(1'b0, 1'b0);
                    2'b10: check(1'b1, 1'b0);
                    2'b11: check(1'b1, 1'b1);   // invalid: holds at 1
                endcase
            end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
