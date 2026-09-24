# 030 — Boolean Function Implementation (SOP, POS, Minimized)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Elementary | `func_sop`, `func_pos`, `func_minimized` | `src/func_sop.v`, `src/func_pos.v`, `src/func_minimized.v` | `tb/tb_boolean_function.v` |

## 1. Objective

Take one 3-variable Boolean function from its truth table through
canonical sum-of-products (SOP), canonical product-of-sums (POS), and a
K-map-minimized form, and prove by exhaustive simulation that all three —
despite looking completely different — implement the same function.

## 2. What the Design Does

The function under study is `f(a,b,c) = Σm(0, 2, 5, 7)`:

| `a` | `b` | `c` | `f` |
|---|---|---|---|
| 0 | 0 | 0 | 1 |
| 0 | 0 | 1 | 0 |
| 0 | 1 | 0 | 1 |
| 0 | 1 | 1 | 0 |
| 1 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 1 | 1 | 0 | 0 |
| 1 | 1 | 1 | 1 |

* `func_sop` — canonical SOP: one AND term per 1-row, OR-ed together.
* `func_pos` — canonical POS: one OR term per 0-row (a maxterm), AND-ed
  together.
* `func_minimized` — the K-map-simplified form. Grouping the K-map shows
  `m0/m2` (a=0, c=0) form `a'c'` and `m5/m7` (a=1, c=1) form `ac`, so
  `f = a'c' + ac = ~(a ^ c)` — **`b` is entirely irrelevant** to the
  result, which the minimization process reveals but the canonical forms
  obscure.

## 3. Why It Is Useful

This is the complete classical combinational-design flow — truth table →
canonical forms → minimized implementation — condensed into one program,
with the added, very real lesson that minimization can eliminate an
input the truth table didn't obviously let go of.

## 4. Interface

All three modules share the same port list:

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b`, `c` | input | 1 | The three variables of `f` |
| `y` | output | 1 | `f(a,b,c)` |

No parameters.

## 5. Internal Signals

None — each module is a single Boolean expression.

## 6. Architecture

```
SOP:  y = a'b'c' + a'bc' + ab'c + abc            (4 AND terms, 1 OR)

POS:  y = (a+b+c')(a+b'+c')(a'+b+c)(a'+b'+c)     (4 OR terms, 1 AND)

MIN:  y = a'c' + ac  =  ~(a ^ c)                  (b unused)
```

## 7. Module Hierarchy and Connections

```
tb_boolean_function
├── dut_sop : func_sop
├── dut_pos : func_pos
└── dut_min : func_minimized
```

All three are driven by the same `a, b, c` registers; a fourth,
independent reference (a Verilog `function` with a `case` statement) is
evaluated inside the testbench itself.

## 8. Verilog Concepts Used

* Canonical SOP/POS expressed directly as continuous assignments.
* An unused module input (`b` in `func_minimized`) left in the port list
  on purpose, to compare all three modules with identical interfaces.
* A Verilog `function` with a `case` statement and a `default` branch,
  used inside a testbench as an independent oracle rather than as
  synthesizable RTL.

## 9. Source Code Explanation

```verilog
// func_sop.v
assign y = (~a & ~b & ~c) | (~a & b & ~c) | (a & ~b & c) | (a & b & c);
```
Each parenthesized term is one minterm (`m0`, `m2`, `m5`, `m7`); ORing them
reproduces exactly the 1-rows of the truth table.

```verilog
// func_pos.v
assign y = (a | b | ~c) & (a | ~b | ~c) & (~a | b | c) & (~a | ~b | c);
```
Each term is one maxterm (`M1`, `M3`, `M4`, `M6`) — a sum that evaluates to
0 for exactly one input combination where `f` is 0, and 1 everywhere else;
ANDing all four forces `y` to 0 exactly at those four rows.

```verilog
// func_minimized.v
assign y = ~(a ^ c);
```
The simplified equation. `b` remains a port (so the module's interface
matches `func_sop`/`func_pos`) but is not read by the logic — a directly
visible consequence of the K-map grouping, not a mistake.

## 10. Testbench Explanation

`tb_boolean_function` defines `reference_f`, a Verilog `function`
implementing the truth table directly with a `case` statement — a fourth,
independent representation of `f` that does not share any code with the
three RTL styles. It drives all 8 combinations of `{a,b,c}` exhaustively,
evaluates `reference_f` for each, and compares all three DUT outputs
against it. Mismatches print an `ERROR:` line naming which implementation
failed; the run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

All 8 rows of the truth table in §2 (100% of the input space), each
checked against all three implementations (24 checks total).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 030` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_boolean_function` — **PASS**

```text
a b c | SOP POS MIN | truth-table
  0 0 0  |  1   1   1   |     1
  0 0 1  |  0   0   0   |     0
  0 1 0  |  1   1   1   |     1
  0 1 1  |  0   0   0   |     0
  1 0 0  |  0   0   0   |     0
  1 0 1  |  1   1   1   |     1
  1 1 0  |  0   0   0   |     0
  1 1 1  |  1   1   1   |     1
TEST PASSED: 24 checks
tb/tb_boolean_function.v:69: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 24 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `func_minimized` synthesizes to noticeably fewer cells than `func_sop`
  or `func_pos` — the whole point of minimization is a smaller, faster
  circuit with identical behaviour.
* `func_minimized` never reads `b` inside its logic (see §2), even though
  it stays in the port list; the repository's default Verilator invocation
  does not flag unused ports at this warning level, but a stricter lint
  configuration (`-Wall`) would, and correctly so — this is the intended,
  provable-from-the-K-map observation, not a defect.
* Purely combinational — no clock or reset in any of the three modules.

## 14. Common Mistakes

* Reading a K-map in the wrong (non-Gray-code) column/row order, which
  makes adjacent-cell grouping invisible and produces a non-minimal or
  incorrect simplification.
* Deriving POS maxterms with the complementation backwards (maxterm `Mi`
  complements the variables that are **1** in `i`'s binary form, the
  opposite convention from SOP minterms).
* Assuming every minimization removes a variable entirely — that outcome
  is specific to this function's structure, not a general property of
  K-map simplification.

## 15. Possible Improvements

* Add a fourth style built from `case`/`casez` statements directly (moving
  from "algebra" to "table lookup" as a fourth representation).
* Re-run the same flow on a function with don't-cares to show how they
  relax the minimized grouping further.

## 16. What This Program Teaches

* The full truth-table → SOP → POS → minimized design flow in one place.
* That algebraically different-looking equations can be exactly the same
  function, provable by exhaustive simulation.
* That minimization can reveal a variable is functionally irrelevant.

## 17. Industry Relevance

Logic synthesis tools perform exactly this minimization (and far more
sophisticated variants, e.g. Espresso-style two-level minimization or
multi-level optimization) automatically; understanding the by-hand version
is what makes synthesized netlists and area/timing reports interpretable.

## 18. How to Run

```bash
python3 scripts/run.py 030
cd 01-basic-gates/030-boolean-function-implementation && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_boolean_function.v
vvp build/sim.vvp +vcd
```
