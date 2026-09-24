`timescale 1ns / 1ps

// fp_normalize_round: takes the raw (unnormalized) 28-bit magnitude sum
// or difference produced by adding/subtracting fp_align's two aligned
// significands, restores it to the normalized 1.xxxx form (implicit
// leading 1 at bit 26), and rounds it to 23 stored mantissa bits using
// round-to-nearest-even. Three cases are handled: an addition that
// carried out of bit 26 (shift right by one, exponent+1), an exact
// cancellation (result is zero), and a subtraction that left leading
// zeros (shift left by the leading-zero count, exponent decreases by
// the same amount). After rounding, a further carry out of the top
// mantissa bit (all-ones rounding up to a power of two) is handled by
// one more right-shift-and-increment step.
module fp_normalize_round (
    input  wire [27:0] raw_sum,
    input  wire [7:0]  in_exp,
    input  wire         is_add,          // 1 = came from same-sign addition, 0 = subtraction
    output reg  [7:0]  out_exp,
    output reg  [22:0] out_mant,
    output reg          result_is_zero
);

    integer i;
    reg [27:0] w;
    reg [8:0]  e;
    reg [4:0]  shift_amt;
    reg        found;
    reg [23:0] sig;
    reg        guard, sticky_bit;
    reg [24:0] rounded;

    always @(*) begin
        e         = {1'b0, in_exp};
        w         = raw_sum;
        found     = 1'b0;
        shift_amt = 5'd0;
        i         = 0;

        if (is_add && raw_sum[27]) begin
            // sum overflowed past the implicit-1 position: shift right one bit
            w    = {1'b0, raw_sum[27:1]};
            w[0] = w[0] | raw_sum[0];
            e    = e + 9'd1;
        end else if (raw_sum[26:0] == 27'b0) begin
            w = 28'b0;
        end else if (!raw_sum[26]) begin
            // subtraction cancellation: find the new leading 1 and shift left
            found     = 1'b0;
            shift_amt = 5'd0;
            for (i = 1; i <= 26; i = i + 1) begin
                if (!found && raw_sum[26-i]) begin
                    shift_amt = i[4:0];
                    found     = 1'b1;
                end
            end
            w = raw_sum << shift_amt;
            if (e > {4'b0, shift_amt}) e = e - {4'b0, shift_amt};
            else                        e = 9'd0;   // underflow: clamp (educational-subset limitation)
        end
        // else: raw_sum[26] already set -- already normalized, w/e keep their initial values

        sig        = w[26:3];
        guard      = w[2];
        sticky_bit = w[1] | w[0];

        if (guard && (sticky_bit || sig[0])) rounded = {1'b0, sig} + 25'd1;
        else                                  rounded = {1'b0, sig};

        if (rounded[24]) begin
            out_mant = rounded[23:1];
            out_exp  = e[7:0] + 8'd1;
        end else begin
            out_mant = rounded[22:0];
            out_exp  = e[7:0];
        end

        result_is_zero = (w == 28'b0);
        if (result_is_zero) begin
            out_mant = 23'b0;
            out_exp  = 8'b0;
        end
    end

endmodule
