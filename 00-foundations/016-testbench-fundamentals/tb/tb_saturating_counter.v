`timescale 1ns / 1ps

// Template testbench showing the standard structure used in this repository:
//   1. parameters and signal declarations
//   2. DUT instantiation
//   3. clock generation
//   4. reference model
//   5. checker
//   6. stimulus (directed, then seeded random)
//   7. watchdog and summary
module tb_saturating_counter;

    // ---- 1. parameters and signals ----------------------------------------
    localparam WIDTH      = 4;
    localparam CLK_PERIOD = 10;                 // ns
    localparam MAX        = (1 << WIDTH) - 1;

    reg              clk = 1'b0;
    reg              rst_n = 1'b1;
    reg              clear = 1'b0;
    reg              en = 1'b0;
    reg              up = 1'b1;
    wire [WIDTH-1:0] count;
    wire             at_max, at_min;

    integer errors = 0;
    integer checks = 0;
    integer seed   = 1;
    integer model;          // reference model state
    integer cycle;
    integer hits_max = 0, hits_min = 0;

    // ---- 2. DUT ------------------------------------------------------------
    saturating_counter #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .up(up),
        .count(count), .at_max(at_max), .at_min(at_min)
    );

    // ---- 3. clock ----------------------------------------------------------
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---- 4. reference model: updated on the same edge as the DUT ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          model <= 0;
        else if (clear)      model <= 0;
        else if (en && up)   model <= (model == MAX) ? MAX : model + 1;
        else if (en && !up)  model <= (model == 0) ? 0 : model - 1;
    end

    // ---- 5. checker: compare on the falling edge, when everything is stable
    always @(negedge clk) begin
        if (rst_n) begin
            checks = checks + 1;
            if (count !== model || at_max !== (model == MAX) || at_min !== (model == 0)) begin
                errors = errors + 1;
                $display("ERROR: %t count=%0d expected %0d at_max=%b at_min=%b",
                         $time, count, model, at_max, at_min);
            end
            if (at_max) hits_max = hits_max + 1;
            if (at_min) hits_min = hits_min + 1;
        end
    end

    // ---- 6. stimulus -------------------------------------------------------
    task reset_dut;
        begin
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk) rst_n = 1'b1;
        end
    endtask

    // drive inputs for n cycles (inputs change on the falling edge)
    task drive(input c, input e, input u, input integer n);
        begin
            repeat (n) begin
                @(negedge clk);
                clear = c; en = e; up = u;
            end
        end
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 8);
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_saturating_counter.vcd");
            $dumpvars(0, tb_saturating_counter);
        end
        if ($value$plusargs("seed=%d", seed))
            $display("using seed %0d from the command line", seed);

        reset_dut;
        $display("directed: count up past MAX, down past 0, clear, hold");
        drive(0, 1, 1, MAX + 5);   // saturate at the top
        $display("  after counting up:   count=%0d at_max=%b", count, at_max);
        drive(0, 0, 0, 3);         // hold
        drive(0, 1, 0, MAX + 5);   // saturate at the bottom
        $display("  after counting down: count=%0d at_min=%b", count, at_min);
        drive(0, 1, 1, 6);
        drive(1, 1, 1, 1);         // clear has priority over enable
        drive(0, 0, 1, 2);
        $display("  after clear:         count=%0d", count);

        $display("random: 2000 cycles with seed %0d", seed);
        for (cycle = 0; cycle < 2000; cycle = cycle + 1) begin
            @(negedge clk);
            clear = (($random(seed) & 63) == 0);      // rare clears
            en    = (($random(seed) & 3) != 0);       // 75 % enabled
            up    = ((cycle / 64) % 2 == 0) ? (($random(seed) & 7) != 0)   // mostly up
                                            : (($random(seed) & 7) == 0);  // mostly down
        end

        // asynchronous reset in the middle of a cycle
        @(negedge clk);
        #2 rst_n = 1'b0;
        #1;
        checks = checks + 1;
        if (count !== 0) begin
            errors = errors + 1;
            $display("ERROR: asynchronous reset did not clear count");
        end
        @(negedge clk) rst_n = 1'b1;
        drive(0, 0, 1, 2);

        $display("cycles at MAX: %0d, cycles at 0: %0d (both boundaries exercised)", hits_max, hits_min);
        if (hits_max == 0 || hits_min == 0) begin
            errors = errors + 1;
            $display("ERROR: random stimulus did not reach both boundaries");
        end

        // ---- 7. summary ----------------------------------------------------
        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 5000);
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
