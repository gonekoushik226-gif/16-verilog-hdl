`timescale 1ns / 1ps

// universal_shift_reg: a 74194-style universal shift register with 4
// modes selected by `mode`: hold, shift-right, shift-left, or parallel
// load -- combining programs 098-101's separate registers/shifters
// into one configurable block.
module universal_shift_reg #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [1:0]       mode,             // 00=hold 01=shift-right 10=shift-left 11=load
    input  wire             serial_in_left,   // enters at the LSB when shifting left
    input  wire             serial_in_right,  // enters at the MSB when shifting right
    input  wire [WIDTH-1:0] parallel_in,
    output reg  [WIDTH-1:0] q
);

    localparam MODE_HOLD  = 2'b00;
    localparam MODE_RIGHT = 2'b01;
    localparam MODE_LEFT  = 2'b10;
    localparam MODE_LOAD  = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= {WIDTH{1'b0}};
        else begin
            case (mode)
                MODE_HOLD:  q <= q;
                MODE_RIGHT: q <= {serial_in_right, q[WIDTH-1:1]};
                MODE_LEFT:  q <= {q[WIDTH-2:0], serial_in_left};
                MODE_LOAD:  q <= parallel_in;
            endcase
        end
    end

endmodule
