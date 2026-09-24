`timescale 1ns / 1ps

// shift_siso: serial-in, serial-out shift register. Each cycle, every
// bit moves one position toward the output, and serial_in enters at
// the opposite end -- so a bit fed in at cycle N appears on
// serial_out exactly WIDTH cycles later. A pure delay line.
module shift_siso #(
    parameter WIDTH = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire serial_in,
    output wire serial_out
);

    reg [WIDTH-1:0] shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) shreg <= {WIDTH{1'b0}};
        else        shreg <= {shreg[WIDTH-2:0], serial_in};
    end

    assign serial_out = shreg[WIDTH-1];

endmodule
