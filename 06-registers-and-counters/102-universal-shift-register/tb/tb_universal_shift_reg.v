`timescale 1ns / 1ps

// tb_universal_shift_reg: exercises every mode -- load, hold,
// shift-right (checking serial_in_right enters the MSB and the old LSB
// exits), and shift-left (mirror image) -- against a plain reference
// model of the same behavior.
module tb_universal_shift_reg;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n;
    reg [1:0] mode;
    reg sin_l, sin_r;
    reg [WIDTH-1:0] pin;
    wire [WIDTH-1:0] q;

    reg [WIDTH-1:0] ref_q;

    universal_shift_reg #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .mode(mode),
        .serial_in_left(sin_l), .serial_in_right(sin_r),
        .parallel_in(pin), .q(q)
    );

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (q !== ref_q) begin
                errors = errors + 1;
                $display("ERROR: time=%0t mode=%b expected q=%h actual q=%h", $time, mode, ref_q, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_universal_shift_reg.vcd");
            $dumpvars(0, tb_universal_shift_reg);
        end

        rst_n = 0; mode = 2'b00; sin_l = 0; sin_r = 0; pin = 0; ref_q = 0;
        @(negedge clk); check;
        rst_n = 1;

        // load
        mode = 2'b11; pin = 8'hA5; ref_q = 8'hA5;
        @(posedge clk); #1; check;

        // hold
        mode = 2'b00; pin = 8'hFF;
        @(posedge clk); #1; check;
        @(posedge clk); #1; check;

        // shift right several times, tracking expected value by hand
        mode = 2'b01;
        for (i = 0; i < 8; i = i + 1) begin
            sin_r = i[0];
            ref_q = {sin_r, ref_q[WIDTH-1:1]};
            @(posedge clk); #1; check;
        end

        // load again, then shift left several times
        mode = 2'b11; pin = 8'h3C; ref_q = 8'h3C;
        @(posedge clk); #1; check;

        mode = 2'b10;
        for (i = 0; i < 8; i = i + 1) begin
            sin_l = i[0];
            ref_q = {ref_q[WIDTH-2:0], sin_l};
            @(posedge clk); #1; check;
        end

        // random mode sequence for broader confidence
        for (i = 0; i < 20; i = i + 1) begin
            mode = $random % 4;
            sin_l = $random; sin_r = $random; pin = $random;
            case (mode)
                2'b00: ref_q = ref_q;
                2'b01: ref_q = {sin_r, ref_q[WIDTH-1:1]};
                2'b10: ref_q = {ref_q[WIDTH-2:0], sin_l};
                2'b11: ref_q = pin;
            endcase
            @(posedge clk); #1; check;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
