`timescale 1ns / 1ps

// tb_seq_circuit: exhaustively forces every (q1,q0) state via
// hierarchical `force` on the internal flip-flops, applies both values
// of x, and checks the output y (from the forced state) and the next
// state reached after one clock edge, against the hand-derived
// equations in seq_circuit.v's header comment.
module tb_seq_circuit;

    integer errors = 0;
    integer checks = 0;
    integer si, xi;
    reg force_q1, force_q0;

    reg clk = 0;
    reg rst_n, x;
    wire y;
    wire [1:0] state;

    seq_circuit dut (.clk(clk), .rst_n(rst_n), .x(x), .y(y), .state(state));

    always #5 clk = ~clk;

    function [1:0] expected_next;
        input [1:0] s;
        input       xin;
        reg q1, q0, d1, d0;
        begin
            q1 = s[1]; q0 = s[0];
            d1 = q1 ^ (q0 & xin);
            d0 = (~q0) | (q1 & ~xin);
            expected_next = {d1, d0};
        end
    endfunction

    function expected_y;
        input [1:0] s;
        begin
            expected_y = s[1] & s[0];
        end
    endfunction

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_seq_circuit.vcd");
            $dumpvars(0, tb_seq_circuit);
        end

        rst_n = 1;

        for (si = 0; si < 4; si = si + 1) begin
            for (xi = 0; xi < 2; xi = xi + 1) begin
                // force the state directly, bypassing normal transitions,
                // so every (state,input) combination is exercised
                force_q1 = si[1];
                force_q0 = si[0];
                force dut.ff1.q = force_q1;
                force dut.ff0.q = force_q0;
                x = xi[0];
                #1;

                checks = checks + 1;
                if (state !== si[1:0] || y !== expected_y(si[1:0])) begin
                    errors = errors + 1;
                    $display("ERROR(output): state=%b x=%b expected y=%b actual y=%b state=%b",
                              si[1:0], x, expected_y(si[1:0]), y, state);
                end

                release dut.ff1.q;
                release dut.ff0.q;

                @(posedge clk); #1;
                checks = checks + 1;
                if (state !== expected_next(si[1:0], xi[0])) begin
                    errors = errors + 1;
                    $display("ERROR(next-state): from state=%b x=%b expected next=%b actual next=%b",
                              si[1:0], xi[0], expected_next(si[1:0], xi[0]), state);
                end
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
