`timescale 1ns / 1ps

// pipe_stage: one generic register stage -- a WIDTH-bit D flip-flop
// bank plus a valid bit, the basic building block of a pipeline. Each
// stage simply registers whatever arrived at its input on the previous
// cycle; chaining several (program pipeline3.v) is what turns
// combinational latency into overlapped, higher-throughput stages.
module pipe_stage #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             in_valid,
    input  wire [WIDTH-1:0] in_data,
    output reg              out_valid,
    output reg  [WIDTH-1:0] out_data
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= {WIDTH{1'b0}};
        end else begin
            out_valid <= in_valid;
            out_data  <= in_data;
        end
    end

endmodule
