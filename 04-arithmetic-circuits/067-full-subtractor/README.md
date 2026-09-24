# 067 — Full Subtractor

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Beginner | `full_subtractor` | `src/half_subtractor.v`, `src/full_subtractor.v` | `tb/tb_full_subtractor.v` |

## 1. Objective

Extend the half subtractor with a borrow-in, the subtraction counterpart
of program 063's full adder, built the same way from two half cells.

## 2. What the Design Does

`full_subtractor` takes `a`, `b`, `bin` and produces `diff = a XOR b XOR
bin` and `borrow_out`, set whenever the subtraction `a - b - bin` needs to
borrow from the next higher bit.

## 3. Why It Is Useful

A borrow-in is what makes a single-bit subtractor chainable into a
multi-bit subtractor, mirroring exactly how a carry-in makes a full adder
chainable — the structural parallel program 068 later exploits directly.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | minuend bit |
| `b` | input | 1 | subtrahend bit |
| `bin` | input | 1 | borrow in from a lower-order stage |
| `diff` | output | 1 | `a XOR b XOR bin` |
| `borrow_out` | output | 1 | borrow to the next stage |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `diff1` | 1 | partial difference from the first half subtractor (`a XOR b`) |
| `borrow1` | 1 | borrow from the first half subtractor |
| `borrow2` | 1 | borrow from the second half subtractor (`diff1`, `bin`) |

## 6. Architecture

```
a,b   --[half_subtractor hs1]-- diff1, borrow1
diff1,bin --[half_subtractor hs2]-- diff, borrow2
borrow_out = borrow1 OR borrow2
```
Mirrors program 063's full-adder construction exactly, with subtraction
in place of addition.

## 7. Module Hierarchy and Connections

```
full_subtractor
├── hs1 : half_subtractor (a, b) -> (diff1, borrow1)
└── hs2 : half_subtractor (diff1, bin) -> (diff, borrow2)
```

## 8. Verilog Concepts Used

* Module instantiation with named ports, composing two half-subtractor
  instances (same pattern as program 063's full adder).

## 9. Source Code Explanation

```verilog
half_subtractor hs1 (.a(a),     .b(b),   .diff(diff1), .borrow(borrow1));
half_subtractor hs2 (.a(diff1), .b(bin), .diff(diff),  .borrow(borrow2));
assign borrow_out = borrow1 | borrow2;
```
`hs1` computes `a - b`; `hs2` subtracts `bin` from that partial
difference. As with the full adder, at most one stage can borrow for any
given input combination, so ORing their borrow outputs correctly reports
whether the 3-operand subtraction needed a borrow.

## 10. Testbench Explanation

`tb_full_subtractor` drives all 8 combinations of `{a,b,bin}` and checks
`{borrow_out,diff}` against a signed 2-bit reference `a - b - bin`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | 0-0-0 | a=0,b=0,bin=0 | diff=0, borrow_out=0 |
| 2 | 0-0-1 | a=0,b=0,bin=1 | diff=1, borrow_out=1 |
| 3 | 1-1-1 | a=1,b=1,bin=1 | diff=1, borrow_out=1 |
| 4 | exhaustive | all 8 combinations | matches signed `a-b-bin` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 067` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_full_subtractor` — **PASS**

```text
TEST PASSED: 8 checks
tb/tb_full_subtractor.v:43: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 5 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely combinational; no reset/clock.
* Like program 064's full adder, this two-half-subtractor form is the
  clearest structural reading, not the minimal gate count.

## 14. Common Mistakes

* OR-ing only one half subtractor's borrow instead of both.
* Assuming subtractor chaining works identically to adder chaining in
  every respect — the borrow direction is the same (low to high bit), but
  the final borrow_out means "the whole result is negative", which is a
  different interpretation than an adder's carry_out.

## 15. Possible Improvements

* A direct sum-of-products single-level implementation (skip the two
  half-subtractor instances), as a gate-count comparison exercise.

## 16. What This Program Teaches

* The structural symmetry between adder and subtractor chaining.
* How borrow propagates through a multi-bit subtraction.

## 17. Industry Relevance

Standalone subtractor chains like this are mostly of educational value;
real datapaths almost always implement subtraction by reusing adder
hardware with two's-complement negation (program 068), which needs no
separate borrow-propagation logic at all.

## 18. How to Run

```bash
python3 scripts/run.py 067            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/067-full-subtractor && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_subtractor.v src/full_subtractor.v tb/tb_full_subtractor.v
vvp build/sim.vvp +vcd
```
