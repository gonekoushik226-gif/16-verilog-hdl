`timescale 1ns / 1ps

// tick_generator: produces a single-cycle enable pulse ("tick") once
// every PERIOD clock cycles, instead of a derived slower clock (as
// programs 114/115 do). Downstream logic uses `tick` as a clock-enable
// on the *original* fast clock, avoiding the clock-tree and timing-
// closure problems that come from distributing many different derived
// clocks throughout a design.
module tick_generator #(
    parameter PERIOD = 10
) (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output wire tick
);

    reg [$clog2(PERIOD)-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cnt <= {$clog2(PERIOD){1'b0}};
        else if (en) begin
            if (cnt == PERIOD-1) cnt <= {$clog2(PERIOD){1'b0}};
            else                 cnt <= cnt + 1'b1;
        end
    end

    assign tick = en & (cnt == PERIOD-1);

endmodule
