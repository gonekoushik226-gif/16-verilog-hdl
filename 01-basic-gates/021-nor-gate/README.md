# 021 — NOR Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `nor_gate` | `src/nor_gate.v` | `tb/tb_nor_gate.v` |

## 1. Objective

Implement a 2-input NOR gate and verify De Morgan's theorem
(`~(a | b) == ~a & ~b`) directly in the testbench.

## 2. What the Design Does

`nor_gate` drives `y = ~(a | b)`: the complement of OR. `y` is 1 only when
both inputs are 0.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 1 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 0 |

## 3. Why It Is Useful

NOR, like NAND, is functionally complete (demonstrated in 028). It is the
classic gate used to build SR latches (see 085) because cross-coupling two
NOR gates gives a stable bistable element with well-defined set/reset
behaviour.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `NOT (a OR b)` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ >=1 ]──[ NOT ]── y
 b ──┘
```

## 7. Module Hierarchy and Connections

```
tb_nor_gate
└── dut : nor_gate
```

## 8. Verilog Concepts Used

* Composed continuous assignment: `~(a | b)`.

## 9. Source Code Explanation

```verilog
module nor_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = ~(a | b);
endmodule
```

`a | b` computes the OR term, then `~` inverts the whole result in the same
continuous assignment.

## 10. Testbench Explanation

`tb_nor_gate` runs two passes over all 4 input combinations:

1. **Truth-table pass** — computes `expected = ~(a | b)` independently and
   compares against `y`.
2. **De Morgan pass** — re-drives the same combinations and checks
   `y === ~a & ~b`, the AND-of-complements identity.

Both passes print each row, track `errors`/`checks`, and finish with the
standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 0 |
| 3 | 1 | 0 | 0 |
| 4 | 1 | 1 | 0 |

Plus 4 De Morgan cross-checks over the same input space (8 checks total).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 021` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_nor_gate` — **PASS**

```text
a b | y
 0 0 | 1
 0 1 | 0
 1 0 | 0
 1 1 | 0
TEST PASSED: 8 checks
tb/tb_nor_gate.v:48: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* NOR, like NAND, is a single CMOS stage and is cheaper than a plain OR
  gate (OR is a NOR followed by an inverter).
* Purely combinational — no clock or reset.

## 14. Common Mistakes

* Writing `~a | b` instead of `~(a | b)` — precedence again changes the
  function entirely.
* Confusing NOR's "only true when everything is false" behaviour with
  NAND's "only false when everything is true" — they are duals, not the
  same shape of function.

## 15. Possible Improvements

* Build a 3-input NOR and compare with cascaded 2-input NOR gates.
* Use `nor_gate` as the sole building block for other gates (see 028), and
  later as the core of the cross-coupled SR latch (085).

## 16. What This Program Teaches

* Building a compound gate from two operators in one expression.
* De Morgan's theorem for OR, verified by simulation.

## 17. Industry Relevance

NOR gates are the building block of SR latches and, historically, of NOR
flash memory cells; NAND/NOR-based cell libraries dominate ASIC synthesis.

## 18. How to Run

```bash
python3 scripts/run.py 021
cd 01-basic-gates/021-nor-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/nor_gate.v tb/tb_nor_gate.v
vvp build/sim.vvp +vcd
```
