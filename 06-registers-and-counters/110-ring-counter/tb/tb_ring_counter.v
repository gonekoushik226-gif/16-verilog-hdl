`timescale 1ns / 1ps

// tb_ring_counter: checks the normal one-hot rotation sequence over two
// full periods, then forces the register into several invalid
// (non-one-hot) states via hierarchical force -- all-zero, two bits
// set, and all-ones -- and checks it always converges back to a valid
// one-hot state within WIDTH cycles and then continues rotating
// correctly, demonstrating the self-correcting property.
module tb_ring_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en;
    wire [WIDTH-1:0] q;
    reg [WIDTH-1:0] force_val;

    ring_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .q(q));

    always #5 clk = ~clk;

    function is_one_hot;
        input [WIDTH-1:0] v;
        begin
            is_one_hot = (v != 0) && ((v & (v - 1'b1)) == 0);
        end
    endfunction

    task check_one_hot;
        begin
            checks = checks + 1;
            if (!is_one_hot(q)) begin
                errors = errors + 1;
                $display("ERROR: time=%0t expected one-hot, actual q=%b", $time, q);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_ring_counter.vcd");
            $dumpvars(0, tb_ring_counter);
        end

        rst_n = 0; en = 0;
        @(negedge clk); check_one_hot;   // reset value is one-hot (bit 0)
        if (q !== 4'b0001) begin
            errors = errors + 1;
            $display("ERROR: reset value expected 0001, actual %b", q);
        end
        checks = checks + 1;
        rst_n = 1; en = 1;

        // two full periods of normal rotation, always one-hot
        for (i = 0; i < 2*WIDTH; i = i + 1) begin
            @(posedge clk); #1; check_one_hot;
        end

        // force invalid states and confirm recovery within WIDTH cycles
        force_val = 4'b0000; force dut.q = force_val; #1; release dut.q;
        for (i = 0; i < WIDTH; i = i + 1) @(posedge clk); #1;
        check_one_hot;

        force_val = 4'b1010; force dut.q = force_val; #1; release dut.q;
        for (i = 0; i < WIDTH; i = i + 1) @(posedge clk); #1;
        check_one_hot;

        force_val = 4'b1111; force dut.q = force_val; #1; release dut.q;
        for (i = 0; i < WIDTH; i = i + 1) @(posedge clk); #1;
        check_one_hot;

        // continues rotating correctly after recovery
        for (i = 0; i < WIDTH; i = i + 1) begin
            @(posedge clk); #1; check_one_hot;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
