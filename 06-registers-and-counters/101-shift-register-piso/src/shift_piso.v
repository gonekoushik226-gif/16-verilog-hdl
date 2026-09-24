`timescale 1ns / 1ps

// shift_piso: parallel-in, serial-out shift register -- the reverse of
// program 100's SIPO. `load` captures a full WIDTH-bit word in one
// cycle; `shift_en` then serializes it out MSB-first, one bit per
// cycle, with 0 filling in behind as bits leave.
module shift_piso #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             load,
    input  wire             shift_en,
    input  wire [WIDTH-1:0] parallel_in,
    output wire             serial_out
);

    reg [WIDTH-1:0] shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        shreg <= {WIDTH{1'b0}};
        else if (load)     shreg <= parallel_in;
        else if (shift_en) shreg <= {shreg[WIDTH-2:0], 1'b0};
    end

    assign serial_out = shreg[WIDTH-1];

endmodule
