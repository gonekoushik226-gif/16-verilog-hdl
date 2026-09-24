`timescale 1ns / 1ps

module tb_literal_constants;

    reg  [3:0]  a;
    wire [7:0]  dec_val, hex_val, bin_val, oct_val, neg_val, replicated;
    wire [15:0] zero_ext;
    wire [3:0]  and_mask, or_mask;

    integer errors = 0;
    integer checks = 0;

    literal_constants dut (
        .a(a), .dec_val(dec_val), .hex_val(hex_val), .bin_val(bin_val),
        .oct_val(oct_val), .neg_val(neg_val), .zero_ext(zero_ext),
        .replicated(replicated), .and_mask(and_mask), .or_mask(or_mask)
    );

    // Compare with case equality (===) so that x and z must match exactly
    task check8(input [7:0] actual, input [7:0] expected, input [8*10-1:0] name);
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s expected %b got %b", name, expected, actual);
            end
        end
    endtask

    task check4(input [3:0] actual, input [3:0] expected, input [8*10-1:0] name);
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s a=%b expected %b got %b", name, a, expected, actual);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_literal_constants.vcd");
            $dumpvars(0, tb_literal_constants);
        end

        a = 4'b1010;
        #10;
        $display("dec_val=%0d hex_val=%h bin_val=%b oct_val=%o", dec_val, hex_val, bin_val, oct_val);
        $display("neg_val bits=%b unsigned=%0d signed=%0d", neg_val, neg_val, $signed(neg_val));
        $display("zero_ext=%h replicated=%h", zero_ext, replicated);
        check8(dec_val, 200, "dec_val");
        check8(hex_val, 200, "hex_val");
        check8(bin_val, 200, "bin_val");
        check8(oct_val, 200, "oct_val");
        check8(neg_val, 200, "neg_val");
        check8(zero_ext[7:0], 8'hC8, "zext_low");
        check8(zero_ext[15:8], 8'h00, "zext_high");
        check8(replicated, 8'b1010_1010, "replicated");

        // Known inputs
        check4(and_mask, 4'b1000, "and_mask");
        check4(or_mask,  4'b1011, "or_mask");

        // Four-state inputs: bit3=x, bit2=z, bit1=0, bit0=1
        a = 4'bxz01;
        #10;
        $display("a=%b  a & 1100 = %b   a | 0011 = %b", a, and_mask, or_mask);
        // x&1 = x, z&1 = x (z behaves as unknown inside logic), 0&0 = 0, 1&0 = 0
        check4(and_mask, 4'bxx00, "and_mask");
        // x|0 = x, z|0 = x, 0|1 = 1, 1|1 = 1
        check4(or_mask,  4'bxx11, "or_mask");

        // Dominating values: 0 forces AND to 0, 1 forces OR to 1 even with x
        a = 4'b00xz;
        #10;
        $display("a=%b  a & 1100 = %b   a | 0011 = %b", a, and_mask, or_mask);
        check4(and_mask, 4'b0000, "and_mask");
        check4(or_mask,  4'b0011, "or_mask");

        // == with an x operand yields x (the if-branch is NOT taken);
        // === compares the four-state values literally.
        a = 4'b10x0;
        #1;
        checks = checks + 1;
        if ((a == 4'b1000) !== 1'bx) begin
            errors = errors + 1;
            $display("ERROR: (a == 4'b1000) should be x");
        end
        checks = checks + 1;
        if ((a === 4'b10x0) !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR: (a === 4'b10x0) should be 1");
        end
        $display("a=%b: (a == 4'b1000) -> %b, (a === 4'b10x0) -> %b",
                 a, (a == 4'b1000), (a === 4'b10x0));

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
