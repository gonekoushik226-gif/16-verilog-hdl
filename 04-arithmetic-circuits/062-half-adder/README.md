# 062 — Half Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Beginner | `half_adder` | `src/half_adder.v` | `tb/tb_half_adder.v` |

## 1. Objective

Build the smallest possible binary adder — one bit plus one bit, no
carry-in — and see how `sum`/`carry` map directly onto the XOR/AND gates
from category 01.

## 2. What the Design Does

`half_adder` takes two 1-bit inputs `a`, `b` and produces `sum = a XOR b`
and `carry = a AND b`. Together `{carry, sum}` is the 2-bit binary
representation of `a + b` (0, 1, 1, or 2).

## 3. Why It Is Useful

Every wider adder in this category (`full_adder`, ripple-carry chains,
carry-lookahead, etc.) is built from single-bit adder cells. The half
adder is the base case: it cannot accept a carry-in, which is exactly why
a *full* adder (program 063) is needed to chain these into a multi-bit
adder.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | first operand bit |
| `b` | input | 1 | second operand bit |
| `sum` | output | 1 | `a XOR b` |
| `carry` | output | 1 | `a AND b` |

## 5. Internal Signals

None — both outputs are direct functions of the inputs.

## 6. Architecture

```
a ---+---[XOR]--- sum
     |    |
b ---+----+
     |
     +----[AND]--- carry
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Continuous `assign` with bitwise operators `^` and `&`.
* Direct sum-of-half-adder-outputs correspondence to a 2-bit binary count.

## 9. Source Code Explanation

```verilog
assign sum   = a ^ b;
assign carry = a & b;
```
`sum` is 1 exactly when `a` and `b` differ (odd number of 1s — the XOR
truth table). `carry` is 1 only when both inputs are 1, the only case
where the 1-bit sum overflows into a second bit.

## 10. Testbench Explanation

`tb_half_adder` iterates `i` from 0 to 3, assigns `{a,b} = i[1:0]` so all
four input combinations are driven, and after each assignment computes
`expected = a + b` (a 2-bit reg, so Verilog's own `+` gives the reference
value) and compares it bit-for-bit against `{carry,sum}`.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | 0+0 | a=0,b=0 | sum=0, carry=0 |
| 2 | 0+1 | a=0,b=1 | sum=1, carry=0 |
| 3 | 1+0 | a=1,b=0 | sum=1, carry=0 |
| 4 | 1+1 | a=1,b=1 | sum=0, carry=1 |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 062` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_half_adder` — **PASS**

```text
TEST PASSED: 4 checks
tb/tb_half_adder.v:43: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 2 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Purely combinational, no reset/clock needed.
* Synthesizes to a single XOR and a single AND gate; Yosys generic
  synthesis reports 1 cell (the AND; the XOR is typically absorbed into
  the top-level output wire during generic mapping, or reported
  separately depending on optimization — either way there are no latches).

## 14. Common Mistakes

* Forgetting that a half adder has no carry-in, so it cannot be used
  directly as one stage of a multi-bit adder chain without also handling
  an incoming carry (that is exactly what program 063 fixes).
* Swapping the `sum`/`carry` equations (using AND for sum, XOR for carry)
  — always check against the truth table, not memory.

## 15. Possible Improvements

* None meaningful at this scope; the design is already minimal. See
  program 063 for the natural next step (adding a carry-in).

## 16. What This Program Teaches

* The direct hardware realization of 1-bit binary addition.
* How to write and read the simplest possible self-checking testbench.

## 17. Industry Relevance

Half/full adders are the atomic building block of every arithmetic unit
in a CPU or DSP datapath — multipliers, ALUs and dividers all ultimately
decompose into full-adder cells derived from this circuit.

## 18. How to Run

```bash
python3 scripts/run.py 062            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/062-half-adder && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/half_adder.v tb/tb_half_adder.v
vvp build/sim.vvp +vcd
```
