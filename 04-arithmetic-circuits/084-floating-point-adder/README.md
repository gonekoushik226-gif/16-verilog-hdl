# 084 — IEEE-754 Single-Precision Floating-Point Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Expert | `fp_adder` | `src/fp_unpack.v`, `src/fp_align.v`, `src/fp_normalize_round.v`, `src/fp_adder.v` | `tb/tb_fp_adder.v` |

## 1. Objective

Implement the classic four-stage floating-point add pipeline —
unpack, align, add/subtract, normalize-and-round — for IEEE-754
single-precision, closing out this category with the most involved
arithmetic circuit in it.

## 2. What the Design Does

`fp_adder` adds two 32-bit IEEE-754 single-precision numbers `a`, `b`
and produces their correctly-rounded 32-bit sum `result`. It unpacks
each operand into sign/exponent/24-bit significand, right-shifts the
smaller-magnitude operand's significand to align it with the larger
exponent (folding shifted-out bits into a sticky bit), adds or
subtracts the two aligned significands depending on whether the signs
agree, and renormalizes plus rounds (round-to-nearest-even) the raw
result back into IEEE-754 form.

## 3. Why It Is Useful

Floating point lets a fixed-width word represent a huge dynamic range at
the cost of doing more work per operation than fixed-point (program
083): every add has to account for the two operands potentially having
wildly different scales, and the result has to be renormalized and
correctly rounded afterward. This program builds that entire pipeline
from first principles, one stage at a time.

## 4. Interface

**`fp_adder`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 32 | IEEE-754 single-precision operands |
| `result` | output | 32 | IEEE-754 single-precision sum, round-to-nearest-even |

**`fp_unpack`**: `in` in; `sign`, `exp[7:0]`, `mant[23:0]`, `is_zero` out.
**`fp_align`**: both operands' unpacked fields in; `res_sign`,
`common_exp`, `larger_mant[26:0]`, `smaller_mant_aligned[26:0]`, `op_sub`
out.
**`fp_normalize_round`**: `raw_sum[27:0]`, `in_exp`, `is_add` in;
`out_exp`, `out_mant[22:0]`, `result_is_zero` out.

**Documented scope (educational subset):** supported operand/result
classes are normal (non-zero, finite, non-subnormal) numbers and zero.
**NaN, +-Infinity, and subnormal numbers are not supported** — feeding
any of those in produces an unspecified result, since every stage
reasons about the normal-number bit layout (implicit leading 1,
biased-but-in-range exponent). This is stated plainly rather than
silently claimed to be a full IEEE-754 implementation.

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `signA/B`, `expA/B`, `mantA/B`, `zeroA/B` | each operand's unpacked fields |
| `res_sign_align`, `common_exp`, `larger_mant`, `smaller_mant_aligned`, `op_sub` | `fp_align`'s outputs |
| `raw_sum[27:0]` | the aligned significands added or subtracted |
| `norm_exp`, `norm_mant`, `norm_is_zero` | `fp_normalize_round`'s outputs |

## 6. Architecture

```
a --[fp_unpack]-- signA,expA,mantA,zeroA
b --[fp_unpack]-- signB,expB,mantB,zeroB
              |
        [fp_align] -- res_sign, common_exp, larger_mant, smaller_mant_aligned, op_sub
              |
   raw_sum = op_sub ? larger_mant - smaller_mant_aligned
                     : larger_mant + smaller_mant_aligned
              |
     [fp_normalize_round] -- norm_exp, norm_mant, norm_is_zero
              |
   result = zero-operand bypass, else {final_sign, norm_exp, norm_mant}
```
Bit layout of the 27-bit aligned significands: bit 26 = implicit leading
1 (for the unshifted, larger operand), bits 25:3 = the 23 explicit
mantissa bits, bits 2:0 = extra precision (guard bits), with any bits
shifted out during alignment OR-folded into bit 0 as a sticky flag.

## 7. Module Hierarchy and Connections

```
fp_adder
├── ua : fp_unpack (a) -> signA, expA, mantA, zeroA
├── ub : fp_unpack (b) -> signB, expB, mantB, zeroB
├── al : fp_align (signA/expA/mantA, signB/expB/mantB)
│          -> res_sign_align, common_exp, larger_mant, smaller_mant_aligned, op_sub
└── nr : fp_normalize_round (raw_sum, common_exp, ~op_sub)
           -> norm_exp, norm_mant, norm_is_zero
```

## 8. Verilog Concepts Used

* A Verilog `function` (`shift_sticky` in `fp_align`) implementing a
  variable-amount right shift with sticky-bit accumulation, called on
  whichever operand `fp_align` determines is smaller.
* A priority (leading-one-search) loop in `fp_normalize_round`, using a
  `found` flag to stop updating `shift_amt` once the first set bit is
  located — the standard idiom for "first match" logic in a procedural
  `for` loop, since Verilog has no `break`.
* Default assignments (`found`, `shift_amt`, `i` set before the
  if/elseif chain) needed specifically because those signals are only
  driven inside one conditional branch — without the defaults, Yosys
  correctly inferred an unintended latch for each of them, caught by
  this repository's synthesis check and fixed by adding the defaults.
* Two-stage renormalization after rounding: rounding a maximal
  (all-ones) significand up can itself overflow into a new carry,
  requiring one more shift-and-increment step (`rounded[24]` check).

## 9. Source Code Explanation

