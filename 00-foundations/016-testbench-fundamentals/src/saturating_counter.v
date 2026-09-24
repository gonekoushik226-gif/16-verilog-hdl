`timescale 1ns / 1ps

// saturating_counter
// Up/down counter that stops at 0 and at MAX instead of wrapping.
// Priority: clear > enable. Used as the DUT for the testbench template.
module saturating_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,     // asynchronous, active low
    input  wire             clear,     // synchronous clear
    input  wire             en,        // count enable
    input  wire             up,        // 1 = count up, 0 = count down
    output reg  [WIDTH-1:0] count,
    output wire             at_max,
    output wire             at_min
);

    localparam [WIDTH-1:0] MAX = {WIDTH{1'b1}};

    assign at_max = (count == MAX);
    assign at_min = (count == {WIDTH{1'b0}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {WIDTH{1'b0}};
        else if (clear)
            count <= {WIDTH{1'b0}};
        else if (en) begin
            if (up && !at_max)
                count <= count + 1'b1;
            else if (!up && !at_min)
                count <= count - 1'b1;
        end
    end

endmodule
