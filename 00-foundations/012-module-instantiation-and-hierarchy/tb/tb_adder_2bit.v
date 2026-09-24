`timescale 1ns / 1ps

module tb_adder_2bit;

    reg  [1:0] a, b;
    reg        cin;
    wire [1:0] sum;
    wire       cout;

    integer errors = 0;
    integer checks = 0;
    integer n, total;

    adder_2bit dut (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_adder_2bit.vcd");
            $dumpvars(0, tb_adder_2bit);
        end

        $display(" a  b cin | cout sum | carry_mid fa0.ha_ab.sum");
        for (n = 0; n < 32; n = n + 1) begin
            {a, b, cin} = n[4:0];
            #1;
            total = a + b + cin;
            checks = checks + 1;
            if ({cout, sum} !== total) begin
                errors = errors + 1;
                $display("ERROR: %0d + %0d + %0d = %0d, got %0d", a, b, cin, total, {cout, sum});
            end
            // Hierarchical references reach inside the DUT: instance.instance.signal
            checks = checks + 1;
            if (dut.carry_mid !== (a[0] + b[0] + cin >= 2) ||
                dut.fa0.ha_ab.sum !== (a[0] ^ b[0])) begin
                errors = errors + 1;
                $display("ERROR: internal nets wrong for a=%b b=%b cin=%b", a, b, cin);
            end
            if (n % 4 == 1)
                $display("%b %b  %b  |  %b   %b  |     %b         %b",
                         a, b, cin, cout, sum, dut.carry_mid, dut.fa0.ha_ab.sum);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
