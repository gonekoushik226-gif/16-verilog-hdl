`timescale 1ns / 1ps

// prescaler: like program 116's tick_generator, but the divide ratio is
// a runtime input (reload_val) instead of a compile-time parameter --
// dividing by (reload_val+1). `tick` is registered, pulsing for one
// cycle the cycle *after* the internal counter reaches reload_val.
module prescaler #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire [WIDTH-1:0] reload_val,
    output reg              tick
);

    reg [WIDTH-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= {WIDTH{1'b0}};
            tick <= 1'b0;
        end else if (en) begin
            if (cnt == reload_val) begin
                cnt  <= {WIDTH{1'b0}};
                tick <= 1'b1;
            end else begin
                cnt  <= cnt + 1'b1;
                tick <= 1'b0;
            end
        end else begin
            tick <= 1'b0;
        end
    end

endmodule
