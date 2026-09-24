`timescale 1ns / 1ps

// fp_adder: IEEE-754 single-precision floating-point adder (educational
// subset). Supported: normal (non-zero, finite, non-subnormal) operands
// and zero, with round-to-nearest-even. NOT supported: NaN, +-Infinity,
// and subnormal (denormal) operands/results -- feeding any of those in
// produces an unspecified result, since fp_unpack/fp_align/
// fp_normalize_round only reason about the normal-number bit layout.
// This limitation is deliberate (see README.md SS13) to keep the design
// at a size where every stage can be derived and verified by hand.
module fp_adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result
);

    wire        signA, signB;
    wire [7:0]  expA, expB;
    wire [23:0] mantA, mantB;
    wire        zeroA, zeroB;

    fp_unpack ua (.in(a), .sign(signA), .exp(expA), .mant(mantA), .is_zero(zeroA));
    fp_unpack ub (.in(b), .sign(signB), .exp(expB), .mant(mantB), .is_zero(zeroB));

    wire        res_sign_align;
    wire [7:0]  common_exp;
    wire [26:0] larger_mant, smaller_mant_aligned;
    wire        op_sub;

    fp_align al (
        .signA(signA), .expA(expA), .mantA(mantA),
        .signB(signB), .expB(expB), .mantB(mantB),
        .res_sign(res_sign_align), .common_exp(common_exp),
        .larger_mant(larger_mant), .smaller_mant_aligned(smaller_mant_aligned), .op_sub(op_sub)
    );

    wire [27:0] raw_sum = op_sub
        ? ({1'b0, larger_mant} - {1'b0, smaller_mant_aligned})
        : ({1'b0, larger_mant} + {1'b0, smaller_mant_aligned});

    wire [7:0]  norm_exp;
    wire [22:0] norm_mant;
    wire        norm_is_zero;

    fp_normalize_round nr (
        .raw_sum(raw_sum), .in_exp(common_exp), .is_add(~op_sub),
        .out_exp(norm_exp), .out_mant(norm_mant), .result_is_zero(norm_is_zero)
    );

    // a-a (exact cancellation) rounds to +0 under round-to-nearest-even
    wire final_sign = norm_is_zero ? 1'b0 : res_sign_align;
    wire [31:0] normal_result = {final_sign, norm_exp, norm_mant};

    // zero operands bypass the align/normalize path entirely, since it
    // assumes both operands are nonzero normal numbers.
    assign result = (zeroA && zeroB) ? {signA & signB, 31'b0} :
                     zeroA            ? b :
                     zeroB            ? a :
                                        normal_result;

endmodule
