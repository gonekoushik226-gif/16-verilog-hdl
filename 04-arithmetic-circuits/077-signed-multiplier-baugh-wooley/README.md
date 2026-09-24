# 077 — Signed Multiplier (Baugh-Wooley)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Advanced | `baugh_wooley_mult` | `src/baugh_wooley_mult.v` | `tb/tb_baugh_wooley_mult.v` |

## 1. Objective

Multiply two's-complement (signed) numbers using only AND gates and
ordinary addition — no sign-extension logic, no explicit subtraction —
by complementing a handful of partial-product bits and adding two fixed
correction bits, the Baugh-Wooley technique.

## 2. What the Design Does

`baugh_wooley_mult` multiplies two 4-bit two's-complement numbers into an
exact 8-bit two's-complement product, using the modified partial-product
array derived in this program's source comments (and rederived below)
rather than sign-extending both operands and running a wider unsigned
multiply.

## 3. Why It Is Useful

Program 076's array multiplier is unsigned-only: feeding it two's
complement operands directly gives wrong answers whenever either operand
is negative, because a negative bit's weight is *negative*, not positive.
Baugh-Wooley solves this with a small, fixed modification to the *same*
AND-and-add structure, avoiding both an explicit sign-extend-then-multiply
approach and any subtraction hardware.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | multiplicand, two's complement |
| `b` | input | 4 | multiplier, two's complement |
| `product` | output | 8 | `a * b`, exact two's complement (any signed 4x4 product fits in 8 bits) |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `row0..row2` | 4 each | partial-product rows for `a[0..2]`, with the `b[3]` column bit inverted |
| `row3` | 4 | partial-product row for `a[3]`, with the `b[0..2]` bits inverted and the corner (`a[3]&b[3]`) left positive |

## 6. Architecture

Deriving the algorithm: write `a = -a3*8 + A`, `b = -b3*8 + B` where `A`,
`B` are the unsigned value of each operand's low 3 bits. Expanding:
```
a*b = a3*b3*64 - a3*B*8 - b3*A*8 + A*B
```
The two negative terms share the same `x8` scale factor, so their sum
`S = a3*B + b3*A` (a 4-bit unsigned quantity) can be negated as a whole:
`-S = NOT(S, zero-extended to 5 bits) + 1`. Expanding that identity back
out distributes into: complement every individual bit of the two
partial-product rows that make up `S`, and add two fixed correction bits
— one at weight `2^4`, one at the sign position `2^7`. The corner term
`a3*b3*64` stays a plain positive AND (it was never part of `S`). Every
other partial product (`a[0..2]` times `b[0..2]`) is an ordinary,
uninverted AND, exactly as in program 076.

```
row0 = { ~(a0&b3), a0&b2, a0&b1, a0&b0 }
row1 = { ~(a1&b3), a1&b2, a1&b1, a1&b0 }
row2 = { ~(a2&b3), a2&b2, a2&b1, a2&b0 }
row3 = { a3&b3, ~(a3&b2), ~(a3&b1), ~(a3&b0) }

product = row0 + (row1<<1) + (row2<<2) + (row3<<3) + (1<<4) + (1<<7)   (mod 256)
```

## 7. Module Hierarchy and Connections

Single module; the four modified partial-product rows are combined with
Verilog's own `+`, which is valid here because the entire expression
resolves at 8-bit width, matching the mod-`2^8` arithmetic the derivation
above depends on for exactness.

## 8. Verilog Concepts Used

* Deriving a hardware algorithm algebraically from the two's-complement
  weighted-bit definition, rather than applying a memorized diagram —
  documented step by step in the source comments so the identity can be
  checked independently of the testbench.
* Selective bitwise complement of specific partial-product bits
  (`~(a[i]&b[3])`, `~(a[3]&b[j])`) alongside uninverted ones in the same
  concatenation.
* Relying on natural 8-bit modular wraparound of `+` to realize "add mod
  2^n" without any explicit truncation.

## 9. Source Code Explanation

See the derivation in §6 and the module's own header comment, which
carries the full algebraic derivation inline. The four `wire [3:0]`
rows are each a concatenation of one inverted MSB-adjacent bit (`row0-2`)
or three inverted low bits (`row3`) with the remaining plain AND bits, and
`product` sums all four rows (each pre-shifted to its row weight) plus the
two fixed correction constants.

## 10. Testbench Explanation

`tb_baugh_wooley_mult` exhaustively drives all 256 combinations of 4-bit
two's-complement `a` and `b`, comparing `product` (read back with
`$signed`) against Verilog's own `$signed(a) * $signed(b)` reference —
covering every sign combination (positive×positive, positive×negative,
negative×negative) and the most-negative-operand corner (`a=b=-8`).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 256 signed `(a,b)` combinations | `product == a*b` (signed) |
| 2 | negative × negative | a=-1,b=-1 | product=1 |
| 3 | positive × negative | a=1,b=-1 | product=-1 |
| 4 | most-negative corner | a=-8,b=-8 | product=64 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 077` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_baugh_wooley_mult` — **PASS**

```text
TEST PASSED: 256 checks
tb/tb_baugh_wooley_mult.v:45: $finish called at 256000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 70 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This derivation and its two correction-bit positions (`2^n`, `2^(2n-1)`)
  were verified by hand for `n=2` and then exhaustively for `n=4` by this
  program's own testbench — not taken on faith from a remembered diagram,
  since getting the correction weights wrong is a classic, easy-to-make
  mistake in this algorithm (an earlier by-hand check during development
  using the wrong correction weights failed on `a=b=-1`, which is exactly
  why this program's derivation is spelled out algebraically rather than
  just asserted).
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Inverting the wrong set of partial products (e.g. inverting the corner
  `a3&b3` term, which must stay positive) or placing the correction
  constants at the wrong bit weights — both produce answers that are
  *close* to correct (right for many inputs) but wrong for others, which
  is exactly the kind of bug only exhaustive testing reliably catches.
* Believing bitwise-inverting two rows individually is equivalent to
  inverting their *sum* — it is not in general (`NOT(x)+NOT(y) !=
  NOT(x+y)`); the correction constants exist precisely to reconcile that
  difference, and the derivation in §6 accounts for it algebraically.

## 15. Possible Improvements

* Generalize to a parameterized `WIDTH`, deriving the two correction bit
  positions (`2^WIDTH`, `2^(2*WIDTH-1)`) from the parameter.

## 16. What This Program Teaches

* The Baugh-Wooley algorithm for signed multiplication using only ANDs
  and ordinary addition.
* How to derive a bit-level hardware trick algebraically from first
  principles, and why exhaustive verification matters even for a
  "classic, well-known" circuit.

## 17. Industry Relevance

Baugh-Wooley multipliers are a standard technique for signed
multiplication in regular array/systolic multiplier layouts, avoiding the
extra sign-extension hardware (or the width/latency cost of multiplying
sign-extended operands) that a naive signed-multiply-via-unsigned-multiply
approach would need.

## 18. How to Run

```bash
python3 scripts/run.py 077            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/077-signed-multiplier-baugh-wooley && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/baugh_wooley_mult.v tb/tb_baugh_wooley_mult.v
vvp build/sim.vvp +vcd
```
