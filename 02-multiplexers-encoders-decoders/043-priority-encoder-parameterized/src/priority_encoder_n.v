`timescale 1ns / 1ps

// priority_encoder_n: parameterized N-bit priority encoder. A `for` loop
// scans every bit of d and keeps overwriting y with each set bit's index,
// so the direction of the scan decides which end wins ties: scanning low
// to high makes the last (highest-index) write win, scanning high to low
// makes the lowest-index write win. MSB_PRIORITY selects the scan
// direction, generalizing the fixed MSB-wins behaviour of
// priority_encoder4to2 (042).
module priority_encoder_n #(
    parameter N            = 8,        // number of request lines
    parameter MSB_PRIORITY = 1         // 1: highest set bit wins, 0: lowest set bit wins
) (
    input  wire [N-1:0]          d,
    output reg  [$clog2(N)-1:0]  y,
    output reg                   valid
);

    integer i;

    always @(*) begin
        y     = {$clog2(N){1'b0}};   // default assignment: avoids an inferred latch
        valid = |d;
        if (MSB_PRIORITY) begin
            for (i = 0; i < N; i = i + 1)
                if (d[i]) y = i[$clog2(N)-1:0];   // later (higher-index) hits overwrite earlier ones
        end else begin
            for (i = N - 1; i >= 0; i = i - 1)
                if (d[i]) y = i[$clog2(N)-1:0];   // later (lower-index) hits overwrite earlier ones
        end
    end

endmodule
