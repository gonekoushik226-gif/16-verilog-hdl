`timescale 1ns / 1ps

// tb_shift_sipo: shifts in a known WIDTH-bit byte, bit by bit, in both
// msb_first and lsb_first modes, checking the assembled parallel_out
// after WIDTH cycles matches the expected byte, then repeats with 10
// random bytes per mode.
module tb_shift_sipo;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer trial, b;

    reg clk = 0;
    reg rst_n, serial_in, msb_first;
    wire [WIDTH-1:0] parallel_out;

    reg [WIDTH-1:0] byte_val;

    shift_sipo #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .serial_in(serial_in),
                                      .msb_first(msb_first), .parallel_out(parallel_out));

    always #5 clk = ~clk;

    task load_and_check(input [WIDTH-1:0] byte_in, input msbf);
        begin
            rst_n = 0; @(negedge clk); rst_n = 1;
            msb_first = msbf;
            if (msbf) begin
                // feed MSB first: byte_in[WIDTH-1] down to byte_in[0]
                for (b = WIDTH-1; b >= 0; b = b - 1) begin
                    serial_in = byte_in[b];
                    @(posedge clk); #1;
                end
            end else begin
                // feed LSB first: byte_in[0] up to byte_in[WIDTH-1]
                for (b = 0; b < WIDTH; b = b + 1) begin
                    serial_in = byte_in[b];
                    @(posedge clk); #1;
                end
            end
            checks = checks + 1;
            if (parallel_out !== byte_in) begin
                errors = errors + 1;
                $display("ERROR: msb_first=%b expected parallel_out=%h actual=%h", msbf, byte_in, parallel_out);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_shift_sipo.vcd");
            $dumpvars(0, tb_shift_sipo);
        end

        load_and_check(8'hA5, 1'b1);
        load_and_check(8'h3C, 1'b0);
        load_and_check(8'h00, 1'b1);
        load_and_check(8'hFF, 1'b0);

        for (trial = 0; trial < 10; trial = trial + 1) begin
            byte_val = $random;
            load_and_check(byte_val, 1'b1);
        end
        for (trial = 0; trial < 10; trial = trial + 1) begin
            byte_val = $random;
            load_and_check(byte_val, 1'b0);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
