`timescale 1ns / 1ps

// tb_mod_n_counter: three DUT instances at different (including
// non-power-of-two) moduli, each run for more than two full cycles and
// checked against a software 0..MOD-1 reference counter.
module tb_mod_n_counter;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;

    wire [2:0] c5;    // MOD=5
    wire [3:0] c10;   // MOD=10
    wire [3:0] c13;   // MOD=13 (non-power-of-two)

    reg [3:0] ref5, ref10, ref13;

    mod_n_counter #(.MOD(5))  dut5  (.clk(clk), .rst_n(rst_n), .en(en), .count(c5),  .tc());
    mod_n_counter #(.MOD(10)) dut10 (.clk(clk), .rst_n(rst_n), .en(en), .count(c10), .tc());
    mod_n_counter #(.MOD(13)) dut13 (.clk(clk), .rst_n(rst_n), .en(en), .count(c13), .tc());

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (c5 !== ref5[2:0] || c10 !== ref10 || c13 !== ref13) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected c5=%0d c10=%0d c13=%0d actual c5=%0d c10=%0d c13=%0d",
                          $time, ref5, ref10, ref13, c5, c10, c13);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_mod_n_counter.vcd");
            $dumpvars(0, tb_mod_n_counter);
        end

        rst_n = 0; en = 0; ref5 = 0; ref10 = 0; ref13 = 0;
        @(negedge clk); check;
        rst_n = 1; en = 1;

        for (i = 0; i < 30; i = i + 1) begin   // > 2 full cycles of the largest modulus (13)
            ref5  = (ref5  == 4)  ? 0 : ref5  + 1;
            ref10 = (ref10 == 9)  ? 0 : ref10 + 1;
            ref13 = (ref13 == 12) ? 0 : ref13 + 1;
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
