`timescale 1ns / 1ps

module tb_bit_manipulator;

    reg  [31:0] data_in;
    reg  [1:0]  byte_sel;
    wire        msb, lsb;
    wire [7:0]  low_byte, high_byte, sel_byte;
    wire [31:0] byte_swap, sext_byte, rotl8;

    integer errors = 0;
    integer checks = 0;
    integer n, s;

    bit_manipulator dut (
        .data_in(data_in), .byte_sel(byte_sel), .msb(msb), .lsb(lsb),
        .low_byte(low_byte), .high_byte(high_byte), .sel_byte(sel_byte),
        .byte_swap(byte_swap), .sext_byte(sext_byte), .rotl8(rotl8)
    );

    // Reference model uses shifts and masks instead of part selects
    task check_all;
        reg [31:0] e_swap, e_sext, e_rot;
        reg [7:0]  e_sel;
        begin
            e_sel  = (data_in >> (8 * byte_sel)) & 32'hFF;
            e_swap = ((data_in & 32'h0000_00FF) << 24) | ((data_in & 32'h0000_FF00) << 8) |
                     ((data_in & 32'h00FF_0000) >> 8)  | ((data_in & 32'hFF00_0000) >> 24);
            e_sext = (data_in & 32'h80) ? (data_in | 32'hFFFF_FF00) : (data_in & 32'hFF);
            e_rot  = (data_in << 8) | (data_in >> 24);
            checks = checks + 1;
            if (msb !== (data_in >> 31) || lsb !== (data_in & 1) ||
                low_byte !== (data_in & 32'hFF) || high_byte !== (data_in >> 24) ||
                sel_byte !== e_sel || byte_swap !== e_swap ||
                sext_byte !== e_sext || rotl8 !== e_rot) begin
                errors = errors + 1;
                $display("ERROR: data_in=%h byte_sel=%0d msb=%b lsb=%b low=%h high=%h sel=%h(exp %h) swap=%h(exp %h) sext=%h(exp %h) rot=%h(exp %h)",
                         data_in, byte_sel, msb, lsb, low_byte, high_byte, sel_byte, e_sel,
                         byte_swap, e_swap, sext_byte, e_sext, rotl8, e_rot);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_bit_manipulator.vcd");
            $dumpvars(0, tb_bit_manipulator);
        end

        // Directed example with distinct bytes so every selection is visible
        data_in = 32'h1234_56F8;
        $display("data_in   = %h", data_in);
        for (s = 0; s < 4; s = s + 1) begin
            byte_sel = s;
            #1;
            $display("byte_sel=%0d -> sel_byte=%h", byte_sel, sel_byte);
            check_all;
        end
        $display("msb=%b lsb=%b low_byte=%h high_byte=%h", msb, lsb, low_byte, high_byte);
        $display("byte_swap=%h sext_byte=%h rotl8=%h", byte_swap, sext_byte, rotl8);

        // Sign-extension corner cases
        data_in = 32'h0000_007F; byte_sel = 0; #1 check_all;
        data_in = 32'h0000_0080; #1 check_all;
        data_in = 32'hFFFF_FFFF; #1 check_all;
        data_in = 32'h0000_0000; #1 check_all;

        // Random vectors, every byte_sel value
        for (n = 0; n < 500; n = n + 1) begin
            data_in = $random;
            byte_sel = $random;
            #1 check_all;
        end

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
