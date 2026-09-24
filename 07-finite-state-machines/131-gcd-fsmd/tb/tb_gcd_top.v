`timescale 1ns / 1ps

// tb_gcd_top: computes GCD via random and directed pairs, checking the
// FSMD's `result` against an independent reference model implementing
// the standard MOD-based Euclidean algorithm (deliberately different
// from the RTL's SUBTRACTION-based method, so the two do not share a
// bug). Directed cases specifically cover zero operands, equal
// operands, and a worst-case Fibonacci pair for the subtraction method.
module tb_gcd_top;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n, start;
    reg [WIDTH-1:0] a_in, b_in;
    wire done, busy;
    wire [WIDTH-1:0] result;

    gcd_top #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_in(a_in), .b_in(b_in), .done(done), .busy(busy), .result(result)
    );

    always #5 clk = ~clk;

    // independent reference model: mod-based Euclidean algorithm
    function integer gcd_ref(input integer x, input integer y);
        integer t;
        begin
            while (y != 0) begin
                t = y;
                y = x % y;
                x = t;
            end
            gcd_ref = x;
        end
    endfunction

    task do_reset;
        begin
            rst_n = 0; start = 0; a_in = 0; b_in = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    task run_gcd(input [WIDTH-1:0] a, input [WIDTH-1:0] b);
        integer watchdog;
        integer expected;
        reg timed_out;
        begin
            expected = gcd_ref(a, b);
            @(negedge clk); start = 1'b1; a_in = a; b_in = b;
            @(posedge clk); #1; start = 1'b0;
            watchdog = 0; timed_out = 0;
            while (!done && !timed_out) begin
                @(posedge clk); #1;
                watchdog = watchdog + 1;
                if (watchdog > 1000) begin
                    errors = errors + 1;
                    $display("ERROR: TEST FAILED: timeout computing gcd(%0d,%0d)", a, b);
                    timed_out = 1;
                end
            end
            checks = checks + 1;
            if (!timed_out && result !== expected[WIDTH-1:0]) begin
                errors = errors + 1;
                $display("ERROR: gcd(%0d,%0d)=%0d expected=%0d", a, b, result, expected);
            end
        end
    endtask

    integer i;
    integer seed = 32'hA5A5F00D;
    integer ra, rb;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_gcd_top.vcd");
            $dumpvars(0, tb_gcd_top);
        end

        do_reset;

        // directed edge cases
        run_gcd(8'd0, 8'd0);       // gcd(0,0) = 0
        run_gcd(8'd0, 8'd17);      // gcd(0,b) = b
        run_gcd(8'd17, 8'd0);      // gcd(a,0) = a
        run_gcd(8'd7, 8'd7);       // equal operands
        run_gcd(8'd1, 8'd1);
        run_gcd(8'd48, 8'd18);     // gcd = 6
        run_gcd(8'd17, 8'd5);      // coprime, gcd = 1
        run_gcd(8'd100, 8'd75);    // gcd = 25
        run_gcd(8'd144, 8'd89);    // Fibonacci pair: subtraction method's worst case

        // back-to-back computations with no reset between them
        run_gcd(8'd60, 8'd48);
        run_gcd(8'd21, 8'd14);

        // randomized pairs (values 1..150, bounded so the subtraction
        // method's iteration count stays reasonable for simulation)
        for (i = 0; i < 80; i = i + 1) begin
            seed = seed * 1103515245 + 12345;
            ra = (seed[30:23] % 150) + 1;
            seed = seed * 1103515245 + 12345;
            rb = (seed[30:23] % 150) + 1;
            run_gcd(ra[7:0], rb[7:0]);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
