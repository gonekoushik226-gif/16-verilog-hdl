`timescale 1ns / 1ps

// div_cell_row: one row of a restoring-division array — a single trial
// subtraction with restore. Given the current partial remainder shifted
// in with the next dividend bit (rem_in) and the (zero-extended)
// divisor, it computes rem_in - divisor with a bit-serial borrow chain
// (an array of single-bit subtract cells, hence "row" of the larger
// divider "array"). If the subtraction borrows (rem_in < divisor), the
// trial result is discarded and rem_in is kept unchanged ("restoring")
// and the quotient bit for this row is 0; otherwise the subtracted
// value is kept and the quotient bit is 1.
module div_cell_row #(
    parameter ROWW = 7   // = dividend/divisor WIDTH + 1 (headroom for the shifted-in bit)
) (
    input  wire [ROWW-1:0] rem_in,
    input  wire [ROWW-1:0] divisor,   // divisor, zero-extended to ROWW bits
    output reg  [ROWW-1:0] rem_out,
    output reg              qbit
);

    // procedural borrow-chain loop (rather than a generate loop writing
    // per-bit assigns into a shared vector) to avoid a Verilator
    // UNOPTFLAT false positive on the apparent circular dependency of
    // overlapping vector slices — the same fix used in program 075.
    integer i;
    reg [ROWW:0] borrow;
    reg [ROWW-1:0] diff;

    always @(*) begin
        borrow[0] = 1'b0;
        for (i = 0; i < ROWW; i = i + 1) begin
            diff[i]      = rem_in[i] ^ divisor[i] ^ borrow[i];
            borrow[i+1]  = (~rem_in[i] & divisor[i])
                         | (~rem_in[i] & borrow[i])
                         | (divisor[i] & borrow[i]);
        end
        if (borrow[ROWW]) begin
            qbit    = 1'b0;
            rem_out = rem_in;
        end else begin
            qbit    = 1'b1;
            rem_out = diff;
        end
    end

endmodule
