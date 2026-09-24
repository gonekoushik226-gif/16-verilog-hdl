`timescale 1ns / 1ps

module tb_blocking_vs_nonblocking;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    reg  din = 1'b0;
    wire nb_q1, nb_q2, nb_q3;
    wire bl_q1, bl_q2, bl_q3;

    integer errors = 0;
    integer checks = 0;
    integer cycle;
    reg [2:0] history;          // din of the last three rising edges, [0] newest
    reg [15:0] pattern = 16'b1011_0010_0111_0001;

    shift_nonblocking u_nb (.clk(clk), .rst_n(rst_n), .din(din), .q1(nb_q1), .q2(nb_q2), .q3(nb_q3));
    shift_blocking    u_bl (.clk(clk), .rst_n(rst_n), .din(din), .q1(bl_q1), .q2(bl_q2), .q3(bl_q3));

    always #5 clk = ~clk;

    // Record what each rising edge sampled
    always @(posedge clk)
        if (rst_n) history <= {history[1:0], din};

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_blocking_vs_nonblocking.vcd");
            $dumpvars(0, tb_blocking_vs_nonblocking);
        end
        history = 3'b000;
        #12 rst_n = 1'b1;

        $display("cycle din | nonblocking q1 q2 q3 | blocking q1 q2 q3");
        @(negedge clk);
        for (cycle = 0; cycle < 16; cycle = cycle + 1) begin
            din = pattern[15 - cycle];   // drive on the falling edge, away from the active edge
            @(negedge clk);              // exactly one rising edge has sampled din
            $display("  %2d   %b  |           %b  %b  %b  |         %b  %b  %b",
                     cycle, din, nb_q1, nb_q2, nb_q3, bl_q1, bl_q2, bl_q3);
            checks = checks + 2;
            // Correct shift register: stage k holds the input from k edges ago
            if ({nb_q3, nb_q2, nb_q1} !== history) begin
                errors = errors + 1;
                $display("ERROR: nonblocking stages %b%b%b expected %b", nb_q3, nb_q2, nb_q1, history);
            end
            // Blocking version: every stage equals the newest input
            if ({bl_q3, bl_q2, bl_q1} !== {3{history[0]}}) begin
                errors = errors + 1;
                $display("ERROR: blocking stages %b%b%b expected %b", bl_q3, bl_q2, bl_q1, {3{history[0]}});
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #5000 $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
