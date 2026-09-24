`timescale 1ns / 1ps

// register_n: a parameterized WIDTH-bit parallel-load register with
// enable and asynchronous active-low reset -- the direct generalization
// of program 087's single-bit D flip-flop to a whole data bus.
module register_n #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  q <= {WIDTH{1'b0}};
        else if (en) q <= d;
    end

endmodule
