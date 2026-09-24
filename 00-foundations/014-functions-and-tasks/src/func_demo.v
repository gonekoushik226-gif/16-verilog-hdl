`timescale 1ns / 1ps

// func_demo
// Synthesizable functions: each call is expanded into combinational logic.
module func_demo (
    input  wire [7:0] data,
    output wire [3:0] ones,        // number of 1 bits
    output wire       parity,      // odd parity
    output wire [7:0] reversed,    // bit order reversed
    output wire [2:0] lowest_one,  // index of the least significant 1 bit
    output wire       any_one      // data != 0 (lowest_one is valid)
);

    // Count the 1 bits. The loop has a constant bound, so synthesis unrolls it.
    function [3:0] count_ones;
        input [7:0] v;
        integer i;
        begin
            count_ones = 4'd0;
            for (i = 0; i < 8; i = i + 1)
                count_ones = count_ones + {3'b000, v[i]};   // widen the bit to 4 bits
        end
    endfunction

    function [7:0] reverse_bits;
        input [7:0] v;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                reverse_bits[i] = v[7 - i];
        end
    endfunction

    // Scan from the MSB down so that the last match (the lowest index) wins
    function [2:0] find_lowest;
        input [7:0] v;
        integer i;
        begin
            find_lowest = 3'd0;
            for (i = 7; i >= 0; i = i - 1)
                if (v[i]) find_lowest = i[2:0];
        end
    endfunction

    assign ones       = count_ones(data);
    assign parity     = ones[0];            // odd count <=> LSB of the count is 1
    assign reversed   = reverse_bits(data);
    assign lowest_one = find_lowest(data);
    assign any_one    = |data;

endmodule
