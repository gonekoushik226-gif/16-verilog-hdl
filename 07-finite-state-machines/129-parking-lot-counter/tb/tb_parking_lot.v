`timescale 1ns / 1ps

// tb_parking_lot: drives realistic two-sensor entry/exit/aborted-pass
// sequences into the INTEGRATED design and checks occupancy (against
// an independent, saturating reference counter) and `full` after each
// event. Covers filling to capacity (saturation, no overflow), draining
// to empty (no underflow), and aborted passes on both sensors that must
// leave occupancy unchanged.
module tb_parking_lot;

    localparam CAPACITY = 4, WIDTH = 3;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n;
    reg sensor_a, sensor_b;
    wire [WIDTH-1:0] occupancy;
    wire full;

    parking_lot #(.CAPACITY(CAPACITY), .WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .sensor_a(sensor_a), .sensor_b(sensor_b),
        .occupancy(occupancy), .full(full)
    );

    always #5 clk = ~clk;

    task do_reset;
        begin
            rst_n = 0; sensor_a = 0; sensor_b = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    // full clean entry: A alone -> both -> B alone (A cleared first) -> clear
    task do_entry;
        begin
            @(negedge clk); sensor_a = 1; sensor_b = 0;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 1; sensor_b = 1;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 0; sensor_b = 1;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 0; sensor_b = 0;
            @(posedge clk); #1;                    // entry_pulse visible now
            @(negedge clk); @(posedge clk); #1;     // let occupancy register update
        end
    endtask

    // full clean exit: B alone -> both -> A alone (B cleared first) -> clear
    task do_exit;
        begin
            @(negedge clk); sensor_a = 0; sensor_b = 1;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 1; sensor_b = 1;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 1; sensor_b = 0;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 0; sensor_b = 0;
            @(posedge clk); #1;
            @(negedge clk); @(posedge clk); #1;
        end
    endtask

    // aborted pass: only A triggers, then withdraws before B ever activates
    task do_abort_a;
        begin
            @(negedge clk); sensor_a = 1; sensor_b = 0;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 0; sensor_b = 0;
            @(posedge clk); #1;
        end
    endtask

    // aborted pass on the B sensor
    task do_abort_b;
        begin
            @(negedge clk); sensor_a = 0; sensor_b = 1;
            @(posedge clk); #1;
            @(negedge clk); sensor_a = 0; sensor_b = 0;
            @(posedge clk); #1;
        end
    endtask

    task check(input [WIDTH-1:0] exp_occ, input [255:0] label);
        begin
            checks = checks + 1;
            if (occupancy !== exp_occ) begin
                errors = errors + 1;
                $display("ERROR: %0s occupancy=%0d expected=%0d", label, occupancy, exp_occ);
            end
            checks = checks + 1;
            if (full !== (exp_occ >= CAPACITY[WIDTH-1:0])) begin
                errors = errors + 1;
                $display("ERROR: %0s full=%b expected=%b", label, full, (exp_occ >= CAPACITY[WIDTH-1:0]));
            end
        end
    endtask

    integer i;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_parking_lot.vcd");
            $dumpvars(0, tb_parking_lot);
        end

        do_reset;
        check(0, "reset");

        // fill to capacity, one clean entry at a time
        for (i = 1; i <= CAPACITY; i = i + 1) begin
            do_entry;
            check(i[WIDTH-1:0], "entry filling to capacity");
        end

        // one more entry while already full: saturates, no overflow
        do_entry;
        check(CAPACITY[WIDTH-1:0], "entry while already full (saturated)");

        // aborted passes on both sensors while full: no change
        do_abort_a; check(CAPACITY[WIDTH-1:0], "aborted A pass while full");
        do_abort_b; check(CAPACITY[WIDTH-1:0], "aborted B pass while full");

        // one exit clears full
        do_exit;
        check(CAPACITY[WIDTH-1:0] - 1'b1, "exit clears full");

        // aborted passes mid-occupancy: no change
        do_abort_a; check(CAPACITY[WIDTH-1:0] - 1'b1, "aborted A pass mid-occupancy");
        do_abort_b; check(CAPACITY[WIDTH-1:0] - 1'b1, "aborted B pass mid-occupancy");

        // drain fully to empty
        for (i = CAPACITY - 1; i >= 1; i = i - 1) begin
            do_exit;
            check((i - 1), "exit draining to empty");
        end

        // exit attempted while already empty: no underflow
        do_exit;
        check(0, "exit while already empty (no underflow)");

        // mixed sequence with aborts interleaved, verified against
        // occupancy staying correct throughout
        do_entry; check(1, "mixed: entry");
        do_abort_a; check(1, "mixed: abort A");
        do_entry; check(2, "mixed: entry");
        do_abort_b; check(2, "mixed: abort B");
        do_exit;  check(1, "mixed: exit");
        do_exit;  check(0, "mixed: exit");

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
