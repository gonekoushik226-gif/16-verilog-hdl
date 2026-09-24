`timescale 1ns / 1ps

// fp_align: identifies which of two unpacked (nonzero, normal) operands
// has the larger magnitude, right-shifts the *other* operand's
// significand by the exponent difference so both are expressed at the
// same (larger) exponent, and reports whether the effective operation
// is an addition (same sign) or subtraction (different signs) of
// magnitudes. Each 24-bit significand is extended with 3 low guard
// bits before shifting; any bits shifted out are OR-reduced into a
// single sticky bit folded into the result's own bit 0, which is
// sufficient (together with one more guard bit produced during
// normalization) to round correctly later, without needing to widen
// the datapath to the full possible exponent-difference range.
module fp_align (
    input  wire        signA,
    input  wire [7:0]  expA,
    input  wire [23:0] mantA,
    input  wire        signB,
    input  wire [7:0]  expB,
    input  wire [23:0] mantB,
    output wire         res_sign,               // sign of the larger-magnitude operand
    output wire [7:0]   common_exp,
    output wire [26:0]  larger_mant,             // unshifted, always has its bit 26 set
    output wire [26:0]  smaller_mant_aligned,    // right-shifted to common_exp, sticky-folded
    output wire          op_sub                   // 1 = effective subtraction, 0 = effective addition
);

    function [26:0] shift_sticky;
        input [26:0] val;
        input [7:0]  amt;
        reg   [26:0] shifted;
        reg          sticky;
        begin
            if (amt >= 8'd27) begin
                shifted = 27'b0;
                sticky  = |val;
            end else if (amt == 8'd0) begin
                shifted = val;
                sticky  = 1'b0;
            end else begin
                shifted = val >> amt;
                sticky  = |(val & ((27'b1 << amt) - 27'b1));
            end
            shift_sticky = shifted | {26'b0, sticky};
        end
    endfunction

    wire a_ge_b = (expA > expB) || ((expA == expB) && (mantA >= mantB));
    wire [7:0] exp_diff = a_ge_b ? (expA - expB) : (expB - expA);

    wire [26:0] mantA_ext = {mantA, 3'b000};
    wire [26:0] mantB_ext = {mantB, 3'b000};

    assign res_sign             = a_ge_b ? signA : signB;
    assign common_exp           = a_ge_b ? expA  : expB;
    assign larger_mant          = a_ge_b ? mantA_ext : mantB_ext;
    assign smaller_mant_aligned = shift_sticky(a_ge_b ? mantB_ext : mantA_ext, exp_diff);
    assign op_sub               = signA ^ signB;

endmodule
