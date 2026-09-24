# 023 — XNOR Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `xnor_gate` | `src/xnor_gate.v` | `tb/tb_xnor_gate.v` |

## 1. Objective

Implement a 2-input XNOR gate and read it as the "equality detector" dual
of XOR's "difference detector".

## 2. What the Design Does

`xnor_gate` drives `y = ~(a ^ b)`. `y` is 1 exactly when `a` and `b` are
equal.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 1 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

## 3. Why It Is Useful

XNOR is the fundamental bit-equality comparator: an N-bit equality
comparator is built by XNOR-ing each corresponding bit pair and ANDing all
the results together. It also appears in Gray-code and LFSR feedback logic
where "same" rather than "different" needs to be detected.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `NOT (a XOR b)`, i.e. `a == b` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ =1 ]──[ NOT ]── y
 b ──┘
```

## 7. Module Hierarchy and Connections

```
tb_xnor_gate
└── dut : xnor_gate
```

## 8. Verilog Concepts Used

* Composed continuous assignment: `~(a ^ b)`.
* Verilog also provides a direct XNOR operator (`~^` or `^~`); this program
  uses the explicit `~(a ^ b)` form so the "invert the difference" reading
  is visible in the source.

## 9. Source Code Explanation

```verilog
module xnor_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = ~(a ^ b);
endmodule
```

`a ^ b` is 1 when the bits differ; inverting it makes `y` 1 when they are
equal — a single-bit equality comparator.

## 10. Testbench Explanation

`tb_xnor_gate` exhaustively drives all 4 combinations, computes
`expected = ~(a ^ b)` independently, waits `#1`, and compares. Mismatches
print an `ERROR:` line; the run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 0 |
| 3 | 1 | 0 | 0 |
| 4 | 1 | 1 | 1 |

All 4 cases (100% of the input space) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 023` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_xnor_gate` — **PASS**

```text
a b | y
 0 0 | 1
 0 1 | 0
 1 0 | 0
 1 1 | 1
TEST PASSED: 4 checks
tb/tb_xnor_gate.v:37: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Like XOR, XNOR needs more transistors than AND/OR/NAND/NOR in CMOS.
* Purely combinational — no clock or reset.

## 14. Common Mistakes

* Confusing XNOR's "equal" reading with AND's "both true" reading — they
  only agree when both inputs are 1; XNOR is also 1 when both are 0.
* Writing `~a ^ b` instead of `~(a ^ b)` — this computes a different
  function because `~` would bind to `a` alone (it happens to equal XNOR
  here only by the specific algebra of two operands, but is the wrong
  expression to generalize from — write the parentheses explicitly).

## 15. Possible Improvements

* Chain single-bit XNORs and AND the results to build an N-bit equality
  comparator (see 046/047).
* Compare against Verilog's built-in `~^`/`^~` operator for the same
  function.

## 16. What This Program Teaches

* The "equality" logic primitive, dual to XOR.
* The building block used by every bit-parallel comparator later in the
  repository.

## 17. Industry Relevance

XNOR trees implement equality comparison in every ALU and address decoder;
XNOR-based comparators are also used in content-addressable memories (see
149) and cache tag matching.

## 18. How to Run

```bash
python3 scripts/run.py 023
cd 01-basic-gates/023-xnor-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/xnor_gate.v tb/tb_xnor_gate.v
vvp build/sim.vvp +vcd
```
