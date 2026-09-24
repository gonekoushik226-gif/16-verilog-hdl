`timescale 1ns / 1ps

// tb_johnson_counter: from reset, checks the full 2*WIDTH-state
// sequence (0000,0001,0011,0111,1111,1110,1100,1000 for WIDTH=4) over
// two complete cycles, and checks `decoded` is one-hot with exactly the
// bit matching the DUT's own decode index for the current state (which
// is NOT the traversal order starting from reset -- see the seq_idx
// mapping below and README.md SS10 for why).
module tb_johnson_counter;

    localparam WIDTH = 4;
    localparam STATES = 2*WIDTH;

    integer errors = 0;
    integer checks = 0;
    integer i, cyc;

    reg clk = 0;
    reg rst_n, en;
    wire [WIDTH-1:0] q;
    wire [2*WIDTH-1:0] decoded;

    // traversal order starting from reset: seq_q[p] is the state visited
    // at position p; seq_idx[p] is the DUT's own decode bit index for
    // that state (decoded[i]=(q==(2^(i+1)-1)) for the "filling" states,
    // decoded[WIDTH+i]=(q==~(2^(i+1)-1)) for the "draining" states --
    // reset's all-zero state is itself the last "draining" pattern,
    // decoded[2*WIDTH-1], not decoded[0]).
    reg [WIDTH-1:0] seq_q   [0:7];
    integer         seq_idx [0:7];

    johnson_counter #(.WIDTH(WIDTH)) dut (.clk(clk), .rst_n(rst_n), .en(en), .q(q), .decoded(decoded));

    always #5 clk = ~clk;

    task check(input integer pos);
        reg [2*WIDTH-1:0] exp_decoded;
        begin
            checks = checks + 1;
            exp_decoded = {{(2*WIDTH-1){1'b0}}, 1'b1} << seq_idx[pos];
            if (q !== seq_q[pos] || decoded !== exp_decoded) begin
                errors = errors + 1;
                $display("ERROR: pos=%0d expected q=%b decoded=%b actual q=%b decoded=%b",
                          pos, seq_q[pos], exp_decoded, q, decoded);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_johnson_counter.vcd");
            $dumpvars(0, tb_johnson_counter);
        end

        seq_q[0] = 4'b0000; seq_idx[0] = 7;
        seq_q[1] = 4'b0001; seq_idx[1] = 0;
        seq_q[2] = 4'b0011; seq_idx[2] = 1;
        seq_q[3] = 4'b0111; seq_idx[3] = 2;
        seq_q[4] = 4'b1111; seq_idx[4] = 3;
        seq_q[5] = 4'b1110; seq_idx[5] = 4;
        seq_q[6] = 4'b1100; seq_idx[6] = 5;
        seq_q[7] = 4'b1000; seq_idx[7] = 6;

        rst_n = 0; en = 0;
        @(negedge clk); check(0);
        rst_n = 1; en = 1;

        for (cyc = 0; cyc < 2; cyc = cyc + 1) begin
            for (i = 1; i < STATES; i = i + 1) begin
                @(posedge clk); #1; check(i);
            end
            @(posedge clk); #1; check(0);   // wraps back to state 0
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
