`timescale 1ns / 1ps

// tb_bcd_counter_3digit: runs the full 1000-count cycle (000-999) plus
// a bit further to confirm wraparound back to 000, checking each digit
// and the overall carry_out against a software decimal reference every
// cycle.
module tb_bcd_counter_3digit;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    wire [3:0] ones, tens, hundreds;
    wire carry_out;

    integer ref_val;   // 0..999

    bcd_counter_3digit dut (.clk(clk), .rst_n(rst_n), .en(en),
                             .ones(ones), .tens(tens), .hundreds(hundreds), .carry_out(carry_out));

    always #5 clk = ~clk;

    task check;
        reg exp_carry;
        begin
            checks = checks + 1;
            exp_carry = en & (ref_val == 999);
            if (ones !== ref_val%10 || tens !== (ref_val/10)%10 || hundreds !== (ref_val/100)%10
                || carry_out !== exp_carry) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected val=%0d carry=%b actual ones=%0d tens=%0d hundreds=%0d carry=%b",
                          $time, ref_val, exp_carry, ones, tens, hundreds, carry_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bcd_counter_3digit.vcd");
            $dumpvars(0, tb_bcd_counter_3digit);
        end

        rst_n = 0; en = 0; ref_val = 0;
        @(negedge clk); check;
        rst_n = 1; en = 1;

        for (i = 0; i < 1005; i = i + 1) begin   // full 1000-count cycle + 5 more
            ref_val = (ref_val == 999) ? 0 : ref_val + 1;
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
