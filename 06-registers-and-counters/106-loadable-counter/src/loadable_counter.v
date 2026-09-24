`timescale 1ns / 1ps

// loadable_counter: an up counter that can also be preset to an
// arbitrary value via `load`, and reports `tc` (terminal count) when it
// reaches the maximum representable value -- useful for chaining into a
// cascaded counter (program 109) or triggering a reload cycle.
module loadable_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             load,
    input  wire             en,
    input  wire [WIDTH-1:0] load_val,
    output reg  [WIDTH-1:0] count,
    output wire             tc
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     count <= {WIDTH{1'b0}};
        else if (load)  count <= load_val;
        else if (en)    count <= count + 1'b1;
    end

    assign tc = (count == {WIDTH{1'b1}});

endmodule
