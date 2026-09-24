`timescale 1ns / 1ps

// tb_up_down_counter: counts up past a wrap, then down past a wrap in
// the opposite direction, checked against a software reference.
module tb_up_down_counter;

    localparam WIDTH = 4;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg clk = 0;
    reg rst_n, en, up;
    wire [WIDTH-1:0] count;

    reg [WIDTH-1:0] ref_count;

    up_down_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .up(up), .count(count));

    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (count !== ref_count) begin
                errors = errors + 1;
                $display("ERROR: time=%0t up=%b expected count=%0d actual count=%0d", $time, up, ref_count, count);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_up_down_counter.vcd");
            $dumpvars(0, tb_up_down_counter);
        end

        rst_n = 0; en = 0; up = 1; ref_count = 0;
        @(negedge clk); check;
        rst_n = 1;

        en = 1; up = 1;
        for (i = 0; i < 18; i = i + 1) begin   // past the up-wrap (16 values)
            ref_count = ref_count + 1;
            @(posedge clk); #1; check;
        end

        up = 0;
        for (i = 0; i < 18; i = i + 1) begin   // past the down-wrap
            ref_count = ref_count - 1;
            @(posedge clk); #1; check;
        end

        en = 0;
        for (i = 0; i < 3; i = i + 1) begin @(posedge clk); #1; check; end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
