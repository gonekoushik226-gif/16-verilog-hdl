`timescale 1ns / 1ps

// tb_safe_fsm: (1) confirms normal cyclic operation over several
// `advance` pulses; (2) exhaustively forces the internal `state`
// register (hierarchical `force`/`release`, following the same
// technique already used in this repository's 110-ring-counter) to
// EVERY one of the 16 possible 4-bit values -- the 4 legal one-hot
// patterns and all 12 illegal ones -- checking `error` combinationally
// for each, then confirming single-cycle recovery to S_A for every
// illegal value (and correct self-loop/advance behavior for the legal
// ones); (3) confirms recovery is unconditional (ignores `advance`) for
// a supplementary sweep.
module tb_safe_fsm;

    integer errors = 0;
    integer checks = 0;

    reg clk = 0;
    reg rst_n, advance;
    wire [3:0] state_out;
    wire error;

    safe_fsm dut (
        .clk(clk), .rst_n(rst_n), .advance(advance),
        .state_out(state_out), .error(error)
    );

    always #5 clk = ~clk;

    localparam [3:0] S_A = 4'b0001, S_B = 4'b0010, S_C = 4'b0100, S_D = 4'b1000;

    task do_reset;
        begin
            rst_n = 0; advance = 0;
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    function is_legal(input [3:0] v);
        begin
            is_legal = (v == S_A) || (v == S_B) || (v == S_C) || (v == S_D);
        end
    endfunction

    integer v;
    reg [3:0] expected;
    reg [3:0] force_val;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_safe_fsm.vcd");
            $dumpvars(0, tb_safe_fsm);
        end

        // --- normal cyclic operation: S_A -> S_B -> S_C -> S_D -> S_A ... ---
        do_reset;
        checks = checks + 1;
        if (state_out !== S_A || error !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR: expected S_A after reset, got state=%b error=%b", state_out, error);
        end

        advance = 1'b1;
        expected = S_B;
        for (v = 0; v < 8; v = v + 1) begin
            @(posedge clk); #1;
            checks = checks + 1;
            if (state_out !== expected) begin
                errors = errors + 1;
                $display("ERROR: normal cycle step %0d: state=%b expected=%b", v, state_out, expected);
            end
            case (expected)
                S_A: expected = S_B;
                S_B: expected = S_C;
                S_C: expected = S_D;
                S_D: expected = S_A;
                default: expected = S_A;
            endcase
        end
        advance = 1'b0;

        // --- exhaustive illegal-state injection: all 16 possible
        // 4-bit values, advance held low so legal states self-loop ---
        for (v = 0; v < 16; v = v + 1) begin
            force_val = v[3:0];
            force dut.state = force_val;
            #1;
            checks = checks + 1;
            if (error !== !is_legal(v[3:0])) begin
                errors = errors + 1;
                $display("ERROR: state=%b error=%b expected=%b", v[3:0], error, !is_legal(v[3:0]));
            end
            release dut.state;

            @(posedge clk); #1;
            checks = checks + 1;
            if (is_legal(v[3:0])) begin
                // advance=0: legal states self-loop
                if (state_out !== v[3:0]) begin
                    errors = errors + 1;
                    $display("ERROR: legal state=%b should self-loop with advance=0, got=%b",
                              v[3:0], state_out);
                end
            end else begin
                // illegal states recover to S_A within exactly one cycle
                if (state_out !== S_A || error !== 1'b0) begin
                    errors = errors + 1;
                    $display("ERROR: illegal state=%b did not recover to S_A: state=%b error=%b",
                              v[3:0], state_out, error);
                end
            end
        end

        // --- recovery is unconditional: illegal states recover to S_A
        // even while advance=1 ---
        advance = 1'b1;
        for (v = 0; v < 16; v = v + 1) begin
            if (!is_legal(v[3:0])) begin
                force_val = v[3:0];
                force dut.state = force_val;
                #1;
                release dut.state;
                @(posedge clk); #1;
                checks = checks + 1;
                if (state_out !== S_A) begin
                    errors = errors + 1;
                    $display("ERROR: illegal state=%b with advance=1 did not recover to S_A, got=%b",
                              v[3:0], state_out);
                end
            end
        end
        advance = 1'b0;

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
