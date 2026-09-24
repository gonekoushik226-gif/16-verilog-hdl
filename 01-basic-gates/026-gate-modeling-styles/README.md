# 026 — Gate Modeling Styles

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `majority_gate_level`, `majority_dataflow`, `majority_behavioral` | `src/majority_gate_level.v`, `src/majority_dataflow.v`, `src/majority_behavioral.v` | `tb/tb_majority_styles.v` |

## 1. Objective

Implement the same function three ways — structural (gate-level),
dataflow (`assign`), and behavioral (`always`) — and prove by simulation
that all three are logically identical, to make the three abstraction
levels of Verilog concrete.

## 2. What the Design Does

All three modules implement the 3-input **majority function**: `y = 1`
when at least 2 of `a`, `b`, `c` are 1.

| `a` | `b` | `c` | `y` |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 0 |
| 0 | 1 | 0 | 0 |
| 0 | 1 | 1 | 1 |
| 1 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 1 | 1 | 0 | 1 |
| 1 | 1 | 1 | 1 |

* `majority_gate_level` — instantiates `and`/`or` primitives directly,
  wiring the classic `y = ab + bc + ac` equation gate by gate.
* `majority_dataflow` — the same equation as one continuous assignment.
* `majority_behavioral` — describes the *algorithm* ("count the ones,
  compare to a threshold") in an `always @(*)` block instead of the
  equation.

## 3. Why It Is Useful

Real projects mix all three styles: gate-level for a hand-crafted
timing-critical cell, dataflow for glue logic and expressions, behavioral
for anything with a clear algorithm (arithmetic, FSMs, muxes). Knowing that
they compile to the same hardware — and how to prove it — is a prerequisite
for reading unfamiliar RTL and for equivalence checking.

## 4. Interface

Each module shares the same port list:

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b`, `c` | input | 1 | The three voters |
| `y` | output | 1 | 1 iff at least two of `a,b,c` are 1 |

No parameters.

## 5. Internal Signals

| Module | Signal | Purpose |
|---|---|---|
| `majority_gate_level` | `ab`, `bc`, `ac` | Named nets between the AND and OR primitives |
| `majority_dataflow` | none | Single expression |
| `majority_behavioral` | `ones` (reg [1:0]) | Running count of asserted inputs |

## 6. Architecture

```
Gate level:        a,b ──[AND]── ab ──┐
                    b,c ──[AND]── bc ──┼──[OR]── y
                    a,c ──[AND]── ac ──┘

Dataflow:           y = (a&b) | (b&c) | (a&c)     (one assign)

Behavioral:         ones = a+b+c ; y = (ones >= 2)  (one algorithm)
```

## 7. Module Hierarchy and Connections

```
tb_majority_styles
├── dut_gate       : majority_gate_level
├── dut_dataflow   : majority_dataflow
└── dut_behavioral : majority_behavioral
```

All three instances are driven by the same `a`, `b`, `c` registers so every
stimulus vector reaches all three implementations simultaneously.

## 8. Verilog Concepts Used

* Gate-level primitives (`and`, `or`) with explicit intermediate `wire`s.
* Continuous assignment with a full Boolean expression.
* `always @(*)` combinational block with implicit bit-width extension
  (`a + b + c` widened into a 2-bit count) and a `reg` output.
* Comparing three independently coded implementations against one
  reference value in a single testbench.

## 9. Source Code Explanation

```verilog
// majority_gate_level.v
wire ab, bc, ac;
and (ab, a, b);
and (bc, b, c);
and (ac, a, c);
or  (y, ab, bc, ac);
```
Each `and`/`or` line instantiates one built-in primitive; `ab`, `bc`, `ac`
are ordinary nets that only exist to connect the AND outputs to the OR
inputs — structurally identical to drawing the gate-level schematic.

```verilog
// majority_dataflow.v
assign y = (a & b) | (b & c) | (a & c);
```
The same three AND terms and the OR, but as one Boolean expression with no
named intermediate signals.

```verilog
// majority_behavioral.v
always @(*) begin
    ones = a + b + c;
    y = (ones >= 2'd2);
end
```
`a + b + c` adds the three 1-bit inputs as unsigned numbers (result 0–3);
the 2-bit `ones` register holds the count, and `y` is asserted once the
count reaches 2. This describes *what* is wanted ("at least two votes"),
not which gates to use — synthesis is free to choose either implementation
and both produce the same equation shown above.

## 10. Testbench Explanation

`tb_majority_styles` instantiates all three modules with shared `a, b, c`
inputs, drives all 8 combinations exhaustively with a `for` loop, computes
`expected = (a&b) | (b&c) | (a&c)` independently, and checks each of the
three outputs against `expected` (three checks per input combination, 24
checks total). Any mismatch names which style failed. The final line
follows the standard pass/fail contract.

## 11. Test Cases and Expected Results

All 8 input combinations (100% of the input space) are exercised, each
checked against all three implementations (see the truth table in §2).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 026` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_majority_styles` — **PASS**

```text
a b c | gate dataflow behavioral
  0 0 0  |   0       0        0
  0 0 1  |   0       0        0
  0 1 0  |   0       0        0
  0 1 1  |   1       1        1
  1 0 0  |   0       0        0
  1 0 1  |   1       1        1
  1 1 0  |   1       1        1
  1 1 1  |   1       1        1
TEST PASSED: 8 checks
tb/tb_majority_styles.v:56: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 14 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* All three styles synthesize to logically equivalent (though not
  necessarily identically-shaped) netlists; Yosys is free to re-optimize
  the behavioral count-based description into the same AND/OR structure
  as the other two, or something else with the same truth table.
* Purely combinational — no clock or reset in any of the three styles.

## 14. Common Mistakes

* Assuming gate-level code is always "faster" or "smaller" than behavioral
  code — modern synthesis optimizes based on the described *logic*, not
  the coding style; hand instantiating gates mostly matters when a specific
  cell (not just a specific function) must be used.
* Forgetting `@(*)` (or listing an incomplete sensitivity list) in the
  behavioral style, which would make simulation react only to some input
  changes while synthesis (which assumes full sensitivity) built a design
  that still reacts to any of them — a classic sim/synth mismatch.
* Sizing `ones` too small: a 1-bit `ones` register could not hold the value
  3, silently truncating the count.

## 15. Possible Improvements

* Add a fourth style using a `case` statement over `{a,b,c}` (truth-table
  style) for a fourth comparison point.
* Formally equivalence-check the three netlists with Yosys `equiv_make` /
  `equiv_induct` instead of only simulating (see 292).

## 16. What This Program Teaches

* The three levels of Verilog abstraction, side by side, for one function.
* That behavioral, dataflow and structural code are different descriptions
  of the same logic, not different logic.
* A testbench pattern for comparing several implementations at once.

## 17. Industry Relevance

Production RTL is almost always behavioral/dataflow; gate-level
instantiation survives for hand-tuned cells (memory compilers, clock
buffers, hard macros) and for gate-level netlists produced *by* synthesis
tools, which engineers still need to be able to read.

## 18. How to Run

```bash
python3 scripts/run.py 026
cd 01-basic-gates/026-gate-modeling-styles && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/majority_gate_level.v src/majority_dataflow.v src/majority_behavioral.v tb/tb_majority_styles.v
vvp build/sim.vvp +vcd
```
