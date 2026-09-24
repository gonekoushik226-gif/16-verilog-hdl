`timescale 1ns / 1ps

// param_counter
// Modulo-MODULUS counter whose width is derived from its modulus.
//   parameter  : can be overridden by the instantiating module
//   localparam : internal constant, cannot be overridden
module param_counter #(
    parameter MODULUS = 10,                 // number of states, must be >= 2
    parameter WIDTH   = $clog2(MODULUS)     // derived default; override only to widen
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,             // count when high
    output reg  [WIDTH-1:0] count,
    output wire             wrap            // high while count is at its last value and en is high
);

    localparam integer LAST = MODULUS - 1;   // last count value

    assign wrap = en && (count == LAST[WIDTH-1:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {WIDTH{1'b0}};
        else if (en)
            count <= (count == LAST[WIDTH-1:0]) ? {WIDTH{1'b0}} : count + 1'b1;
    end

endmodule
