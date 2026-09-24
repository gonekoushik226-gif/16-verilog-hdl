# 063 — Full Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Beginner | `full_adder` | `src/half_adder.v`, `src/full_adder.v` | `tb/tb_full_adder.v` |

## 1. Objective

Build a full adder — one that accepts a carry-in — from two half adders,
the textbook construction, so it can be chained into multi-bit adders.

## 2. What the Design Does

`full_adder` takes bits `a`, `b`, `cin` and produces `sum = a XOR b XOR
cin` and `carry_out`, set whenever two or more of the three inputs are 1.
`{carry_out, sum}` equals the 2-bit binary value of `a + b + cin` (0–3).

## 3. Why It Is Useful

Accepting a carry-in is what makes a single-bit adder chainable: program
064 wires `carry_out` of each stage into `cin` of the next to build a
4-bit ripple-carry adder, and every later adder architecture in this
category (carry-lookahead, carry-select, Wallace tree, ...) is built from
full-adder cells at its core.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | first operand bit |
| `b` | input | 1 | second operand bit |
| `cin` | input | 1 | carry in from a lower-order stage |
| `sum` | output | 1 | `a XOR b XOR cin` |
| `carry_out` | output | 1 | carry to the next stage |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `sum1` | 1 | partial sum from the first half adder (`a XOR b`) |
| `carry1` | 1 | carry from the first half adder (`a AND b`) |
| `carry2` | 1 | carry from the second half adder (`sum1 AND cin`) |

## 6. Architecture

```
a,b --[half_adder ha1]-- sum1, carry1
sum1,cin --[half_adder ha2]-- sum, carry2
carry_out = carry1 OR carry2
```
At most one of the two half adders can produce a carry for any given
`a,b,cin` combination (proof: `carry1=1` requires `a=b=1`, which forces
`sum1=0`, so `ha2`'s inputs are `0,cin` and `carry2` can never also be 1),
so OR-ing them is safe and equivalent to majority(a,b,cin).

## 7. Module Hierarchy and Connections

```
full_adder
├── ha1 : half_adder (a, b) -> (sum1, carry1)
└── ha2 : half_adder (sum1, cin) -> (sum, carry2)
```

## 8. Verilog Concepts Used

* Module instantiation with named port connections.
* Building a wider-function module purely from two instances of a
  narrower one, with a top-level `assign` combining their outputs.

## 9. Source Code Explanation

```verilog
half_adder ha1 (.a(a),    .b(b), .sum(sum1), .carry(carry1));
half_adder ha2 (.a(sum1), .b(cin), .sum(sum), .carry(carry2));
assign carry_out = carry1 | carry2;
```
`ha1` adds `a` and `b`, giving a partial sum and possible carry. `ha2`
adds that partial sum to `cin`, giving the final `sum` and a second
possible carry. `carry_out` is 1 if either half adder saw both its inputs
set — exactly the majority function of `a`, `b`, `cin`.

## 10. Testbench Explanation

`tb_full_adder` drives all 8 combinations of `{a,b,cin}` (`i` = 0..7) and
compares `{carry_out,sum}` against the reference `a + b + cin` computed by
Verilog's own `+` on a 2-bit reg.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | all-zero | a=b=cin=0 | sum=0, carry_out=0 |
| 2 | single 1 (×3) | one of a/b/cin=1 | sum=1, carry_out=0 |
| 3 | two 1s (×3) | two of a/b/cin=1 | sum=0, carry_out=1 |
| 4 | all-one | a=b=cin=1 | sum=1, carry_out=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 063` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_full_adder` — **PASS**

```text
TEST PASSED: 8 checks
tb/tb_full_adder.v:43: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 5 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely combinational; no reset/clock.
* This two-half-adder construction is the clearest to read but not the
  smallest possible full adder (a direct sum-of-products form, used in
  program 064, needs one fewer gate level); both are logically identical.

## 14. Common Mistakes

* Using only one half adder and simply OR-ing in `cin` — that does not
  compute the correct 3-input sum.
* Forgetting `carry_out` needs an OR of *both* half-adder carries, not
  just the first one.

## 15. Possible Improvements

* Compare gate/cell count against the direct sum-of-products full adder
  used in program 064 (both are logically equivalent, but synthesis may
  map them to different numbers of cells before optimization).

## 16. What This Program Teaches

* Composing small modules to build a slightly larger one.
* Why "majority of three bits" is exactly what a carry-out computes.

## 17. Industry Relevance

The full adder is the universal building block of binary arithmetic
hardware; its instantiation pattern here (module reuse via named ports)
is the same technique used to build every hierarchical adder later in
this category.

## 18. How to Run

```bash
python3 scripts/run.py 063            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/063-full-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_adder.v src/full_adder.v tb/tb_full_adder.v
vvp build/sim.vvp +vcd
```