`fp_unpack` is a direct field decode with an implicit-leading-1 restore
for non-zero values. `fp_align`'s `shift_sticky` function shifts a 27-bit
value right by a variable amount, computing whether any of the bits
being shifted out were 1 (via `val & ((1<<amt)-1)`, an OR-reduction of
exactly those bits) and OR-ing that single sticky flag into the result's
bit 0. `fp_adder` computes `raw_sum` with plain `+`/`-` on the aligned
27-bit fields (widened by one bit to `28` so an addition carry-out is
never lost). `fp_normalize_round` handles the three normalization cases
described in its own header comment (addition carry-out, exact
cancellation, subtraction leading-zero cancellation), then rounds the
24-bit significand using the standard guard+sticky round-to-nearest-even
rule: round up only when the guard bit is set *and* (sticky is set *or*
the significand's own LSB is 1) — the second condition is what makes
exact ties round to the *even* neighbor rather than always up.

## 10. Testbench Explanation

`tb_fp_adder` runs 17 directed cases with **hand-computed exact expected
bit patterns** — simple sums, addition-carry normalization (1.0+1.0),
subtraction cancellation to +0 (including operand order and sign
variations), zero-operand bypass in both operand positions, and a
same-exponent-difference-24 tie case (`2^24 + 1.0`) that specifically
exercises round-to-nearest-even's tie-to-even rule (the mathematically
exact sum `16777217.0` is exactly halfway between the two nearest
representable floats and must round to the even one, `16777216.0`,
unchanged from the first operand). It then drives 4000 random operand
pairs restricted to normal numbers (exponent field forced into `[1,254]`,
excluding the reserved all-0/all-1 exponent values this design does not
support), checking the result against the exact real-number sum
(reconstructed independently via `fp32_to_real`, which is exact for this
purpose since IEEE-754 values have exact real representations) within a
small relative tolerance — this validates overall correctness (sign,
exponent, magnitude, and rounding to within a few ULPs) without requiring
a second, independently-rounding real-to-fp32 packer in the
testbench.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | simple sum | 1.0 + 2.0 | 3.0 |
| 2 | addition carry-out | 1.0 + 1.0 | 2.0 |
| 3 | exact cancellation | 1.0 + (-1.0) | +0.0 |
| 4 | zero operand (either side) | 0.0 + 5.0, -5.0 + 0.0 | unchanged non-zero operand |
| 5 | -0.0 + -0.0 | both negative zero | -0.0 |
| 6 | round-to-even tie | 2^24 + 1.0 | 2^24 (unchanged; exact tie rounds to even) |
| 7 | random, normal operands | 4000 random `(a,b)` pairs | matches real sum within tolerance |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 084` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_fp_adder` — **PASS**

```text
TEST PASSED: 4018 checks
tb/tb_fp_adder.v:113: $finish called at 4018000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 2107 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* **This is an educational subset of IEEE-754**, not a compliant FPU:
  NaN, +-Infinity, and subnormal numbers are not handled (see §4). A
  production floating-point adder must special-case all of these.
* Round-to-nearest-even is implemented with a single guard bit plus one
  sticky bit (rather than the more commonly diagrammed separate
  guard/round/sticky triple) — this is mathematically sufficient: the
  guard bit is "the bit immediately below the kept LSB" and sticky is
  "OR of everything below that," which is exactly what round-to-nearest
  needs to distinguish exact ties from any other case.
* Only 4000 random cases (plus 17 directed ones) were run, checked with
  a tolerance rather than a fully independent bit-exact rounding
  re-implementation — this gives strong confidence in overall
  correctness (magnitude, sign, exponent, coarse rounding) but is not an
  exhaustive proof that every possible guard/sticky/tie pattern rounds
  correctly; the directed tie-case test (#6 above) spot-checks that
  specific behavior deliberately.

## 14. Common Mistakes

* Forgetting the extra headroom bit for addition's possible carry-out
  (sizing `raw_sum` at 27 instead of 28 bits) — two normalized
  significands, each already using the full 27-bit aligned width, can
  sum to a value needing one more bit.
* Using `$rtoi`/truncation-style rounding instead of a genuine
  guard+sticky round-to-nearest-even check — silently changes the
  rounding mode and produces wrong results specifically at tie cases
  (the exact bug class caught and fixed in program 083's testbench,
  avoided here by testing tie behavior directly).
* Not re-normalizing a second time after rounding overflows the
  significand (an all-ones mantissa rounding up to a clean power of two)
  — without the `rounded[24]` check, this case silently produces a
  corrupted result instead of the correct one-exponent-higher value.
* Forgetting default assignments for procedurally-computed helper
  variables used in only one branch of a conditional — produces an
  unintended latch, caught here by this repository's Yosys synthesis
  check (see §8).

## 15. Possible Improvements

* Add NaN/Infinity propagation and subnormal (denormal) number support
  for full IEEE-754 compliance.
* Add a matching `fp_sub`/comparison set and a floating-point multiplier.
* Replace the tolerance-based random check with a fully independent
  bit-exact reference model for exhaustive rounding verification.

## 16. What This Program Teaches

* The full unpack/align/compute/normalize-round floating-point pipeline.
* Why floating-point addition needs alignment (unlike fixed-point,
  where the scale is already shared) and why multiplication (program
  083) needs rounding instead.
* Correct guard+sticky round-to-nearest-even, including the tie-to-even
  case and the post-rounding renormalization corner case.
* How an unintended-latch synthesis check catches an incomplete
  conditional-assignment bug that simulation alone would not (since
  simulation only exercises the paths the testbench happens to hit).

## 17. Industry Relevance

This is, at reduced scope, exactly the pipeline every hardware
floating-point unit implements for addition — the same stages
(unpack/align/add-or-subtract/normalize-round) appear, with far more
edge-case handling and usually deep pipelining, in every CPU and GPU FPU
in production use.

## 18. How to Run

```bash
python3 scripts/run.py 084            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/084-floating-point-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/fp_unpack.v src/fp_align.v src/fp_normalize_round.v src/fp_adder.v tb/tb_fp_adder.v
vvp build/sim.vvp +vcd
```
