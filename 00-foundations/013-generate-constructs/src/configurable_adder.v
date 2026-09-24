`timescale 1ns / 1ps

// configurable_adder
// ARCH selects the implementation at elaboration time with generate-if:
//   ARCH = 0 : explicit ripple-carry chain built with generate-for
//   ARCH = 1 : behavioural '+' (synthesis chooses the adder structure)
module configurable_adder #(
    parameter WIDTH = 8,
    parameter ARCH  = 0
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);

    generate
        if (ARCH == 0) begin : g_ripple
            wire [WIDTH:0] carry;          // carry[0] = cin, carry[WIDTH] = cout
            assign carry[0] = cin;
            genvar i;
            for (i = 0; i < WIDTH; i = i + 1) begin : g_stage
                assign sum[i]       = a[i] ^ b[i] ^ carry[i];
                assign carry[i + 1] = (a[i] & b[i]) | (carry[i] & (a[i] ^ b[i]));
            end
            assign cout = carry[WIDTH];
        end else begin : g_behavioral
            assign {cout, sum} = a + b + cin;
        end
    endgenerate

endmodule
