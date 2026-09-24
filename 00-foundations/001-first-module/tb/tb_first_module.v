`timescale 1ns / 1ps

// Testbench for first_module: applies both input values and checks
// both outputs against the expected values.
module tb_first_module;

    // Testbench-side signals: inputs of the DUT are regs (driven here),
    // outputs of the DUT are wires (driven by the DUT).
    reg  in_sig;
    wire out_sig;
    wire out_sig_n;

    integer errors = 0;
    integer checks = 0;
    integer i;

    // Device under test, connected by port name
    first_module dut (
        .in_sig   (in_sig),
        .out_sig  (out_sig),
        .out_sig_n(out_sig_n)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_first_module.vcd");
            $dumpvars(0, tb_first_module);
        end

        $display("time(ns) in_sig | out_sig out_sig_n");
        for (i = 0; i < 2; i = i + 1) begin
            in_sig = i[0];
            #10;  // let the continuous assignments settle
            $display("%8d    %b    |    %b       %b", $time, in_sig, out_sig, out_sig_n);
            checks = checks + 1;
            if (out_sig !== in_sig || out_sig_n !== ~in_sig) begin
                errors = errors + 1;
                $display("ERROR: in_sig=%b expected out_sig=%b out_sig_n=%b, got %b %b",
                         in_sig, in_sig, ~in_sig, out_sig, out_sig_n);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
