`timescale 1ns / 1ps

// johnson_counter: a WIDTH-bit twisted-ring (Johnson) counter. Every
// enabled cycle, the register shifts left and the *inverted* MSB
// re-enters at the LSB -- unlike program 110's ring counter, this
// naturally self-starts from an all-zero reset and cycles through
// exactly 2*WIDTH distinct states (twice the register width) before
// repeating, since the inversion keeps injecting a new value each
// cycle instead of just rotating a fixed pattern.
//
// `decoded` is a one-hot decode of which of the 2*WIDTH states the
// counter currently holds: states 0..WIDTH-1 are the "filling" phase
// (0001, 0011, 0111, ... all-ones), states WIDTH..2*WIDTH-1 are the
// "draining" phase (1110, 1100, 1000, ... all-zero) -- exactly the two
// halves of the cycle described above.
module johnson_counter #(
    parameter WIDTH = 4
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,
    output reg  [WIDTH-1:0]     q,
    output reg  [2*WIDTH-1:0]   decoded
);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  q <= {WIDTH{1'b0}};
        else if (en) q <= {q[WIDTH-2:0], ~q[WIDTH-1]};
    end

    always @(*) begin
        decoded = {(2*WIDTH){1'b0}};
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (q == ((1 << (i+1)) - 1))
                decoded[i] = 1'b1;                                  // filling phase
            if (q == ({WIDTH{1'b1}} ^ ((1 << (i+1)) - 1)))
                decoded[WIDTH+i] = 1'b1;                             // draining phase
        end
    end

endmodule
