`timescale 1ns / 1ps

// up_down_counter: WIDTH-bit counter with a direction control. up=1
// counts up (wrapping from all-ones to 0); up=0 counts down (wrapping
// from 0 to all-ones) -- unsigned add/subtract already wrap correctly
// with no special-case logic needed.
module up_down_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire             up,
    output reg  [WIDTH-1:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  count <= {WIDTH{1'b0}};
        else if (en) count <= up ? (count + 1'b1) : (count - 1'b1);
    end

endmodule
