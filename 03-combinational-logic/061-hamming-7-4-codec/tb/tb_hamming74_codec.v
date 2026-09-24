`timescale 1ns / 1ps

// tb_hamming74_codec: for all 16 possible 4-bit data words, encodes, then
// injects every possible single-bit error (no error, plus each of the 7
// codeword positions flipped) and checks the decoder recovers the
// original data, reports the correct syndrome, and sets `error`
// appropriately.
module tb_hamming74_codec;

    integer errors = 0;
    integer checks = 0;
    integer d, flip_pos;

    reg  [3:0] data_in;
    wire [6:0] code;

    reg  [6:0] code_in;
    wire [3:0] data_out;
    wire       error;
    wire [2:0] syndrome;

    hamming74_encoder enc (.data(data_in), .code(code));
    hamming74_decoder dec (.code_in(code_in), .data_out(data_out), .error(error), .syndrome(syndrome));

    task check(input [3:0] original_data, input [6:0] clean_code, input integer pos);
        reg [6:0] received;
        reg       expect_error;
        reg [2:0] expect_syndrome;
        begin
            received = clean_code;
            if (pos != 0)
                received[pos-1] = ~received[pos-1];   // pos is 1-indexed codeword position

            code_in = received;
            #1;

            expect_error    = (pos != 0);
            expect_syndrome = pos[2:0];

            checks = checks + 1;
            if (data_out !== original_data || error !== expect_error || syndrome !== expect_syndrome) begin
                errors = errors + 1;
                $display("ERROR: data=%b flip_pos=%0d received=%b expected data_out=%b error=%b syndrome=%0d actual data_out=%b error=%b syndrome=%0d",
                          original_data, pos, received, original_data, expect_error, expect_syndrome,
                          data_out, error, syndrome);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_hamming74_codec.vcd");
            $dumpvars(0, tb_hamming74_codec);
        end

        $display("all 16 data words x (no error + every single-bit error at 7 positions)...");
        for (d = 0; d < 16; d = d + 1) begin
            data_in = d[3:0];
            #1;
            for (flip_pos = 0; flip_pos <= 7; flip_pos = flip_pos + 1)
                check(d[3:0], code, flip_pos);
        end
        $display("done: %0d checks", checks);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
