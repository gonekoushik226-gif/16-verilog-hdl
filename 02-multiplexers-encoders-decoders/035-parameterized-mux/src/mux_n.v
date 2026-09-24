`timescale 1ns / 1ps

// mux_n: fully parameterized N-to-1 multiplexer. Verilog-2005 ports cannot
// be arrays, so the N data inputs are passed as one flattened bus `data`
// (N*WIDTH bits, element i occupying bits [i*WIDTH +: WIDTH]) and picked
// out with an indexed part-select whose base is the runtime value `sel`.
module mux_n #(
    parameter WIDTH = 8,               // bits per data element
    parameter N     = 4                // number of data elements (must be a power of 2)
) (
    input  wire [$clog2(N)-1:0] sel,
    input  wire [N*WIDTH-1:0]   data,
    output wire [WIDTH-1:0]     y
);

    assign y = data[sel*WIDTH +: WIDTH];

endmodule
