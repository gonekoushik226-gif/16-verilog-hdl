`timescale 1ns / 1ps

module tb_delay_models;

    reg  in_sig;
    wire inertial_out;
    wire transport_out;

    integer errors = 0;
    integer checks = 0;
    reg     nb_demo;

    delay_models dut (.in_sig(in_sig), .inertial_out(inertial_out), .transport_out(transport_out));

    // Check both outputs at an absolute simulation time
    task check_at(input integer t, input exp_inertial, input exp_transport);
        begin
            #(t - $time);
            checks = checks + 1;
            if (inertial_out !== exp_inertial || transport_out !== exp_transport) begin
                errors = errors + 1;
                $display("ERROR: t=%0t inertial=%b (exp %b) transport=%b (exp %b)",
                         $time, inertial_out, exp_inertial, transport_out, exp_transport);
            end
        end
    endtask

    // Stimulus: a 10 ns pulse at t=10 and a 2 ns pulse at t=30
    initial begin
        in_sig = 1'b0;
        #10 in_sig = 1'b1;
        #10 in_sig = 1'b0;
        #10 in_sig = 1'b1;
        #2  in_sig = 1'b0;
    end

    // $monitor prints whenever any listed signal changes (at most once per time step)
    initial begin
        $timeformat(-9, 0, " ns", 6);
        $monitor("%t  in_sig=%b inertial_out=%b transport_out=%b",
                 $time, in_sig, inertial_out, transport_out);
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_delay_models.vcd");
            $dumpvars(0, tb_delay_models);
        end
        check_at(1,  1'bx, 1'bx);   // nothing has propagated yet
        check_at(6,  1'b0, 1'b0);   // initial 0 arrives after 5 ns
        check_at(14, 1'b0, 1'b0);   // rising edge at 10 not yet visible
        check_at(16, 1'b1, 1'b1);   // ... visible at 15
        check_at(24, 1'b1, 1'b1);
        check_at(26, 1'b0, 1'b0);   // falling edge at 20 visible at 25
        check_at(34, 1'b0, 1'b0);
        check_at(36, 1'b0, 1'b1);   // 2 ns pulse: filtered by inertial, kept by transport
        check_at(38, 1'b0, 1'b0);   // transport pulse ended at 37
        $monitoroff;

        // $display vs $strobe: $display runs immediately, $strobe at the end of
        // the time step, after non-blocking assignments have updated.
        nb_demo = 1'b0;
        #1;
        nb_demo <= 1'b1;
        $display("$display sees nb_demo=%b (old value)", nb_demo);
        $strobe ("$strobe  sees nb_demo=%b (new value)", nb_demo);
        #1;
        checks = checks + 1;
        if (nb_demo !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR: non-blocking update did not happen");
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
