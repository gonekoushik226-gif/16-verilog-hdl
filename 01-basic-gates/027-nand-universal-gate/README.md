# 027 — NAND as a Universal Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Elementary | `nand_universal_top` | `src/nand2.v`, `src/nand_not.v`, `src/nand_and.v`, `src/nand_or.v`, `src/nand_xor.v`, `src/nand_universal_top.v` | `tb/tb_nand_universal_top.v` |

## 1. Objective

Prove, by construction and simulation, that NAND alone is functionally
complete: build NOT, AND, OR and XOR using nothing but 2-input NAND gates,
and check each one against Verilog's native operators.

## 2. What the Design Does

* `nand2` — the single primitive everything else is built from: `y = ~(a & b)`.
* `nand_not(a) = NAND(a, a)` — tying both inputs together turns NAND into NOT.
* `nand_and(a,b) = NOT(NAND(a,b))` — un-inverting a NAND gives AND.
* `nand_or(a,b) = NAND(NOT a, NOT b)` — De Morgan's theorem
  (`a | b == ~(~a & ~b)`) turned directly into gates.
* `nand_xor(a,b)` — the classic 4-NAND XOR:
  `n1=NAND(a,b); n2=NAND(a,n1); n3=NAND(b,n1); y=NAND(n2,n3)`.
* `nand_universal_top` wraps all four derived gates behind one port list
  driven by the same `a`, `b` for testing.

## 3. Why It Is Useful

Functional completeness of NAND is why real ASIC standard-cell libraries
can be — and historically were — built almost entirely from one gate
family (with NOR as the dual choice). Bench technicians and 74-series
designers exploited the same fact with 7400 quad-NAND chips: any function
could be wired using only NAND packages on hand.

## 4. Interface

All derived modules share the same 1-bit port style; the top wraps them:

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 1 | Operands (only `a` is used by the NOT path) |
| `y_not_a` | output | 1 | `NOT a`, built from NAND |
| `y_and` | output | 1 | `a AND b`, built from NAND |
| `y_or` | output | 1 | `a OR b`, built from NAND |
| `y_xor` | output | 1 | `a XOR b`, built from NAND |

No parameters.

## 5. Internal Signals

| Module | Signal | Purpose |
|---|---|---|
| `nand_and` | `n` | Raw NAND(a,b) before the final inversion |
| `nand_or` | `na`, `nb` | `NOT a`, `NOT b` (De Morgan inputs) |
| `nand_xor` | `n1`, `n2`, `n3` | The three intermediate NAND outputs |

## 6. Architecture

```
NOT:  a ──┬──[NAND]── y            (both NAND inputs tied to a)
          └──────────┘

AND:  a,b ──[NAND]── n ──[NAND(n,n)]── y   (NAND then NAND-as-NOT)

OR:   a ──[NAND(a,a)]── na ──┐
                              ├──[NAND]── y
      b ──[NAND(b,b)]── nb ──┘

XOR:  a,b ──[NAND]── n1 ─────────────┐
      a,n1 ──[NAND]── n2 ──┐         │
      b,n1 ──[NAND]── n3 ──┴─[NAND]──y
```

## 7. Module Hierarchy and Connections

```
tb_nand_universal_top
└── dut : nand_universal_top
    ├── u_not : nand_not
    │   └── u1 : nand2 (a=a, b=a)
    ├── u_and : nand_and
    │   ├── u1 : nand2 (a=a, b=b) -> n
    │   └── u2 : nand_not (a=n)
    │       └── u1 : nand2 (a=n, b=n)
    ├── u_or : nand_or
    │   ├── u1 : nand_not (a=a) -> na
    │   ├── u2 : nand_not (a=b) -> nb
    │   └── u3 : nand2 (a=na, b=nb)
    └── u_xor : nand_xor
        ├── u1 : nand2 (a=a, b=b)   -> n1
        ├── u2 : nand2 (a=a, b=n1)  -> n2
        ├── u3 : nand2 (a=b, b=n1)  -> n3
        └── u4 : nand2 (a=n2, b=n3) -> y
```

## 8. Verilog Concepts Used

* Building a hierarchy where every leaf is the *same* primitive module
  (`nand2`), instantiated with different connections to realize different
  functions.
