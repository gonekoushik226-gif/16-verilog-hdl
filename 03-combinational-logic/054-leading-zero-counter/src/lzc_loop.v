`timescale 1ns / 1ps

// lzc_loop: leading-zero counter implemented as a priority scan — an
// unrolled loop that walks the input from the MSB down, counting zero
// bits until the first 1 is found, then stops updating the count. This
// is the "sequential algorithm unrolled combinationally" style, contrasted
// with lzc_tree's divide-and-conquer structure.
module lzc_loop #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]         data,
    output reg  [$clog2(WIDTH+1)-1:0] count,   // 0..WIDTH leading zeros
    output reg                        all_zero
);

    integer i;
    reg     done;

    always @(*) begin
        count    = {$clog2(WIDTH+1){1'b0}};
        done     = 1'b0;
        all_zero = (data == {WIDTH{1'b0}});
        for (i = WIDTH - 1; i >= 0; i = i - 1) begin
            if (!done) begin
                if (data[i])
                    done = 1'b1;          // first 1 found: stop counting
                else
                    count = count + 1'b1; // still scanning leading zeros
            end
        end
    end

endmodule
