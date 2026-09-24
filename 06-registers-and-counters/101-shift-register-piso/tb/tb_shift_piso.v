`timescale 1ns / 1ps

// tb_shift_piso: loads a known byte, then shifts it out and checks each
// bit appears MSB-first, for several bytes including all-zero/all-one
// corners and random values.
module tb_shift_piso;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer trial, b;

    reg clk = 0;
    reg rst_n, load, shift_en;
    reg [WIDTH-1:0] parallel_in;
    wire serial_out;

    reg [WIDTH-1:0] byte_val;

    shift_piso #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .load(load), .shift_en(shift_en),
                                      .parallel_in(parallel_in), .serial_out(serial_out));

    always #5 clk = ~clk;

    task load_and_check(input [WIDTH-1:0] byte_in);
        begin
            load = 1; shift_en = 0; parallel_in = byte_in;
            @(posedge clk); #1;
            load = 0; shift_en = 1;
            for (b = WIDTH-1; b >= 0; b = b - 1) begin
                checks = checks + 1;
                if (serial_out !== byte_in[b]) begin
                    errors = errors + 1;
                    $display("ERROR: byte=%h bit_index=%0d expected serial_out=%b actual=%b",
                              byte_in, b, byte_in[b], serial_out);
                end
                @(posedge clk); #1;
            end
            shift_en = 0;
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_shift_piso.vcd");
            $dumpvars(0, tb_shift_piso);
        end

        rst_n = 0; load = 0; shift_en = 0; parallel_in = 0;
        @(negedge clk);
        rst_n = 1;

        load_and_check(8'hA5);
        load_and_check(8'h00);
        load_and_check(8'hFF);
        load_and_check(8'h81);

        for (trial = 0; trial < 10; trial = trial + 1) begin
            byte_val = $random;
            load_and_check(byte_val);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
