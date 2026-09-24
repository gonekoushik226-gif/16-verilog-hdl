# 083 — Fixed-Point Arithmetic (Q-Format)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `fxp_unit` | `src/fxp_add_sat.v`, `src/fxp_mul.v`, `src/fxp_unit.v` | `tb/tb_fxp_unit.v` |

## 1. Objective

Represent fractional numbers using plain integer registers (Q-format
fixed point) and implement saturating addition and rounding, saturating
multiplication — the two operations that behave differently once
fractions are involved.

## 2. What the Design Does

`fxp_unit` operates on Q3.4 numbers (signed 8-bit raw code, real value =
code / 16). `fxp_add_sat` adds two such codes directly (valid because
both share the same scale) and clamps the result if it doesn't fit back
in 8 bits. `fxp_mul` multiplies two codes (which scales the result by an
extra factor of 16), rounds that scaled product back down to the correct
scale using round-half-up, then clamps if needed.

## 3. Why It Is Useful

Many embedded and DSP designs need fractional arithmetic without a
floating-point unit's cost. Fixed point represents fractions as scaled
integers — cheap in hardware — but needs explicit handling for two things
plain integer arithmetic doesn't have: results that don't fit the format
(saturation, so a runaway value clips instead of wrapping to a wildly
wrong sign) and results that need rescaling after multiply (rounding, so
precision loss is controlled rather than silently truncated).

## 4. Interface

**`fxp_unit`**

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 8, signed | Q3.4 operands |
| `op` | input | 1 | 0 = add, 1 = multiply |
| `result` | output | 8, signed | Q3.4 result |
| `overflow` | output | 1 | 1 if the true result had to be clamped |

Parameters: `WIDTH` (default 8), `FRAC` (default 4, fractional bits).

**`fxp_add_sat`** / **`fxp_mul`**: `a`, `b` in; `result`, `overflow` out.

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| (add) `ext[WIDTH:0]` | exact sum with one headroom bit, never itself overflows |
| (mul) `full_product[2*WIDTH-1:0]` | exact raw product, scale 2^(2·FRAC) |
| (mul) `rounded`, `shifted` | product after round-half-up bias and rescale shift |
| `MAXV`, `MINV` | the format's most-positive/most-negative representable codes |

## 6. Architecture

```
fxp_add_sat: ext = sign_extend(a) + sign_extend(b)         (WIDTH+1 bits, exact)
             overflow = ext[WIDTH] != ext[WIDTH-1]
             result   = overflow ? (ext[WIDTH] ? MINV : MAXV) : ext[WIDTH-1:0]

fxp_mul:     full_product = a * b                            (2*WIDTH bits, scale 2^(2*FRAC))
             rounded      = full_product + 2^(FRAC-1)         (round-half-up bias)
             shifted      = rounded >>> FRAC                  (back to scale 2^FRAC, arithmetic shift)
             overflow     = shifted > MAXV || shifted < MINV
             result       = overflow ? (shifted<0 ? MINV : MAXV) : shifted[WIDTH-1:0]
```
The add path needs no rescale (both operands already share one scale
factor), only overflow detection. The multiply path's raw product is
scaled by `2^(2*FRAC)`, so it must be shifted right by `FRAC` bits to
return to the format's own scale — that shift is where rounding
information is lost, hence the bias-before-shift rounding step.

## 7. Module Hierarchy and Connections

```
fxp_unit
├── u_add : fxp_add_sat (a, b) -> add_result, add_overflow
└── u_mul : fxp_mul (a, b)     -> mul_result, mul_overflow
      (op selects which pair reaches the output ports)
```

## 8. Verilog Concepts Used

* `signed` operands and an arithmetic right shift (`>>>`) so rounding
  and truncation behave correctly for negative fixed-point values.
* `localparam` constants (`MAXV`, `MINV`) built from bit concatenation
  rather than decimal literals, so they scale automatically with `WIDTH`.
* Overflow detection via comparing a widened exact intermediate's sign
  bits, the same headroom-bit technique used by program 068's
  `add_sub`.

## 9. Source Code Explanation

