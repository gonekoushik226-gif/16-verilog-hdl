`timescale 1ns / 1ps

// tb_alu4: all 8 opcodes x exhaustive 4-bit (a,b) = 2048 checks, each
// compared against a per-opcode reference model.
module tb_alu4;

    integer errors = 0;
    integer checks = 0;
    integer ai, bi, oi;

    reg  [3:0] a, b;
    reg  [2:0] opcode;
    wire [3:0] result;
    wire       carry, overflow, zero, negative;

    alu4 dut (.a(a), .b(b), .opcode(opcode), .result(result), .carry(carry),
              .overflow(overflow), .zero(zero), .negative(negative));

    task check;
        reg [4:0] ext;
        reg [3:0] expected_result;
        reg       expected_carry, expected_overflow;
        begin
            #1;
            checks = checks + 1;
            expected_carry = 1'b0;
            expected_overflow = 1'b0;
            case (opcode)
                3'b000: begin // ADD
                    ext = {1'b0,a} + {1'b0,b};
                    expected_result = ext[3:0];
                    expected_carry = ext[4];
                    expected_overflow = (a[3]==b[3]) && (expected_result[3]!=a[3]);
                end
                3'b001: begin // SUB
                    ext = {1'b1,a} - {1'b0,b};
                    expected_result = ext[3:0];
                    expected_carry = ext[4];
                    expected_overflow = (a[3]!=b[3]) && (expected_result[3]!=a[3]);
                end
                3'b010: expected_result = a & b;
                3'b011: expected_result = a | b;
                3'b100: expected_result = a ^ b;
                3'b101: expected_result = ~a;
                3'b110: expected_result = a << 1;
                3'b111: expected_result = a >> 1;
                default: expected_result = 4'b0;
            endcase

            if (result !== expected_result || zero !== (expected_result == 4'b0)
                || negative !== expected_result[3]
                || ((opcode == 3'b000 || opcode == 3'b001)
                    && (carry !== expected_carry || overflow !== expected_overflow))) begin
                errors = errors + 1;
                $display("ERROR: op=%0d a=%0d b=%0d expected result=%0d carry=%b ovf=%b actual result=%0d carry=%b ovf=%b",
                          opcode, a, b, expected_result, expected_carry, expected_overflow,
                          result, carry, overflow);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_alu4.vcd");
            $dumpvars(0, tb_alu4);
        end

        for (oi = 0; oi < 8; oi = oi + 1)
            for (ai = 0; ai < 16; ai = ai + 1)
                for (bi = 0; bi < 16; bi = bi + 1) begin
                    opcode = oi[2:0]; a = ai[3:0]; b = bi[3:0];
                    check;
                end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
