`timescale 1ns / 1ps

module tb_priority_encoder_n;

    integer errors = 0;
    integer checks = 0;
    integer i, n;
    integer seed = 1;

    // ---- N=8, MSB priority: exhaustive (256 combinations) ------------------
    localparam N8 = 8;
    reg  [N8-1:0]        dA;
    wire [$clog2(N8)-1:0] yA;
    wire                  validA;

    priority_encoder_n #(.N(N8), .MSB_PRIORITY(1)) dutA (.d(dA), .y(yA), .valid(validA));

    // ---- N=8, LSB priority: exhaustive (256 combinations) -------------------
    reg  [N8-1:0]        dB;
    wire [$clog2(N8)-1:0] yB;
    wire                  validB;

    priority_encoder_n #(.N(N8), .MSB_PRIORITY(0)) dutB (.d(dB), .y(yB), .valid(validB));

    // ---- N=16, MSB priority: random (2000 vectors) --------------------------
    localparam N16 = 16;
    reg  [N16-1:0]         dC;
    wire [$clog2(N16)-1:0] yC;
    wire                   validC;

    priority_encoder_n #(.N(N16), .MSB_PRIORITY(1)) dutC (.d(dC), .y(yC), .valid(validC));

    // ---- N=16, LSB priority: random (2000 vectors) --------------------------
    reg  [N16-1:0]         dD;
    wire [$clog2(N16)-1:0] yD;
    wire                   validD;

    priority_encoder_n #(.N(N16), .MSB_PRIORITY(0)) dutD (.d(dD), .y(yD), .valid(validD));

    task check8(input [N8-1:0] d, input msb_priority, input [$clog2(N8)-1:0] y, input valid);
        reg expected_valid;
        reg [$clog2(N8)-1:0] expected_y;
        integer k;
        begin
            expected_valid = |d;
            expected_y = {$clog2(N8){1'b0}};
            if (msb_priority) begin
                for (k = 0; k < N8; k = k + 1) if (d[k]) expected_y = k[$clog2(N8)-1:0];
            end else begin
                for (k = N8 - 1; k >= 0; k = k - 1) if (d[k]) expected_y = k[$clog2(N8)-1:0];
            end
            checks = checks + 1;
            if (valid !== expected_valid || (expected_valid && y !== expected_y)) begin
                errors = errors + 1;
                $display("ERROR: N=8 msb_pri=%0d d=%b expected valid=%b y=%0d actual valid=%b y=%0d",
                          msb_priority, d, expected_valid, expected_y, valid, y);
            end
        end
    endtask

    task check16(input [N16-1:0] d, input msb_priority, input [$clog2(N16)-1:0] y, input valid);
        reg expected_valid;
        reg [$clog2(N16)-1:0] expected_y;
        integer k;
        begin
            expected_valid = |d;
            expected_y = {$clog2(N16){1'b0}};
            if (msb_priority) begin
                for (k = 0; k < N16; k = k + 1) if (d[k]) expected_y = k[$clog2(N16)-1:0];
            end else begin
                for (k = N16 - 1; k >= 0; k = k - 1) if (d[k]) expected_y = k[$clog2(N16)-1:0];
            end
            checks = checks + 1;
            if (valid !== expected_valid || (expected_valid && y !== expected_y)) begin
                errors = errors + 1;
                $display("ERROR: N=16 msb_pri=%0d d=%h expected valid=%b y=%0d actual valid=%b y=%0d",
                          msb_priority, d, expected_valid, expected_y, valid, y);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_priority_encoder_n.vcd");
            $dumpvars(0, tb_priority_encoder_n);
        end

        // Exhaustive N=8, both priority directions: 256 combinations each
        $display("N=8 exhaustive, MSB and LSB priority (512 combinations):");
        for (i = 0; i < 256; i = i + 1) begin
            dA = i[N8-1:0];
            dB = i[N8-1:0];
            #1;
            check8(dA, 1'b1, yA, validA);
            check8(dB, 1'b0, yB, validB);
        end

        // Random N=16, both priority directions: 2000 vectors each
        $display("N=16 random, MSB and LSB priority (4000 vectors):");
        for (n = 0; n < 2000; n = n + 1) begin
            dC = {$random(seed), $random(seed)};
            dD = {$random(seed), $random(seed)};
            #1;
            check16(dC, 1'b1, yC, validC);
            check16(dD, 1'b0, yD, validD);
        end

        // Corner cases: all-zero and all-ones on the N=16 instances
        dC = {N16{1'b0}}; dD = {N16{1'b0}}; #1;
        check16(dC, 1'b1, yC, validC);
        check16(dD, 1'b0, yD, validD);
        dC = {N16{1'b1}}; dD = {N16{1'b1}}; #1;
        check16(dC, 1'b1, yC, validC);
        check16(dD, 1'b0, yD, validD);

        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
