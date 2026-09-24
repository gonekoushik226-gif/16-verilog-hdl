`timescale 1ns / 1ps

module tb_conditional_demo;

    reg  [1:0] a, b, op;
    reg        sel;
    reg  [3:0] req;
    wire [1:0] mux_out, prio_if, prio_casez, alu_out;
    wire       prio_valid;

    integer errors = 0;
    integer checks = 0;
    integer n, k;
    reg [1:0] e_mux, e_prio, e_alu;
    reg       e_valid;

    conditional_demo dut (
        .a(a), .b(b), .sel(sel), .req(req), .op(op),
        .mux_out(mux_out), .prio_if(prio_if), .prio_casez(prio_casez),
        .prio_valid(prio_valid), .alu_out(alu_out)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_conditional_demo.vcd");
            $dumpvars(0, tb_conditional_demo);
        end

        // Exhaustive: a(2) b(2) sel(1) req(4) op(2) = 11 bits = 2048 cases
        for (n = 0; n < 2048; n = n + 1) begin
            {a, b, sel, req, op} = n[10:0];
            #1;
            e_mux = (sel == 1'b1) ? a : b;
            // reference priority: scan from bit 0 upward, last hit wins
            e_prio = 2'd0; e_valid = 1'b0;
            for (k = 0; k < 4; k = k + 1)
                if (req[k] == 1'b1) begin e_prio = k; e_valid = 1'b1; end
            case (op)
                2'd0: e_alu = a & b;
                2'd1: e_alu = a | b;
                2'd2: e_alu = a ^ b;
                2'd3: e_alu = (a + b) % 4;
            endcase
            checks = checks + 1;
            if (mux_out !== e_mux || prio_if !== e_prio || prio_casez !== e_prio ||
                prio_valid !== e_valid || alu_out !== e_alu) begin
                errors = errors + 1;
                $display("ERROR: a=%b b=%b sel=%b req=%b op=%0d -> mux=%b prio_if=%0d prio_casez=%0d valid=%b alu=%b",
                         a, b, sel, req, op, mux_out, prio_if, prio_casez, prio_valid, alu_out);
            end
        end

        $display(" req  | prio_if prio_casez valid");
        a = 0; b = 0; sel = 0; op = 0;
        for (n = 0; n < 16; n = n + 1) begin
            req = n;
            #1 $display(" %b |    %0d        %0d       %b", req, prio_if, prio_casez, prio_valid);
        end
        $display(" a  b  op | alu_out");
        a = 2'b10; b = 2'b11;
        for (n = 0; n < 4; n = n + 1) begin
            op = n;
            #1 $display(" %b %b %0d  |  %b", a, b, op, alu_out);
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
