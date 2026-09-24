`timescale 1ns / 1ps

// array_divider: WIDTH-bit unsigned restoring-division array. WIDTH
// cascaded div_cell_row stages, one per dividend bit (processed
// MSB-first): each stage shifts the next dividend bit into the running
// partial remainder, trial-subtracts the divisor, and either keeps the
// subtracted remainder (quotient bit 1) or restores the pre-subtraction
// value (quotient bit 0). This is the "unrolled in space" combinational
// counterpart of the iterative restoring-division algorithm — every
// stage is separate hardware instead of one stage reused over WIDTH
// clock cycles (see program 215 for the sequential version).
//
// Divide-by-zero contract (since this is purely combinational, there is
// no exception mechanism): when divisor=0, every trial subtraction
// never borrows, so quotient saturates to all-1s and remainder ends up
// equal to the original dividend; `div_by_zero` flags this case so a
// caller can detect and handle it.
module array_divider #(
    parameter WIDTH = 6
) (
    input  wire [WIDTH-1:0] dividend,
    input  wire [WIDTH-1:0] divisor,
    output wire [WIDTH-1:0] quotient,
    output wire [WIDTH-1:0] remainder,
    output wire             div_by_zero
);

    localparam ROWW = WIDTH + 1;

    wire [ROWW-1:0] rem [0:WIDTH];   // rem[0] = 0, rem[WIDTH] = final remainder
    wire [WIDTH-1:0] qbits;
    wire [ROWW-1:0]  divisor_ext = {1'b0, divisor};

    assign rem[0] = {ROWW{1'b0}};

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : row
            // shift in dividend bits MSB-first: row 0 uses dividend[WIDTH-1]
            wire [ROWW-1:0] shifted_in = {rem[i][ROWW-2:0], dividend[WIDTH-1-i]};
            div_cell_row #(.ROWW(ROWW)) r (
                .rem_in(shifted_in), .divisor(divisor_ext),
                .rem_out(rem[i+1]), .qbit(qbits[WIDTH-1-i])
            );
        end
    endgenerate

    assign quotient     = qbits;
    assign remainder    = rem[WIDTH][WIDTH-1:0];
    assign div_by_zero  = (divisor == {WIDTH{1'b0}});

endmodule
