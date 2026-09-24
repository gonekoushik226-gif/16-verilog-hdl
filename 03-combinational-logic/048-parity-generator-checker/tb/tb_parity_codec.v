`timescale 1ns / 1ps

// tb_parity_codec: exhaustive check of parity_generator + parity_checker,
// in both even and odd configurations, plus single-bit error injection
// into every one of the WIDTH+1 codeword bits for every data value.
module tb_parity_codec;

    localparam WIDTH = 8;

    integer errors = 0;
    integer checks = 0;
    integer i, bit_pos;

    reg  [WIDTH-1:0] data_e, data_o;
    wire              parity_e, parity_o;
    reg               parity_in_e, parity_in_o;
    wire              error_e, error_o;

    parity_generator #(.WIDTH(WIDTH), .ODD(0)) genE (.data(data_e), .parity(parity_e));
    parity_checker   #(.WIDTH(WIDTH), .ODD(0)) chkE (.data(data_e), .parity_in(parity_in_e), .error(error_e));

    parity_generator #(.WIDTH(WIDTH), .ODD(1)) genO (.data(data_o), .parity(parity_o));
    parity_checker   #(.WIDTH(WIDTH), .ODD(1)) chkO (.data(data_o), .parity_in(parity_in_o), .error(error_o));

    // Checks that the checker reports no error on a clean (unflipped)
    // codeword, and that generated parity gives the requested total count.
    task check_clean(input [WIDTH-1:0] d);
        reg expected_e, expected_o;
        begin
            data_e = d; data_o = d;
            #1;
            parity_in_e = parity_e;
            parity_in_o = parity_o;
            #1;
            expected_e = ^{d, parity_e};        // even parity -> total XOR must be 0
            expected_o = ^{d, parity_o};        // odd parity  -> total XOR must be 1
            checks = checks + 1;
            if (expected_e !== 1'b0 || error_e !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR: even data=%b parity=%b expected clean, total-xor=%b error=%b",
                          d, parity_e, expected_e, error_e);
            end
            checks = checks + 1;
            if (expected_o !== 1'b1 || error_o !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR: odd data=%b parity=%b expected clean, total-xor=%b error=%b",
                          d, parity_o, expected_o, error_o);
            end
        end
    endtask

    // Flips exactly one bit of the (WIDTH+1)-bit codeword {data,parity} and
    // checks that both checkers now report error=1.
    task check_single_bit_error(input [WIDTH-1:0] d, input integer pos);
        reg [WIDTH-1:0] flipped_data_e, flipped_data_o;
        reg             flipped_parity_e, flipped_parity_o;
        begin
            data_e = d; data_o = d;
            #1;
            flipped_data_e = d; flipped_parity_e = parity_e;
            flipped_data_o = d; flipped_parity_o = parity_o;
            if (pos < WIDTH) begin
                flipped_data_e[pos] = ~flipped_data_e[pos];
                flipped_data_o[pos] = ~flipped_data_o[pos];
            end else begin
                flipped_parity_e = ~flipped_parity_e;
                flipped_parity_o = ~flipped_parity_o;
            end
            data_e = flipped_data_e; parity_in_e = flipped_parity_e;
            data_o = flipped_data_o; parity_in_o = flipped_parity_o;
            #1;
            checks = checks + 1;
            if (error_e !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: even single-bit flip at pos=%0d data=%b(orig %b) parity=%b expected error=1 actual=%b",
                          pos, flipped_data_e, d, flipped_parity_e, error_e);
            end
            checks = checks + 1;
            if (error_o !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: odd single-bit flip at pos=%0d data=%b(orig %b) parity=%b expected error=1 actual=%b",
                          pos, flipped_data_o, d, flipped_parity_o, error_o);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_parity_codec.vcd");
            $dumpvars(0, tb_parity_codec);
        end

        $display("exhaustive clean-codeword sweep (%0d data values)...", 256);
        for (i = 0; i < 256; i = i + 1)
            check_clean(i[WIDTH-1:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("exhaustive single-bit error injection (%0d data values x %0d bit positions)...",
                  256, WIDTH + 1);
        for (i = 0; i < 256; i = i + 1)
            for (bit_pos = 0; bit_pos < WIDTH + 1; bit_pos = bit_pos + 1)
                check_single_bit_error(i[WIDTH-1:0], bit_pos);
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
