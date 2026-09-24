`timescale 1ns / 1ps

module tb_wire_assign_demo;

    reg  [2:0] in_bits;
    wire       majority;
    wire       parity;
    wire [2:0] reversed;
    wire [3:0] zero_ext;

    integer errors = 0;
    integer checks = 0;
    integer i;
    integer ones;

    reg       exp_majority;
    reg       exp_parity;
    reg [2:0] exp_reversed;
    reg [3:0] exp_zero_ext;

    wire_assign_demo dut (
        .in_bits (in_bits),
        .majority(majority),
        .parity  (parity),
        .reversed(reversed),
        .zero_ext(zero_ext)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_wire_assign_demo.vcd");
            $dumpvars(0, tb_wire_assign_demo);
        end

        $display("in_bits | majority parity reversed zero_ext");
        for (i = 0; i < 8; i = i + 1) begin
            in_bits = i[2:0];
            #10;
            // Reference model computed arithmetically, independent of the RTL
            ones         = i[0] + i[1] + i[2];
            exp_majority = (ones >= 2);
            exp_parity   = (ones % 2 == 1);
            exp_reversed = {i[0], i[1], i[2]};
            exp_zero_ext = i;
            $display("  %b   |    %b        %b      %b      %b",
                     in_bits, majority, parity, reversed, zero_ext);
            checks = checks + 1;
            if (majority !== exp_majority || parity !== exp_parity ||
                reversed !== exp_reversed || zero_ext !== exp_zero_ext) begin
                errors = errors + 1;
                $display("ERROR: in_bits=%b expected %b %b %b %b got %b %b %b %b",
                         in_bits, exp_majority, exp_parity, exp_reversed, exp_zero_ext,
                         majority, parity, reversed, zero_ext);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