* Reusing one derived module (`nand_not`) inside two others (`nand_and`,
  `nand_or`).
* Structural design entirely through module instantiation and named ports,
  with no `assign`/`always` anywhere except inside `nand2` itself.

## 9. Source Code Explanation

```verilog
// nand_not.v
nand2 u1 (.a(a), .b(a), .y(y));
```
Tying both NAND inputs to the same signal collapses `~(a & a)` to `~a`.

```verilog
// nand_and.v
wire n;
nand2    u1 (.a(a), .b(b), .y(n));
nand_not u2 (.a(n), .y(y));
```
`n` is the raw NAND result; inverting it with `nand_not` (itself one more
NAND) recovers AND.

```verilog
// nand_or.v
wire na, nb;
nand_not u1 (.a(a), .y(na));
nand_not u2 (.a(b), .y(nb));
nand2    u3 (.a(na), .b(nb), .y(y));
```
This is De Morgan's theorem read as a schematic: invert both inputs, then
NAND them, which equals `a | b`.

```verilog
// nand_xor.v
wire n1, n2, n3;
nand2 u1 (.a(a),  .b(b),  .y(n1));
nand2 u2 (.a(a),  .b(n1), .y(n2));
nand2 u3 (.a(b),  .b(n1), .y(n3));
nand2 u4 (.a(n2), .b(n3), .y(y));
```
Four NAND gates in the specific arrangement that produces XOR — no simpler
all-NAND network exists for two inputs.

## 10. Testbench Explanation

`tb_nand_universal_top` drives all 4 combinations of `a`, `b` through the
single `nand_universal_top` instance and, for each combination, checks all
four derived outputs against Verilog's native operators in the same
statement group: `y_not_a !== ~a`, `y_and !== (a & b)`, `y_or !== (a | b)`,
`y_xor !== (a ^ b)`. Each of the 4 combinations produces 4 checks (16
total); any mismatch names which derived gate failed. The run ends with
the standard pass/fail line.

## 11. Test Cases and Expected Results

| `a` | `b` | `~a` | `a&b` | `a\|b` | `a^b` |
|---|---|---|---|---|---|
| 0 | 0 | 1 | 0 | 0 | 0 |
| 0 | 1 | 1 | 0 | 1 | 1 |
| 1 | 0 | 0 | 0 | 1 | 1 |
| 1 | 1 | 0 | 1 | 1 | 0 |

All 4 input combinations, 4 functions each (16 checks), 100% of the input
space.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 027` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_nand_universal_top` — **PASS**

```text
a b | ~a  a&b  a|b  a^b
 0 0 |  1   0    0    0
 0 1 |  1   0    1    1
 1 0 |  0   0    1    1
 1 1 |  0   1    1    0
TEST PASSED: 16 checks
tb/tb_nand_universal_top.v:51: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Each derived gate uses more transistors/cells than the native operator
  would (e.g. AND-from-NAND is 2 NAND stages vs. 1 native AND cell); this
  program is about *proving completeness*, not about efficient
  implementation — synthesis tools would never choose this form on their
  own.
* Purely combinational — no clock or reset anywhere in the hierarchy.

## 14. Common Mistakes

* Trying to build XOR with only 2 or 3 NAND gates — it is not possible;
  4 is the minimum for 2-input XOR from NAND alone.
* Forgetting that `nand_not` needs *both* NAND inputs tied to the same
  signal — feeding it `a` and a constant would not produce `~a` in
  general.

## 15. Possible Improvements

* Add an NAND-only 2:1 multiplexer to show a fifth derived function.
* Count gates per construction and compare against a native-operator
  synthesis to quantify the overhead mentioned in §13.

## 16. What This Program Teaches

* Functional completeness of NAND, proven rather than asserted.
* How De Morgan's theorem maps directly onto gate substitutions.
* Building deep, reusable structural hierarchies from one leaf primitive.

## 17. Industry Relevance

Standard-cell ASIC libraries are NAND/NOR-centric (017-023 already covered
why); this program demonstrates the theoretical property — completeness —
that makes that industry practice possible at all.

## 18. How to Run

```bash
python3 scripts/run.py 027
cd 01-basic-gates/027-nand-universal-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_nand_universal_top.v
vvp build/sim.vvp +vcd
```
