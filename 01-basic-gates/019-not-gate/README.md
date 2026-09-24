# 019 — NOT Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `not_gate` | `src/not_gate.v` | `tb/tb_not_gate.v` |

## 1. Objective

Implement an inverter and use it to observe how Verilog's 4-state logic
(`0`, `1`, `x`, `z`) propagates through a bitwise operator, not just the
2-valued truth table.

## 2. What the Design Does

`not_gate` drives `y = ~a`.

| `a` | `y` |
|---|---|
| 0 | 1 |
| 1 | 0 |
| x | x |
| z | x |

An unknown (`x`) input inverts to unknown. A high-impedance (`z`) input,
having no driven value the gate can read, is also treated as unknown and
inverts to `x` — `z` is a *bus* concept (no driver), not a valid logic
input to a gate.

## 3. Why It Is Useful

Inversion is used to build active-low control signals, complement data for
subtraction, and form NAND/NOR from AND/OR. Understanding that `x`/`z`
propagate through logic (rather than being simulator artifacts) is
essential for reading simulation waveforms and diagnosing uninitialized or
multiply-driven signals.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | Signal to invert |
| `y` | output | 1 | `NOT a` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the input.

## 6. Architecture

```
 a ──[ NOT ]── y
```

## 7. Module Hierarchy and Connections

```
tb_not_gate
└── dut : not_gate
```

## 8. Verilog Concepts Used

* Unary bitwise-NOT operator `~`.
* 4-state value literals `1'bx`, `1'bz`.
* A testbench `task` with `input` arguments to remove repetition
  (`check_one(a_value, expected_value)`).

## 9. Source Code Explanation

```verilog
module not_gate (
    input  wire a,
    output wire y
);
    assign y = ~a;
endmodule
```

`~` is applied bit-by-bit; on a 1-bit signal it is a plain inverter. Verilog
defines `~` over all four logic values: `~0=1`, `~1=0`, `~x=x`, `~z=x` (a
`z` has no defined logic level to complement, so the result is unknown).

## 10. Testbench Explanation

`tb_not_gate` defines a `check_one(av, ev)` task that drives `a = av`,
waits `#1`, and compares `y` against `ev` using `!==` (the case-equality
operator that treats `x`/`z` as ordinary values instead of always being
unknown, so the check itself works for 4-state expected values). It is
called for the two defined logic values (exhaustive 2-valued truth table)
and then for `1'bx` and `1'bz` to confirm 4-state propagation. Any mismatch
prints an `ERROR:` line; the run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | Expected `y` |
|---|---|---|
| 1 | 0 | 1 |
| 2 | 1 | 0 |
| 3 | x | x |
| 4 | z | x |

Cases 1–2 cover 100% of the driven-logic input space; cases 3–4 add the
4-state inputs a real testbench must also consider.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 019` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_not_gate` — **PASS**

```text
a | y
 a=0 | y=1
 a=1 | y=0
 a=x | y=x
 a=z | y=x
TEST PASSED: 4 checks
tb/tb_not_gate.v:43: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Synthesizable RTL never intentionally drives `x`/`z` from a gate; the
  x/z cases here are a simulation-only exploration of the 4-state model,
  not something a real inverter chip does (physical gates cannot output
  x/z; a floating physical input settles to some 0 or 1, unpredictably).
* Maps to a single library inverter cell.

## 14. Common Mistakes

* Using `==`/`!=` (logical equality) instead of `===`/`!==` (case equality)
  when a testbench must compare against `x`/`z`: `==` against an unknown
  operand always yields `x`, which is neither true nor false and can hide
  bugs.
* Assuming `~z` is `z` — it is not; a gate cannot output high-impedance
  unless it is explicitly a tri-state driver (see 025).

## 15. Possible Improvements

* Widen to an N-bit inverter and show `~` operating per-bit on a bus.
* Add a gate-level `not` primitive version for comparison (see 026).

## 16. What This Program Teaches

* The second basic dataflow gate.
* Verilog's 4-state value system and how it propagates through logic.
* `===`/`!==` case equality for testbench comparisons involving `x`/`z`.

## 17. Industry Relevance

`x` propagation through simulation is the primary way engineers catch
uninitialized registers, unconnected ports and multi-driver conflicts
before hardware is built; understanding it here is a prerequisite for
debugging any real design's waveforms.

## 18. How to Run

```bash
python3 scripts/run.py 019
cd 01-basic-gates/019-not-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/not_gate.v tb/tb_not_gate.v
vvp build/sim.vvp +vcd
```
