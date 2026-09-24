`timescale 1ns / 1ps

module tb_hazard;

    reg  a, b, c;
    wire y_h, y_f;

    integer errors = 0;
    integer checks = 0;
    integer i, t;
    integer glitches_h, glitches_f;

    hazard_circuit      dut_h (.a(a), .b(b), .c(c), .y(y_h));
    hazard_free_circuit dut_f (.a(a), .b(b), .c(c), .y(y_f));

    // Samples y_h/y_f once per nanosecond, offset by 0.5ns so samples never
    // land exactly on a scheduled gate-delay boundary, and counts how many
    // samples read 0 during a window where the function must logically
    // stay 1. Any such sample is a real, delay-caused glitch.
    task sample_and_count(input integer duration_ns);
        begin
            glitches_h = 0;
            glitches_f = 0;
            #0.5;
            for (t = 0; t < duration_ns; t = t + 1) begin
                if (y_h !== 1'b1) glitches_h = glitches_h + 1;
                if (y_f !== 1'b1) glitches_f = glitches_f + 1;
                #1;
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_hazard.vcd");
            $dumpvars(0, tb_hazard);
        end

        // 1) Functional equivalence: once fully settled (past every gate
        //    delay), both circuits must equal ab + b'c for all 8 inputs —
        //    the consensus term in hazard_free_circuit must not change
        //    the truth table, only the transient behaviour.
        $display("Settled-value equivalence check (ab + b'c) for all a,b,c:");
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            #20;
            checks = checks + 2;
            $display("  a=%b b=%b c=%b | hazard=%b hazard_free=%b", a, b, c, y_h, y_f);
            if (y_h !== ((a & b) | (~b & c))) begin
                errors = errors + 1;
                $display("ERROR: hazard_circuit settled value wrong a=%b b=%b c=%b y=%b", a, b, c, y_h);
            end
            if (y_f !== ((a & b) | (~b & c))) begin
                errors = errors + 1;
                $display("ERROR: hazard_free_circuit settled value wrong a=%b b=%b c=%b y=%b", a, b, c, y_f);
            end
        end

        // 2) Hazard scenario: hold a=1, c=1 (f=1 regardless of b) and
        //    toggle b. The falling edge (b: 1->0) is the hazardous
        //    direction for this specific gate/delay arrangement, because
        //    the "ab" term switches off (3ns) before the "b'c" term
        //    switches on (2ns NOT + 3ns AND = 5ns), leaving a 2ns window
        //    where both AND terms are 0.
        a = 1; c = 1; b = 1;
        #20;

        $display("b: 1 -> 0 (hazardous direction, a=c=1)");
        b = 0;
        sample_and_count(15);
        checks = checks + 2;
        $display("  hazard_circuit glitch samples      = %0d", glitches_h);
        $display("  hazard_free_circuit glitch samples = %0d", glitches_f);
        if (glitches_h == 0) begin
            errors = errors + 1;
            $display("ERROR: expected hazard_circuit to glitch on b:1->0 with a=c=1, none observed");
        end
        if (glitches_f != 0) begin
            errors = errors + 1;
            $display("ERROR: hazard_free_circuit glitched %0d times on b:1->0 (expected hazard-free)", glitches_f);
        end

        #20;   // let both circuits fully settle back to y=1

        $display("b: 0 -> 1 (non-hazardous direction for this circuit, a=c=1)");
        b = 1;
        sample_and_count(15);
        checks = checks + 1;
        $display("  hazard_circuit glitch samples      = %0d", glitches_h);
        $display("  hazard_free_circuit glitch samples = %0d", glitches_f);
        if (glitches_f != 0) begin
            errors = errors + 1;
            $display("ERROR: hazard_free_circuit glitched %0d times on b:0->1 (expected hazard-free)", glitches_f);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
