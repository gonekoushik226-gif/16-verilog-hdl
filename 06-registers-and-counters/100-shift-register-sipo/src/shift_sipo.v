`timescale 1ns / 1ps

// shift_sipo: serial-in, parallel-out shift register -- assembles a
// serial bit stream into a full WIDTH-bit word, available continuously
// on parallel_out. msb_first selects which end of the word the first
// received bit ends up at: 1 = the first bit received becomes the
// word's MSB (new bits enter at the LSB and shift left); 0 = the first
// bit received becomes the LSB (new bits enter at the MSB and shift
// right).
module shift_sipo #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             serial_in,
    input  wire             msb_first,
    output wire [WIDTH-1:0] parallel_out
);

    reg [WIDTH-1:0] shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)         shreg <= {WIDTH{1'b0}};
        else if (msb_first) shreg <= {shreg[WIDTH-2:0], serial_in};
        else                shreg <= {serial_in, shreg[WIDTH-1:1]};
    end

    assign parallel_out = shreg;

endmodule
