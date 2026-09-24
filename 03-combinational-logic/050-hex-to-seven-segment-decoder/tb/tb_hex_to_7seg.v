`timescale 1ns / 1ps

// tb_hex_to_7seg: checks all 16 hex digits against the standard
// common-anode seven-segment lookup table (segments active-low, ordered
// {a,b,c,d,e,f,g}).
module tb_hex_to_7seg;

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  [3:0] hex;
    wire [6:0] seg;

    hex_to_7seg dut (.hex(hex), .seg(seg));

    function [6:0] expected_seg(input [3:0] h);
        begin
            case (h)
                4'h0: expected_seg = 7'b0000001;
                4'h1: expected_seg = 7'b1001111;
                4'h2: expected_seg = 7'b0010010;
                4'h3: expected_seg = 7'b0000110;
                4'h4: expected_seg = 7'b1001100;
                4'h5: expected_seg = 7'b0100100;
                4'h6: expected_seg = 7'b0100000;
                4'h7: expected_seg = 7'b0001111;
                4'h8: expected_seg = 7'b0000000;
                4'h9: expected_seg = 7'b0000100;
                4'hA: expected_seg = 7'b0001000;
                4'hB: expected_seg = 7'b1100000;
                4'hC: expected_seg = 7'b0110001;
                4'hD: expected_seg = 7'b1000010;
                4'hE: expected_seg = 7'b0110000;
                4'hF: expected_seg = 7'b0111000;
                default: expected_seg = 7'b1111111;
            endcase
        end
    endfunction

    task check(input [3:0] h);
        reg [6:0] exp;
        begin
            hex = h;
            #1;
            exp = expected_seg(h);
            checks = checks + 1;
            if (seg !== exp) begin
                errors = errors + 1;
                $display("ERROR: hex=%h expected seg={a,b,c,d,e,f,g}=%b actual=%b", h, exp, seg);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_hex_to_7seg.vcd");
            $dumpvars(0, tb_hex_to_7seg);
        end

        $display("all 16 hex digits vs the standard 7-segment table:");
        for (i = 0; i < 16; i = i + 1)
            check(i[3:0]);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
