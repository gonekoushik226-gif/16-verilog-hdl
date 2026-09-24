`timescale 1ns / 1ps

// demux_n: parameterized 1-to-N demultiplexer. A generate-for loop creates
// one comparator+gate per output instead of writing N assign statements by
// hand (compare with the four hand-written assigns of demux1to4, 036).
// The N outputs are packed into one flattened bus y, output i occupying
// bits [i*WIDTH +: WIDTH], mirroring the flattened-input convention used
// for mux_n's data bus (035).
module demux_n #(
    parameter WIDTH = 8,               // bits per output element
    parameter N     = 4                // number of outputs (must be a power of 2)
) (
    input  wire [$clog2(N)-1:0] sel,
    input  wire [WIDTH-1:0]     d,
    output wire [N*WIDTH-1:0]   y
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : demux_out
            assign y[i*WIDTH +: WIDTH] = (sel == i) ? d : {WIDTH{1'b0}};
        end
    endgenerate

endmodule
