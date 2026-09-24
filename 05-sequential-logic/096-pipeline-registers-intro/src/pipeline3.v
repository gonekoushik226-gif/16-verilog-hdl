`timescale 1ns / 1ps

// pipeline3: three cascaded pipe_stage registers. Data entering on
// cycle N reaches the output on cycle N+3 -- a fixed 3-cycle latency --
// but a new input can be accepted every single cycle, since each stage
// only ever talks to its immediate neighbors. `valid` rides along the
// same three stages so a caller can tell, cycle by cycle, whether
// out_data corresponds to a real input or is still draining from reset.
module pipeline3 #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             in_valid,
    input  wire [WIDTH-1:0] in_data,
    output wire             out_valid,
    output wire [WIDTH-1:0] out_data
);

    wire             v1, v2;
    wire [WIDTH-1:0] d1, d2;

    pipe_stage #(.WIDTH(WIDTH)) stage1 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
        .out_valid(v1), .out_data(d1)
    );
    pipe_stage #(.WIDTH(WIDTH)) stage2 (
        .clk(clk), .rst_n(rst_n), .in_valid(v1), .in_data(d1),
        .out_valid(v2), .out_data(d2)
    );
    pipe_stage #(.WIDTH(WIDTH)) stage3 (
        .clk(clk), .rst_n(rst_n), .in_valid(v2), .in_data(d2),
        .out_valid(out_valid), .out_data(out_data)
    );

endmodule
