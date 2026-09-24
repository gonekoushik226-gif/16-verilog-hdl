`timescale 1ns / 1ps

// tb_boolean_function: checks func_sop, func_pos and func_minimized
// against an independently hard-coded truth table (not against each
// other's equations), so the check does not just repeat the same algebra
// three times.
module tb_boolean_function;

    reg  a, b, c;
    wire y_sop, y_pos, y_min;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg      expected;

    func_sop       dut_sop (.a(a), .b(b), .c(c), .y(y_sop));
    func_pos       dut_pos (.a(a), .b(b), .c(c), .y(y_pos));
    func_minimized dut_min (.a(a), .b(b), .c(c), .y(y_min));

    // Independent reference: the truth table itself, indexed by {a,b,c}.
    function reference_f;
        input [2:0] abc;
        begin
            case (abc)
                3'b000: reference_f = 1'b1;   // m0
                3'b001: reference_f = 1'b0;
                3'b010: reference_f = 1'b1;   // m2
                3'b011: reference_f = 1'b0;
                3'b100: reference_f = 1'b0;
                3'b101: reference_f = 1'b1;   // m5
                3'b110: reference_f = 1'b0;
                3'b111: reference_f = 1'b1;   // m7
                default: reference_f = 1'bx;
            endcase
        end
    endfunction

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_boolean_function.vcd");
            $dumpvars(0, tb_boolean_function);
        end

        $display(" a b c | SOP POS MIN | truth-table");
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            #1;
            expected = reference_f({a, b, c});
            $display("  %b %b %b  |  %b   %b   %b   |     %b", a, b, c, y_sop, y_pos, y_min, expected);

            checks = checks + 3;
            if (y_sop !== expected) begin
                errors = errors + 1;
                $display("ERROR: SOP a=%b b=%b c=%b expected=%b actual=%b", a, b, c, expected, y_sop);
            end
            if (y_pos !== expected) begin
                errors = errors + 1;
                $display("ERROR: POS a=%b b=%b c=%b expected=%b actual=%b", a, b, c, expected, y_pos);
            end
            if (y_min !== expected) begin
                errors = errors + 1;
                $display("ERROR: MIN a=%b b=%b c=%b expected=%b actual=%b", a, b, c, expected, y_min);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
