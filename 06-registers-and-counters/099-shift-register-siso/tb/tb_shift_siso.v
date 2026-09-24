`timescale 1ns / 1ps

// tb_shift_siso: pushes a distinct known bit stream in and checks each
// bit reappears on serial_out exactly WIDTH cycles later, using a
// software queue as the reference delay line.
module tb_shift_siso;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, serial_in;
    wire serial_out;

    reg queue [0:63];

    shift_siso #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .serial_in(serial_in), .serial_out(serial_out));

    always #5 clk = ~clk;

    // check(cyc) runs after the (cyc+1)-th clock edge past reset release
    // (loop iteration cyc pushes serial_in, then waits one edge before
    // calling check(cyc)); a WIDTH-bit shift register's serial_out after
    // edge k equals the bit pushed before edge (k-WIDTH+1), i.e.
    // queue[cyc-WIDTH+1] here (same indexing derivation as program 096).
    task check(input integer cyc);
        integer idx;
        begin
            idx = cyc - WIDTH + 1;
            if (idx >= 0) begin
                checks = checks + 1;
                if (serial_out !== queue[idx]) begin
                    errors = errors + 1;
                    $display("ERROR: cycle=%0d expected serial_out=%b actual=%b",
                              cyc, queue[idx], serial_out);
                end
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_shift_siso.vcd");
            $dumpvars(0, tb_shift_siso);
        end

        rst_n = 0; serial_in = 0;
        @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 40; i = i + 1) begin
            serial_in = $random;
            queue[i] = serial_in;
            @(posedge clk); #1;
            check(i);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
