`timescale 1ns / 1ps

// tb_bcd_counter: runs a full decade plus a bit further to confirm
// wraparound, checking count and carry_out every cycle against a
// software 0-9 reference.
module tb_bcd_counter;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    wire [3:0] count;
    wire carry_out;

    reg [3:0] ref_count;

    bcd_counter dut (.clk(clk), .rst_n(rst_n), .en(en), .count(count), .carry_out(carry_out));

    always #5 clk = ~clk;

    task check;
        reg exp_carry;
        begin
            checks = checks + 1;
            exp_carry = en & (count == 4'd9);
            if (count !== ref_count || carry_out !== exp_carry) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected count=%0d carry=%b actual count=%0d carry=%b",
                          $time, ref_count, exp_carry, count, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bcd_counter.vcd");
            $dumpvars(0, tb_bcd_counter);
        end

        rst_n = 0; en = 0; ref_count = 0;
        @(negedge clk); check;
        rst_n = 1; en = 1;

        for (i = 0; i < 15; i = i + 1) begin   // full decade + 5 more to confirm wrap
            ref_count = (ref_count == 9) ? 0 : ref_count + 1;
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
