`timescale 1ns / 1ps

// tb_bcd_to_excess3: checks all 16 possible 4-bit inputs, both the 10
// valid BCD digits and the 6 invalid codes.
module tb_bcd_to_excess3;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  [3:0] bcd;
    wire [3:0] excess3;
    wire       invalid;

    bcd_to_excess3 dut (.bcd(bcd), .excess3(excess3), .invalid(invalid));

    task check(input [3:0] b);
        reg [3:0] exp_e3;
        reg       exp_invalid;
        begin
            bcd = b;
            #1;
            exp_invalid = (b > 4'd9);
            exp_e3 = exp_invalid ? 4'd0 : (b + 4'd3);
            checks = checks + 1;
            if (excess3 !== exp_e3 || invalid !== exp_invalid) begin
                errors = errors + 1;
                $display("ERROR: bcd=%0d expected excess3=%0d invalid=%b actual excess3=%0d invalid=%b",
                          b, exp_e3, exp_invalid, excess3, invalid);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bcd_to_excess3.vcd");
            $dumpvars(0, tb_bcd_to_excess3);
        end

        $display("all 16 possible 4-bit inputs (10 valid BCD + 6 invalid):");
        for (i = 0; i < 16; i = i + 1)
            check(i[3:0]);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
