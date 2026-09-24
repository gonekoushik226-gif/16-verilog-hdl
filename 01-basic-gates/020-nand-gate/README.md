# 020 — NAND Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Beginner | `nand_gate` | `src/nand_gate.v` | `tb/tb_nand_gate.v` |

## 1. Objective

Implement a 2-input NAND gate and verify De Morgan's theorem
(`~(a & b) == ~a | ~b`) directly in the testbench.

## 2. What the Design Does

`nand_gate` drives `y = ~(a & b)`: the complement of AND. `y` is 0 only when
both inputs are 1.

| `a` | `b` | `y` |
|---|---|---|
| 0 | 0 | 1 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

## 3. Why It Is Useful

NAND is functionally complete: any Boolean function can be built from NAND
gates alone (demonstrated in 027). It is also the fastest and smallest gate
in CMOS technology, which is why standard-cell libraries are built NAND-first
and synthesis tools frequently prefer NAND/NOR trees over AND/OR trees.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 1 | First operand |
| `b` | input | 1 | Second operand |
| `y` | output | 1 | `NOT (a AND b)` |

No parameters.

## 5. Internal Signals

None — the output is a direct function of the inputs.

## 6. Architecture

```
 a ──┐
     ├──[ & ]──[ NOT ]── y
 b ──┘
```

## 7. Module Hierarchy and Connections

```
tb_nand_gate
└── dut : nand_gate
```

## 8. Verilog Concepts Used

* Composed continuous assignment: `~(a & b)`.
* Operator precedence (`&` binds tighter than nothing else is needed here,
  but the explicit parentheses make the grouping unambiguous to the reader).

## 9. Source Code Explanation

```verilog
module nand_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = ~(a & b);
endmodule
```

`a & b` first computes the AND term, then `~` inverts it in the same
expression — there is no intermediate wire because the whole right-hand
side is one continuous assignment.

## 10. Testbench Explanation

`tb_nand_gate` runs two passes over all 4 input combinations:

1. **Truth-table pass** — computes `expected = ~(a & b)` independently and
   compares against `y`.
2. **De Morgan pass** — re-drives the same 4 combinations and checks
   `y === ~a | ~b`, proving the gate's output is consistent with the
   OR-of-complements identity, not just with one hand-computed formula.

Both passes print a row per case, use `errors`/`checks` counters, and the
run ends with the standard pass/fail line.

## 11. Test Cases and Expected Results

| # | `a` | `b` | Expected `y` |
|---|---|---|---|
| 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 1 |
| 3 | 1 | 0 | 1 |
| 4 | 1 | 1 | 0 |

Plus 4 De Morgan cross-checks over the same input space (8 checks total).

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 020` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_nand_gate` — **PASS**

```text
a b | y
 0 0 | 1
 0 1 | 1
 1 0 | 1
 1 1 | 0
TEST PASSED: 8 checks
tb/tb_nand_gate.v:48: $finish called at 8000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* NAND is a single CMOS gate (2 series NMOS + 2 parallel PMOS transistors)
  and is generally cheaper in silicon than an AND gate (AND is a NAND
  followed by an inverter).
* Purely combinational — no clock or reset.

## 14. Common Mistakes

* Writing `~a & b` instead of `~(a & b)` — operator precedence makes `~`
  bind to `a` alone, producing a completely different function.
* Forgetting that NAND is not associative/commutative-friendly the way AND
  is: `nand(nand(a,b),c)` is not the 3-input NAND of `a,b,c`.

## 15. Possible Improvements

* Build a 3-input NAND and show it differs from cascaded 2-input NANDs.
* Use `nand_gate` as the sole building block for other gates (see 027).

## 16. What This Program Teaches

* Building a compound gate from two operators in one expression.
* De Morgan's theorem verified by simulation, not just on paper.

## 17. Industry Relevance

Standard-cell ASIC libraries are NAND/NOR-centric because these gates are
smaller and faster than AND/OR in CMOS; synthesis tools map logic onto
NAND/NOR trees for this reason.

## 18. How to Run

```bash
python3 scripts/run.py 020
cd 01-basic-gates/020-nand-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/nand_gate.v tb/tb_nand_gate.v
vvp build/sim.vvp +vcd
```
