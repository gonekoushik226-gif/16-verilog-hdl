`timescale 1ns / 1ps

// tb_serial_adder: for each (a_val, b_val, width) test, pulses `start`,
// then feeds both operands LSB-first, checking each `sum` bit against a
// plain `a_val + b_val` computed in the testbench (independent of the
// DUT's internal carry-state encoding), and checks the registered final
// carry after the last bit against expected bit `width` of that sum.
module tb_serial_adder;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg start, a, b;
    wire sum, carry_out;

    serial_adder dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a(a), .b(b), .sum(sum), .carry_out(carry_out)
    );

    always #5 clk = ~clk;

    task feed_addition(input [31:0] a_val, input [31:0] b_val, input integer width);
        integer i;
        reg [63:0] expected;
        begin
            expected = a_val + b_val;

            @(negedge clk); start = 1'b1; a = 1'b0; b = 1'b0;
            @(posedge clk);
            start = 1'b0;

            for (i = 0; i < width; i = i + 1) begin
                @(negedge clk);
                a = a_val[i]; b = b_val[i];
                #1;
                checks = checks + 1;
                if (sum !== expected[i]) begin
                    errors = errors + 1;
                    $display("ERROR: a=%0d b=%0d bit#%0d sum=%b expected=%b",
                              a_val, b_val, i, sum, expected[i]);
                end
                @(posedge clk);
            end

            #1;
            checks = checks + 1;
            if (carry_out !== expected[width]) begin
                errors = errors + 1;
                $display("ERROR: a=%0d b=%0d final carry_out=%b expected=%b",
                          a_val, b_val, carry_out, expected[width]);
            end
        end
    endtask

    integer r;
    integer seed = 32'hBEEF5A17;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_serial_adder.vcd");
            $dumpvars(0, tb_serial_adder);
        end

        // directed edge cases (8-bit)
        feed_addition(8'd0,   8'd0,   8);   // 0+0
        feed_addition(8'd255, 8'd255, 8);   // max+max -> full carry chain
        feed_addition(8'd0,   8'd255, 8);   // 0+max
        feed_addition(8'd255, 8'd1,   8);   // max+1 -> rolls to carry=1, sum=0
        feed_addition(8'd170, 8'd85,  8);   // 10101010 + 01010101 (alternating, no carry)
        feed_addition(8'd127, 8'd1,   8);   // single ripple through all bits

        // randomized, 8-bit and 16-bit operands
        for (r = 0; r < 150; r = r + 1)
            feed_addition($random(seed) & 32'hFF, $random(seed) & 32'hFF, 8);
        for (r = 0; r < 150; r = r + 1)
            feed_addition($random(seed) & 32'hFFFF, $random(seed) & 32'hFFFF, 16);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