See the formulas in §6. `fxp_add_sat`'s overflow test
(`ext[WIDTH]!=ext[WIDTH-1]`) is the standard "does truncating to WIDTH
bits lose information" check: the exact sum fits back in WIDTH bits
exactly when its two most-significant bits already agree (pure
sign-extension). `fxp_mul`'s `1 <<< (FRAC-1)` bias is exactly half of one
least-significant-bit's worth of scale, added before the shift so values
exactly halfway between two representable codes round up rather than
truncating down — arithmetic (sign-preserving) right shift then performs
an exact floor division, and floor(x + 0.5) is the standard construction
for round-half-up at any sign of `x`.

## 10. Testbench Explanation

`tb_fxp_unit` runs 2000 random operand pairs for each of add and
multiply, converting operands to `real` values (exact here, since every
Q3.4 code is a multiple of the power-of-two fraction 1/16) to compute the
true mathematical result and cross-check the design's rounding/
saturation rules independently of the RTL's own bit-width choices, plus
directed cases that push results just past `MAXV`/`MINV` in both
directions for both operations, and exactly onto the boundary (no
overflow expected). An earlier version of this testbench computed
negative-value multiply rounding as round-half-*away-from-zero*
(`-$rtoi(-x+0.5)`) instead of the design's documented round-half-*up*
rule, which disagrees exactly at exact `.5` ties (e.g. `-2.5` rounds to
`-2` under round-half-up but `-3` under round-half-away-from-zero) —
caught by the random sweep and fixed to use the same floor-based
`(product + bias) >>> FRAC` construction as the RTL, which is the
correct implementation of the stated rounding rule.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | add, random | 2000 random `(a,b)` | matches real sum, saturated |
| 2 | multiply, random | 2000 random `(a,b)` | matches real product, rounded + saturated |
| 3 | add overflow, both directions | e.g. 6.25+6.25, -6.25+-6.25 | clamps to MAXV/MINV, overflow=1 |
| 4 | multiply overflow | e.g. 6.25*6.25=39.0625 | clamps to MAXV, overflow=1 |
| 5 | boundary, no overflow | MAXV+0, MINV+0 | passes through unchanged, overflow=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 083` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_fxp_unit` — **PASS**

```text
TEST PASSED: 4010 checks
tb/tb_fxp_unit.v:109: $finish called at 4010000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 520 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Round-half-up (ties toward +infinity) was chosen for `fxp_mul` because
  it is the cheapest correct-rounding construction in hardware (one
  add, one shift); round-to-nearest-even would need extra logic to
  detect exact ties and is not implemented here.
* `fxp_add_sat` needs no rounding since Q-format addition at a shared
  scale is always exact — only `fxp_mul`'s rescale step loses precision.

## 14. Common Mistakes

* Using `$rtoi` (which truncates toward zero) directly on a real value
  as if it computed "round to nearest" — it does not, and for negative
  numbers this silently implements a different rounding convention than
  intended (documented above as the actual bug found in this program's
  own testbench during development).
* Using a logical (`>>`) instead of arithmetic (`>>>`) right shift in
  `fxp_mul` — a logical shift does not sign-extend and silently corrupts
  negative products.

## 15. Possible Improvements

* Add saturating subtract and a divide operation.
* Support configurable rounding modes (truncate, round-to-nearest-even).

## 16. What This Program Teaches

* Q-format fixed-point representation: scaled integers standing in for
  fractional values.
* Why multiplication (but not addition) needs an explicit rescale/round
  step, and how to implement round-half-up correctly for signed values.
* Saturating arithmetic as an alternative to silent wraparound.

## 17. Industry Relevance

Fixed-point arithmetic is standard in DSP, audio, graphics, and other
embedded pipelines where a floating-point unit is too costly or too slow;
saturation and rounding rules exactly like these appear throughout real
audio/video/control-system hardware to keep numeric errors bounded and
predictable.

## 18. How to Run

```bash
python3 scripts/run.py 083            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/083-fixed-point-arithmetic && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/fxp_add_sat.v src/fxp_mul.v src/fxp_unit.v tb/tb_fxp_unit.v
vvp build/sim.vvp +vcd
```
