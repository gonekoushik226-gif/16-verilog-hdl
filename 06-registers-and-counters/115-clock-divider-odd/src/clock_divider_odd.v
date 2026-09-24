`timescale 1ns / 1ps

// clock_divider_odd: divides clk by N (N must be odd, >= 3) with an
// exact 50% duty cycle -- genuinely harder than the even case (program
// 114) because an odd divisor's half-period is not a whole number of
// input clock cycles. The trick: a counter spends the first HALF =
// (N-1)/2 cycles fully high and the last HALF cycles fully low, and
// during the *middle* cycle (cnt==HALF) clk_out directly follows the
// live `clk` signal itself, contributing exactly one half input-clock
// period of extra high time -- giving HALF full cycles + 1 half cycle
// = N/2 cycles high, exactly 50% of the N-cycle period. This was
// derived and checked by hand (see README.md SS6) before being coded,
// avoiding the more error-prone dual-edge-counter-and-AND technique
// sometimes used for the same problem.
module clock_divider_odd #(
    parameter N = 5   // must be odd, >= 3
) (
    input  wire clk,
    input  wire rst_n,
    output wire clk_out
);

    localparam HALF = (N-1) / 2;

    reg [$clog2(N)-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)             cnt <= {$clog2(N){1'b0}};
        else if (cnt == N-1)    cnt <= {$clog2(N){1'b0}};
        else                    cnt <= cnt + 1'b1;
    end

    assign clk_out = (cnt < HALF) ? 1'b1 : (cnt == HALF) ? clk : 1'b0;

endmodule
