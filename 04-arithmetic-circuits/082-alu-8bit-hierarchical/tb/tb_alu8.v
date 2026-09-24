`timescale 1ns / 1ps

// tb_alu8: for each of the 16 possible opcodes, 150 random (a,b) pairs
// plus a fixed set of corner operands (0x00, 0xFF, 0x80, 0x7F,
// alternating-bit patterns, and every shift amount 0-7), checked
// against a reference model mirroring the RTL's own opcode decode.
module tb_alu8;

    integer errors = 0;
    integer checks = 0;
    integer oi, r, ci;

    reg  [7:0] a, b;
    reg  [3:0] opcode;
    wire [7:0] result;
    wire       carry, overflow, zero, negative;

    reg [7:0] corners [0:7];

    alu8 dut (.a(a), .b(b), .opcode(opcode), .result(result), .carry(carry),
              .overflow(overflow), .zero(zero), .negative(negative));

    task check;
        reg [8:0] ext;
        reg [7:0] expected_result;
        reg       expected_carry, expected_overflow;
        reg [2:0] amount;
        begin
            #1;
            checks = checks + 1;
            expected_carry = 1'b0;
            expected_overflow = 1'b0;
            amount = b[2:0];

            case (opcode[3:2])
                2'b00: begin // arithmetic
                    if (opcode[0]) ext = {1'b1,a} - {1'b0,b};
                    else           ext = {1'b0,a} + {1'b0,b};
                    expected_result = ext[7:0];
                    expected_carry  = ext[8];
                    expected_overflow = opcode[0] ? ((a[7]!=b[7]) && (expected_result[7]!=a[7]))
                                                   : ((a[7]==b[7]) && (expected_result[7]!=a[7]));
                end
                2'b01: begin // logic
                    case (opcode[1:0])
                        2'b00: expected_result = a & b;
                        2'b01: expected_result = a | b;
                        2'b10: expected_result = a ^ b;
                        2'b11: expected_result = ~a;
                    endcase
                end
                2'b10: begin // shift/rotate
                    case (opcode[1:0])
                        2'b00: expected_result = a << amount;
                        2'b01: expected_result = a >> amount;
                        2'b10: expected_result = (a << amount) | (a >> (4'd8 - amount));
                        2'b11: expected_result = (a >> amount) | (a << (4'd8 - amount));
                    endcase
                end
                default: expected_result = 8'b0;   // reserved
            endcase

            if (result !== expected_result || zero !== (expected_result == 8'b0)
                || negative !== expected_result[7]
                || (opcode[3:2] == 2'b00 && (carry !== expected_carry || overflow !== expected_overflow))) begin
                errors = errors + 1;
                $display("ERROR: op=%b a=%0d b=%0d expected result=%0d carry=%b ovf=%b actual result=%0d carry=%b ovf=%b",
                          opcode, a, b, expected_result, expected_carry, expected_overflow,
                          result, carry, overflow);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_alu8.vcd");
            $dumpvars(0, tb_alu8);
        end

        corners[0] = 8'h00; corners[1] = 8'hFF; corners[2] = 8'h80; corners[3] = 8'h7F;
        corners[4] = 8'h55; corners[5] = 8'hAA; corners[6] = 8'h01; corners[7] = 8'h08;

        for (oi = 0; oi < 16; oi = oi + 1) begin
            opcode = oi[3:0];

            for (r = 0; r < 150; r = r + 1) begin
                a = $random; b = $random;
                check;
            end

            for (ci = 0; ci < 8; ci = ci + 1) begin
                a = corners[ci]; b = corners[7-ci];
                check;
            end
            // exhaustive shift amounts, fixed operand, for shift/rotate opcodes
            if (opcode[3:2] == 2'b10) begin
                a = 8'hA5;
                for (ci = 0; ci < 8; ci = ci + 1) begin
                    b = {5'b0, ci[2:0]};
                    check;
                end
            end
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
