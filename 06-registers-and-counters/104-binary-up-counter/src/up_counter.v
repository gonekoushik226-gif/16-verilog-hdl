`timescale 1ns / 1ps

// up_counter: free-running WIDTH-bit binary up counter with a
// clock-enable. Wraps from all-ones back to 0 with no special handling
// -- unsigned addition already does the right thing.
module up_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)  count <= {WIDTH{1'b0}};
        else if (en) count <= count + 1'b1;
    end

endmodule
