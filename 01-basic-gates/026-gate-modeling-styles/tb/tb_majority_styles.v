`timescale 1ns / 1ps

// tb_majority_styles: exhaustively drives all three modeling styles of the
// 3-input majority function with the same stimulus and checks each one
// independently against a reference value, and against each other.
module tb_majority_styles;

    reg  a, b, c;
    wire y_gate, y_dataflow, y_behavioral;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg      expected;

    majority_gate_level  dut_gate       (.a(a), .b(b), .c(c), .y(y_gate));
    majority_dataflow    dut_dataflow   (.a(a), .b(b), .c(c), .y(y_dataflow));
    majority_behavioral  dut_behavioral (.a(a), .b(b), .c(c), .y(y_behavioral));

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_majority_styles.vcd");
            $dumpvars(0, tb_majority_styles);
        end

        $display(" a b c | gate dataflow behavioral");
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            #1;
            // Reference model: majority is 1 iff at least 2 of the 3 bits are 1
            expected = (a & b) | (b & c) | (a & c);

            checks = checks + 1;
            $display("  %b %b %b  |   %b       %b        %b",
                      a, b, c, y_gate, y_dataflow, y_behavioral);

            if (y_gate !== expected) begin
                errors = errors + 1;
                $display("ERROR: gate_level t=%0t a=%b b=%b c=%b expected=%b actual=%b",
                          $time, a, b, c, expected, y_gate);
            end
            if (y_dataflow !== expected) begin
                errors = errors + 1;
                $display("ERROR: dataflow t=%0t a=%b b=%b c=%b expected=%b actual=%b",
                          $time, a, b, c, expected, y_dataflow);
            end
            if (y_behavioral !== expected) begin
                errors = errors + 1;
                $display("ERROR: behavioral t=%0t a=%b b=%b c=%b expected=%b actual=%b",
                          $time, a, b, c, expected, y_behavioral);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
