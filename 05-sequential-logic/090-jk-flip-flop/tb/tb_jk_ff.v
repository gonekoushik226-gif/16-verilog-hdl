`timescale 1ns / 1ps

// tb_jk_ff: exhaustively drives all 4 (j,k) combinations from both
// possible starting states of q, checking against the JK characteristic
// table.
module tb_jk_ff;

    integer errors = 0;
    integer checks = 0;
    integer ji, ki;

    reg clk = 0;
    reg rst_n, j, k;
    wire q;

    jk_ff dut (.clk(clk), .rst_n(rst_n), .j(j), .k(k), .q(q));

    always #5 clk = ~clk;

    task check(input expected);
        begin
            checks = checks + 1;
            if (q !== expected) begin
                errors = errors + 1;
                $display("ERROR: time=%0t j=%b k=%b expected q=%b actual q=%b", $time, j, k, expected, q);
            end
        end
    endtask

    task set_q(input val);
        begin
            rst_n = 0; @(negedge clk);
            rst_n = 1;
            if (val) begin
                j = 1; k = 0; @(posedge clk); #1;
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_jk_ff.vcd");
            $dumpvars(0, tb_jk_ff);
        end

        for (ji = 0; ji < 2; ji = ji + 1)
            for (ki = 0; ki < 2; ki = ki + 1) begin
                // from q=0
                set_q(0); check(1'b0);
                j = ji[0]; k = ki[0];
                @(posedge clk); #1;
                case ({ji[0], ki[0]})
                    2'b00: check(1'b0);
                    2'b01: check(1'b0);
                    2'b10: check(1'b1);
                    2'b11: check(1'b1);
                endcase

                // from q=1
                set_q(1); check(1'b1);
                j = ji[0]; k = ki[0];
                @(posedge clk); #1;
                case ({ji[0], ki[0]})
                    2'b00: check(1'b1);
                    2'b01: check(1'b0);
                    2'b10: check(1'b1);
                    2'b11: check(1'b0);
                endcase
            end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
