# 066 — Half Subtractor

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Beginner | `half_subtractor` | `src/half_subtractor.v` | `tb/tb_half_subtractor.v` |

## 1. Objective

Build the subtraction counterpart of the half adder: `a - b` for single
bits with no borrow-in, introducing the `diff`/`borrow` pair that mirrors
`sum`/`carry`.

## 2. What the Design Does

`half_subtractor` takes 1-bit `a`, `b` and produces `diff = a XOR b`
(same equation as the half adder's `sum`) and `borrow = (NOT a) AND b` —
1 only when `a=0` and `b=1`, the one case where a bit must be borrowed
from a higher position to represent `a - b`.

## 3. Why It Is Useful

Subtraction hardware built this way mirrors addition hardware closely,
which is why program 068 shows both can share the same adder hardware
via two's-complement arithmetic. This program isolates the borrow logic
on its own first.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | minuend bit |
| `b` | input | 1 | subtrahend bit |
| `diff` | output | 1 | `a XOR b` |
| `borrow` | output | 1 | 1 when a bit must be borrowed (`a=0,b=1`) |

## 5. Internal Signals

None — both outputs are direct functions of the inputs.

## 6. Architecture

```
a ---+---[XOR]--- diff
     |    |
b ---+----+
     |
    [NOT]
     |
     +----[AND with b]--- borrow
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Continuous `assign` with `^`, `~`, `&`.
* Signed-comparison-free borrow logic derived directly from the 2-bit
  subtraction truth table.

## 9. Source Code Explanation

```verilog
assign diff   = a ^ b;
assign borrow = (~a) & b;
```
`diff` is identical in form to the half adder's `sum` — subtraction and
addition agree bitwise when there's no carry/borrow chain involved.
`borrow` is 1 only for `a=0,b=1` (0-1 = -1, representable only by
borrowing), the sole input combination where the 1-bit result cannot
stand alone.

## 10. Testbench Explanation

`tb_half_subtractor` drives all 4 combinations of `{a,b}` and compares
`{borrow,diff}` against a *signed* 2-bit reference `a - b` (so `0-1`
correctly evaluates to `-1`, i.e. `{borrow=1,diff=1}` in two's
complement), computed with Verilog's own signed subtraction.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | 0-0 | a=0,b=0 | diff=0, borrow=0 |
| 2 | 0-1 | a=0,b=1 | diff=1, borrow=1 |
| 3 | 1-0 | a=1,b=0 | diff=1, borrow=0 |
| 4 | 1-1 | a=1,b=1 | diff=0, borrow=0 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 066` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_half_subtractor` — **PASS**

```text
TEST PASSED: 4 checks
tb/tb_half_subtractor.v:43: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 2 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely combinational; no reset/clock.
* Like the half adder, this cannot accept a borrow-in, so it cannot be
  chained directly into a multi-bit subtractor (program 067 fixes this).

## 14. Common Mistakes

* Writing `borrow = a & (~b)` (swapped) — check the truth table: borrow
  only happens for `0 - 1`, not `1 - 0`.
* Confusing `diff` with a signed magnitude output — it is simply the
  low bit of the two's-complement difference, same as `sum` is for
  addition.

## 15. Possible Improvements

* None meaningful at this scope — see program 067 for the borrow-in
  extension.

## 16. What This Program Teaches

* The bitwise structure of binary subtraction and how it differs subtly
  from addition (only in the borrow/carry equation).

## 17. Industry Relevance

Dedicated subtractor cells are less common in modern datapaths than
two's-complement adder reuse (program 068), but understanding the
borrow logic here is prerequisite to understanding why that reuse trick
works.

## 18. How to Run

```bash
python3 scripts/run.py 066            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/066-half-subtractor && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_subtractor.v tb/tb_half_subtractor.v
vvp build/sim.vvp +vcd
```
