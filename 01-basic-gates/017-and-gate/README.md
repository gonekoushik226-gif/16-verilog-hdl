# 017 — AND Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `and_gate` | `src/and_gate.v` | `tb/tb_and_gate.v` |

## 1. Objective

Implement and exhaustively verify the most basic combinational primitive: a
2-input AND gate, using the dataflow `assign` style.

## 2. What the Design Does

`and_gate` drives `y = a & b`. `y` is 1 only when both inputs are 1;
otherwise `y` is 0.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

## 3. Why It Is Useful

AND is one of the two gates (with OR) needed to build any sum-of-products
Boolean function, and it is the basic "both conditions true" building block
used everywhere in RTL: enabling a register only when several conditions
hold, masking bits, forming address-range checks, etc.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `a AND b` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ & ]── y
 b ──┘
```

A single two-input AND gate; no internal state or hierarchy.

## 7. Module Hierarchy and Connections

```
tb_and_gate
└── dut : and_gate
```

The testbench drives `a`/`b` and observes `y` directly; there is no further
hierarchy.

## 8. Verilog Concepts Used

* `` `timescale `` directive.
* ANSI-style port list with `input wire` / `output wire`.
* Continuous assignment (`assign`) with the bitwise-AND operator `&`.

## 9. Source Code Explanation

```verilog
module and_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = a & b;
endmodule
```

* The port list declares two 1-bit inputs and one 1-bit output.
* `assign y = a & b;` continuously drives `y`: any change on `a` or `b` is
  reflected on `y` with no clock involved (pure combinational logic).
* `&` on 1-bit operands is the same as `&&` here, but `&` is used because
  this program is specifically about the bitwise gate operator that scales
  to buses (see 029), not the logical operator.

## 10. Testbench Explanation

`tb_and_gate` is exhaustive: since the gate has only 2 inputs, all 4 input
combinations are testable in one run.

1. `a`/`b` are `reg`, `y` is `wire`, connected to the DUT by name.
2. A `for` loop drives `{a, b}` through `2'b00 .. 2'b11` using the loop
   index `i`, waits `#1` for the combinational logic to settle, then
   computes `expected = a & b` independently (not by calling the DUT logic)
   and compares.
3. Every combination prints a row of the truth table; any mismatch prints
   an `ERROR:` line with time, inputs, expected and actual values, and
   increments `errors`.
4. The final line reports `TEST PASSED: 4 checks` or `TEST FAILED: ...`.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 0 | 1 | 0 |
| 3 | 1 | 0 | 0 |
| 4 | 1 | 1 | 1 |

All 4 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 017` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_and_gate` — **PASS**

```text
a b | y
 0 0 | 0
 0 1 | 0
 1 0 | 0
 1 1 | 1
TEST PASSED: 4 checks
tb/tb_and_gate.v:37: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* A single-gate design synthesizes to one library cell (or is absorbed into
  whatever it drives); there is no timing or area concern at this scale.
* No reset or clock is needed — this is pure combinational logic.

## 14. Common Mistakes

* Confusing bitwise `&` with logical `&&`: on 1-bit operands they agree, but
  on multi-bit buses `&` is per-bit while `&&` reduces each operand to a
  single truth value first.
* Forgetting the `#1` delay before sampling in the testbench, which would
  read stale values from before the stimulus change propagated (harmless
  here since there is no delay in the DUT, but it is the reproducible habit
  used throughout this repository).

## 15. Possible Improvements

* Widen to an N-bit bitwise AND (covered generically in 029).
* Show the gate-level primitive style (`and (y, a, b);`) alongside the
  dataflow style (covered in 026).

## 16. What This Program Teaches

* The minimal structure of a combinational Verilog module.
* Exhaustive (100% coverage) verification of a small truth table.
* The self-checking testbench contract used by every program in this
  repository.

## 17. Industry Relevance

Every synthesis tool maps `&` directly onto a technology AND cell (or folds
it into a larger gate); this is the same operator used to build enables,
masks and qualifiers in production RTL.

## 18. How to Run

```bash
python3 scripts/run.py 017            # compile, simulate, synthesize, lint
cd 01-basic-gates/017-and-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/and_gate.v tb/tb_and_gate.v
vvp build/sim.vvp +vcd
```
