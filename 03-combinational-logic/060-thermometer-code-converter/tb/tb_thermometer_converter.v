`timescale 1ns / 1ps

// tb_thermometer_converter: exhaustive bin->therm->bin round trip for all
// WIDTH+1 valid counts, plus directed bubble (non-monotonic) codes that
// must be flagged and still decoded to their popcount.
module tb_thermometer_converter;

    localparam WIDTH = 8;
    localparam BW    = $clog2(WIDTH+1);

    integer errors = 0;
    integer checks = 0;
    integer i;

    reg  [BW-1:0]    bin_in;
    wire [WIDTH-1:0] therm_out;

    reg  [WIDTH-1:0] therm_in;
    wire [BW-1:0]    bin_out;
    wire             bubble;

    bin2therm #(.WIDTH(WIDTH)) dut_b2t (.bin(bin_in),   .therm(therm_out));
    therm2bin #(.WIDTH(WIDTH)) dut_t2b (.therm(therm_in), .bin(bin_out), .bubble(bubble));

    task check_roundtrip(input [BW-1:0] b);
        reg [WIDTH-1:0] exp_therm;
        integer k;
        begin
            bin_in = b;
            #1;
            exp_therm = {WIDTH{1'b0}};
            for (k = 0; k < WIDTH; k = k + 1)
                exp_therm[k] = (k < b);
            checks = checks + 1;
            if (therm_out !== exp_therm) begin
                errors = errors + 1;
                $display("ERROR: bin2therm bin=%0d expected therm=%b actual=%b", b, exp_therm, therm_out);
            end

            therm_in = therm_out;
            #1;
            checks = checks + 1;
            if (bin_out !== b || bubble !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR: therm2bin therm=%b expected bin=%0d bubble=0 actual bin=%0d bubble=%b",
                          therm_out, b, bin_out, bubble);
            end
        end
    endtask

    task check_bubble(input [WIDTH-1:0] t);
        integer k, exp_popcount;
        begin
            therm_in = t;
            #1;
            exp_popcount = 0;
            for (k = 0; k < WIDTH; k = k + 1)
                exp_popcount = exp_popcount + t[k];
            checks = checks + 1;
            if (bin_out !== exp_popcount[BW-1:0] || bubble !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR: bubble-code therm=%b expected bin=%0d bubble=1 actual bin=%0d bubble=%b",
                          t, exp_popcount, bin_out, bubble);
            end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/tb_thermometer_converter.vcd");
            $dumpvars(0, tb_thermometer_converter);
        end

        $display("exhaustive bin->therm->bin round trip (bin = 0..%0d)...", WIDTH);
        for (i = 0; i <= WIDTH; i = i + 1)
            check_roundtrip(i[BW-1:0]);
        $display("  done: %0d checks, errors so far: %0d", checks, errors);

        $display("directed bubble (non-monotonic) codes...");
        check_bubble(8'b0000_1010);   // isolated 1s below the "thermometer front"
        check_bubble(8'b1111_0111);   // isolated 0 above the front (bubble in the 1s region)
        check_bubble(8'b1010_1010);   // alternating, maximally non-monotonic
        check_bubble(8'b0101_0101);
        check_bubble(8'b1000_0001);   // one bit set at each end
        check_bubble(8'b0110_0110);
        check_bubble(8'b1111_1110 ^ 8'b0000_0100); // canonical code for 7 with one bubble flipped
        $display("  done: %0d checks total, errors so far: %0d", checks, errors);

        if (errors == 0) $display("TEST PASSED: %0d checks", checks);
        else             $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

endmodule
