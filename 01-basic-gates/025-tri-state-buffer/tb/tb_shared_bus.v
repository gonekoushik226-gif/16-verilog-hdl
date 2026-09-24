`timescale 1ns / 1ps

module tb_shared_bus;

    reg  data_a, enable_a, data_b, enable_b;
    wire bus;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg      expected;

    shared_bus dut (
        .data_a(data_a), .enable_a(enable_a),
        .data_b(data_b), .enable_b(enable_b),
        .bus(bus)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_shared_bus.vcd");
            $dumpvars(0, tb_shared_bus);
        end

        $display(" en_a da | en_b db | bus");
        // Exhaustive over the 4 control/data inputs (16 combinations)
        for (i = 0; i < 16; i = i + 1) begin
            {enable_a, data_a, enable_b, data_b} = i[3:0];
            #1;

            if (!enable_a && !enable_b)
                expected = 1'bz;                       // no driver: floating bus
            else if (enable_a && !enable_b)
                expected = data_a;                      // A is the sole driver
            else if (!enable_a && enable_b)
                expected = data_b;                      // B is the sole driver
            else if (data_a == data_b)
                expected = data_a;                      // both drive, but agree
            else
                expected = 1'bx;                        // real contention

            checks = checks + 1;
            $display("  %b   %b  |  %b   %b  |  %b",
                      enable_a, data_a, enable_b, data_b, bus);
            if (bus !== expected) begin
                errors = errors + 1;
                $display("ERROR: t=%0t en_a=%b da=%b en_b=%b db=%b expected=%b actual=%b",
                          $time, enable_a, data_a, enable_b, data_b, expected, bus);
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
