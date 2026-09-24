`timescale 1ns / 1ps

// tb_pipeline3: pushes a distinct known value in on every cycle and
// checks it reappears at the output exactly 3 cycles later with
// out_valid correctly tracking in_valid through that same latency,
// using a software queue as the reference model. Also checks data
// integrity is maintained continuously (a new input every cycle, not
// just isolated single-shot transfers).
module tb_pipeline3;

    localparam WIDTH = 8;
    localparam LATENCY = 3;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, in_valid;
    reg [WIDTH-1:0] in_data;
    wire out_valid;
    wire [WIDTH-1:0] out_data;

    reg [WIDTH-1:0] data_q   [0:63];
    reg             valid_q  [0:63];

    pipeline3 #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
        .out_valid(out_valid), .out_data(out_data)
    );

    always #5 clk = ~clk;

    // check(cyc) runs right after the (cyc+1)-th clock edge past reset
    // release (loop iteration cyc pushes its input, then waits for one
    // edge before calling check(cyc)); a 3-stage pipeline's out_data
    // after edge k equals the input pushed before edge (k-2), i.e.
    // data_q[cyc-LATENCY+1] here.
    task check(input integer cyc);
        integer idx;
        begin
            idx = cyc - LATENCY + 1;
            if (idx >= 0) begin
                checks = checks + 1;
                if (out_valid !== valid_q[idx]
                    || (valid_q[idx] && out_data !== data_q[idx])) begin
                    errors = errors + 1;
                    $display("ERROR: cycle=%0d expected valid=%b data=%0d actual valid=%b data=%0d",
                              cyc, valid_q[idx], data_q[idx], out_valid, out_data);
                end
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_pipeline3.vcd");
            $dumpvars(0, tb_pipeline3);
        end

        rst_n = 0; in_valid = 0; in_data = 0;
        @(negedge clk);
        rst_n = 1;

        // continuous back-to-back transfers, latency measurement
        for (i = 0; i < 20; i = i + 1) begin
            in_valid = 1;
            in_data  = i[WIDTH-1:0];
            data_q[i]  = in_data;
            valid_q[i] = 1'b1;
            @(posedge clk); #1;
            check(i);
        end

        // a gap: in_valid drops for a few cycles, must ripple through
        // as out_valid=0 exactly LATENCY cycles later
        for (i = 20; i < 24; i = i + 1) begin
            in_valid = 0;
            valid_q[i] = 1'b0;
            @(posedge clk); #1;
            check(i);
        end

        // resume
        for (i = 24; i < 30; i = i + 1) begin
            in_valid = 1;
            in_data  = i[WIDTH-1:0];
            data_q[i]  = in_data;
            valid_q[i] = 1'b1;
            @(posedge clk); #1;
            check(i);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
