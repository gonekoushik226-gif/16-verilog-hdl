`timescale 1ns / 1ps

// mod_n_counter: counts 0..MOD-1 and wraps back to 0, for an arbitrary
// (not necessarily power-of-two) modulus. $clog2 sizes the count
// register from the parameter itself rather than requiring the width
// to be specified separately and kept consistent by hand.
module mod_n_counter #(
    parameter MOD = 10
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    en,
    output reg  [$clog2(MOD)-1:0]  count,
    output wire                    tc      // terminal count: about to wrap
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= {$clog2(MOD){1'b0}};
        else if (en) begin
            if (count == MOD-1) count <= {$clog2(MOD){1'b0}};
            else                count <= count + 1'b1;
        end
    end

    assign tc = (count == MOD-1);

endmodule
