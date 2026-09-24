`timescale 1ns / 1ps

module tb_multi_input_gates;

    localparam N3 = 3;
    localparam N8 = 8;

    reg  [N3-1:0] a3;
    wire y_and3, y_or3, y_xor3, y_nand3, y_nor3, y_xnor3;

    reg  [N8-1:0] a8;
    wire y_and8, y_or8, y_xor8, y_nand8, y_nor8, y_xnor8;

    integer errors = 0;
    integer checks = 0;
    integer i;
    reg      e_and, e_or, e_xor;

    multi_input_gates #(.N(N3)) dut3 (
        .a(a3), .y_and(y_and3), .y_or(y_or3), .y_xor(y_xor3),
        .y_nand(y_nand3), .y_nor(y_nor3), .y_xnor(y_xnor3)
    );

    multi_input_gates #(.N(N8)) dut8 (
        .a(a8), .y_and(y_and8), .y_or(y_or8), .y_xor(y_xor8),
        .y_nand(y_nand8), .y_nor(y_nor8), .y_xnor(y_xnor8)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_multi_input_gates.vcd");
            $dumpvars(0, tb_multi_input_gates);
        end

        // Exhaustive for N = 3 (8 combinations)
        for (i = 0; i < 8; i = i + 1) begin
            a3 = i[N3-1:0];
            #1;
            e_and = &a3; e_or = |a3; e_xor = ^a3;
            checks = checks + 6;
            if (y_and3  !== e_and)  begin errors = errors + 1; $display("ERROR: N=3 AND  a=%b expected=%b actual=%b", a3, e_and, y_and3); end
            if (y_or3   !== e_or)   begin errors = errors + 1; $display("ERROR: N=3 OR   a=%b expected=%b actual=%b", a3, e_or, y_or3); end
            if (y_xor3  !== e_xor)  begin errors = errors + 1; $display("ERROR: N=3 XOR  a=%b expected=%b actual=%b", a3, e_xor, y_xor3); end
            if (y_nand3 !== ~e_and) begin errors = errors + 1; $display("ERROR: N=3 NAND a=%b expected=%b actual=%b", a3, ~e_and, y_nand3); end
            if (y_nor3  !== ~e_or)  begin errors = errors + 1; $display("ERROR: N=3 NOR  a=%b expected=%b actual=%b", a3, ~e_or, y_nor3); end
            if (y_xnor3 !== ~e_xor) begin errors = errors + 1; $display("ERROR: N=3 XNOR a=%b expected=%b actual=%b", a3, ~e_xor, y_xnor3); end
        end
        $display("N=3 sweep done: %0d combinations", 8);

        // Exhaustive for N = 8 (256 combinations)
        for (i = 0; i < 256; i = i + 1) begin
            a8 = i[N8-1:0];
            #1;
            e_and = &a8; e_or = |a8; e_xor = ^a8;
            checks = checks + 6;
            if (y_and8  !== e_and)  begin errors = errors + 1; $display("ERROR: N=8 AND  a=%b expected=%b actual=%b", a8, e_and, y_and8); end
            if (y_or8   !== e_or)   begin errors = errors + 1; $display("ERROR: N=8 OR   a=%b expected=%b actual=%b", a8, e_or, y_or8); end
            if (y_xor8  !== e_xor)  begin errors = errors + 1; $display("ERROR: N=8 XOR  a=%b expected=%b actual=%b", a8, e_xor, y_xor8); end
            if (y_nand8 !== ~e_and) begin errors = errors + 1; $display("ERROR: N=8 NAND a=%b expected=%b actual=%b", a8, ~e_and, y_nand8); end
            if (y_nor8  !== ~e_or)  begin errors = errors + 1; $display("ERROR: N=8 NOR  a=%b expected=%b actual=%b", a8, ~e_or, y_nor8); end
            if (y_xnor8 !== ~e_xor) begin errors = errors + 1; $display("ERROR: N=8 XNOR a=%b expected=%b actual=%b", a8, ~e_xor, y_xnor8); end
        end
        $display("N=8 sweep done: %0d combinations", 256);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
