`timescale 1ns / 1ps

// tb_register_n: checks reset, hold (en=0), load (en=1), and 20 random
// load/hold cycles at WIDTH=8.
module tb_register_n;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    reg [WIDTH-1:0] d;
    wire [WIDTH-1:0] q;

    reg [WIDTH-1:0] ref_q;

    register_n #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .d(d), .q(q));

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (q !== ref_q) begin
                errors = errors + 1;
                $display("ERROR: time=%0t en=%b d=%0d expected q=%0d actual q=%0d", $time, en, d, ref_q, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_register_n.vcd");
            $dumpvars(0, tb_register_n);
        end

        rst_n = 0; en = 0; d = 8'hFF; ref_q = 0;
        @(negedge clk); check;

        rst_n = 1;
        en = 1; d = 8'hA5; ref_q = 8'hA5; @(posedge clk); #1; check;
        en = 0; d = 8'h00; @(posedge clk); #1; check;      // hold
        en = 0; d = 8'hFF; @(posedge clk); #1; check;      // still hold
        en = 1; d = 8'h3C; ref_q = 8'h3C; @(posedge clk); #1; check;

        for (i = 0; i < 20; i = i + 1) begin
            en = $random;
            d  = $random;
            if (en) ref_q = d;
            @(posedge clk); #1; check;
        end

        // reset overrides enable
        en = 1; d = 8'hFF; rst_n = 0; ref_q = 0; #1; check;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
