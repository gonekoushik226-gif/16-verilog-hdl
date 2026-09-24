`timescale 1ns / 1ps

// clock_divider_even: divides clk by DIV (DIV must be even) with an
// exact 50% duty cycle. A counter reaching HALF-1 (half the divisor)
// toggles the output -- since both the high and low phases last
// exactly HALF input cycles, the duty cycle is automatically 50% with
// no extra correction logic needed (unlike the odd-divisor case,
// program 115).
module clock_divider_even #(
    parameter DIV = 4   // must be even, >= 2
) (
    input  wire clk,
    input  wire rst_n,
    output reg  clk_out
);

    localparam HALF  = DIV / 2;
    localparam CNT_W = $clog2(HALF);

    reg  [CNT_W-1:0] cnt;
    wire [CNT_W-1:0] half_m1 = HALF - 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= {CNT_W{1'b0}};
            clk_out <= 1'b0;
        end else if (cnt == half_m1) begin
            cnt     <= {CNT_W{1'b0}};
            clk_out <= ~clk_out;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule
