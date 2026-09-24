`timescale 1ns / 1ps

// tb_fxp_unit: Q3.4 (WIDTH=8, FRAC=4) fixed-point add and multiply,
// checked against the true mathematical result (computed in real
// arithmetic, which is exact here since every Q3.4 code is a multiple
// of 1/16 — a power-of-two fraction with no double-precision rounding
// error) after applying this design's documented round-half-up and
// saturation rules. 2000 random operand pairs per operation, plus
// directed cases that specifically drive the result past the
// representable range in both directions.
module tb_fxp_unit;

    localparam WIDTH = 8;
    localparam FRAC  = 4;
    localparam real  SCALE = 16.0;      // 2^FRAC
    localparam signed [WIDTH-1:0] MAXV = 8'sd127;
    localparam signed [WIDTH-1:0] MINV = -8'sd128;

    integer errors = 0;
    integer checks = 0;
    integer r;

    reg  signed [WIDTH-1:0] a, b;
    reg                      op;
    wire signed [WIDTH-1:0] result;
    wire                     overflow;

    fxp_unit #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
        .a(a), .b(b), .op(op), .result(result), .overflow(overflow)
    );

    task check;
        real real_a, real_b, ideal;
        real scaled_ideal;
        integer rounded;
        reg signed [WIDTH-1:0] expected;
        reg expected_overflow;
        begin
            #1;
            checks = checks + 1;
            real_a = $itor(a) / SCALE;
            real_b = $itor(b) / SCALE;
            ideal  = op ? (real_a * real_b) : (real_a + real_b);
            scaled_ideal = ideal * SCALE;   // = a+b for add, exact; a*b/16 for mul

            if (!op) begin
                // addition: a+b is already an exact integer (no rounding step)
                rounded = a + b;
            end else begin
                // multiply: round-half-up to the nearest integer raw code,
                // i.e. floor(scaled_ideal + 0.5) -- ties round toward +inf
                // for *both* signs (e.g. -2.5 rounds to -2, not -3). Since
                // scaled_ideal = (a*b)/16 is always an exact multiple of
                // 1/16, this floor is computed exactly via integer bias +
                // arithmetic shift rather than real-number $rtoi (which
                // truncates toward zero and would mis-round negative
                // values -- this is exactly the bug an earlier version of
                // this testbench had, using round-half-away-from-zero
                // instead of the design's documented round-half-up rule).
                rounded = (a * b + (1 <<< (FRAC-1))) >>> FRAC;
            end

            if (rounded > $signed({{24{1'b0}}, MAXV})) begin
                expected = MAXV; expected_overflow = 1'b1;
            end else if (rounded < $signed({{24{MINV[WIDTH-1]}}, MINV})) begin
                expected = MINV; expected_overflow = 1'b1;
            end else begin
                expected = rounded[WIDTH-1:0]; expected_overflow = 1'b0;
            end

            if (result !== expected || overflow !== expected_overflow) begin
                errors = errors + 1;
                $display("ERROR: op=%b a=%0d(%.4f) b=%0d(%.4f) expected result=%0d ovf=%b actual result=%0d ovf=%b",
                          op, a, real_a, b, real_b, expected, expected_overflow, result, overflow);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_fxp_unit.vcd");
            $dumpvars(0, tb_fxp_unit);
        end

        // random, both operations
        for (r = 0; r < 2000; r = r + 1) begin
            a = $random; b = $random; op = 1'b0; check;
        end
        for (r = 0; r < 2000; r = r + 1) begin
            a = $random; b = $random; op = 1'b1; check;
        end

        // directed overflow corners: add
        a = 8'sd100; b = 8'sd100; op = 1'b0; check;    // positive overflow
        a = -8'sd100; b = -8'sd100; op = 1'b0; check;  // negative overflow
        a = MAXV; b = 8'sd1; op = 1'b0; check;          // just past MAXV
        a = MINV; b = -8'sd1; op = 1'b0; check;         // just past MINV
        a = MAXV; b = 8'sd0; op = 1'b0; check;          // exactly at MAXV, no overflow
        a = MINV; b = 8'sd0; op = 1'b0; check;          // exactly at MINV, no overflow

        // directed overflow corners: multiply
        a = 8'sd100; b = 8'sd100; op = 1'b1; check;    // 6.25*6.25=39.0625 -> overflow
        a = MINV; b = MINV; op = 1'b1; check;           // (-8.0)*(-8.0)=64.0 -> overflow
        a = 8'sd16; b = 8'sd16; op = 1'b1; check;       // 1.0*1.0=1.0, no overflow
        a = 8'sd0; b = MINV; op = 1'b1; check;          // 0 * anything = 0

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
