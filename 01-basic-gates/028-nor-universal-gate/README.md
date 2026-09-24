# 028 — NOR as a Universal Gate

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 01-basic-gates | Elementary | `nor_universal_top` | `src/nor2.v`, `src/nor_not.v`, `src/nor_and.v`, `src/nor_or.v`, `src/nor_xnor.v`, `src/nor_universal_top.v` | `tb/tb_nor_universal_top.v` |

## 1. Objective

Prove that NOR alone is also functionally complete — the dual of program
027 — by building NOT, OR, AND and XNOR from nothing but 2-input NOR
gates, and check each against Verilog's native operators.

## 2. What the Design Does

* `nor2` — the single primitive everything else is built from: `y = ~(a | b)`.
* `nor_not(a) = NOR(a, a)` — tying both inputs together turns NOR into NOT.
* `nor_or(a,b) = NOT(NOR(a,b))` — un-inverting a NOR gives OR.
* `nor_and(a,b) = NOR(NOT a, NOT b)` — De Morgan's theorem
  (`a & b == ~(~a | ~b)`) turned directly into gates.
* `nor_xnor(a,b)` — four NOR gates in the same topology as the NAND-only
  XOR of 027: `n1=NOR(a,b); n2=NOR(a,n1); n3=NOR(b,n1); y=NOR(n2,n3)`.
  Because NOR is the De Morgan dual of NAND, the *same wiring pattern*
  that produces XOR from NAND produces **XNOR** from NOR — which is why
  this file is `nor_xnor.v`, not `nor_xor.v`.
* `nor_universal_top` wraps all four derived gates behind one port list.

## 3. Why It Is Useful

NOR is the other functionally-complete single-gate family, and the one
used to build the classic cross-coupled SR latch (see 085/086). Seeing
that the *identical* 4-gate XOR topology from 027 yields XNOR here (rather
than needing separate design work) is a concrete illustration of De
Morgan duality, not just an abstract theorem.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a`, `b` | input | 1 | Operands (only `a` is used by the NOT path) |
| `y_not_a` | output | 1 | `NOT a`, built from NOR |
| `y_and` | output | 1 | `a AND b`, built from NOR |
| `y_or` | output | 1 | `a OR b`, built from NOR |
| `y_xnor` | output | 1 | `a XNOR b`, built from NOR |

No parameters.

## 5. Internal Signals

| Module | Signal | Purpose |
|---|---|---|
| `nor_or` | `n` | Raw NOR(a,b) before the final inversion |
| `nor_and` | `na`, `nb` | `NOT a`, `NOT b` (De Morgan inputs) |
| `nor_xnor` | `n1`, `n2`, `n3` | The three intermediate NOR outputs |

## 6. Architecture

```
NOT:  a ──┬──[NOR]── y             (both NOR inputs tied to a)
          └─────────┘

OR:   a,b ──[NOR]── n ──[NOR(n,n)]── y   (NOR then NOR-as-NOT)

AND:  a ──[NOR(a,a)]── na ──┐
                             ├──[NOR]── y
      b ──[NOR(b,b)]── nb ──┘

XNOR: a,b ──[NOR]── n1 ─────────────┐
      a,n1 ──[NOR]── n2 ──┐         │
      b,n1 ──[NOR]── n3 ──┴─[NOR]───y
```

## 7. Module Hierarchy and Connections

```
tb_nor_universal_top
└── dut : nor_universal_top
    ├── u_not  : nor_not
    │   └── u1 : nor2 (a=a, b=a)
    ├── u_and  : nor_and
    │   ├── u1 : nor_not (a=a) -> na
    │   ├── u2 : nor_not (a=b) -> nb
    │   └── u3 : nor2 (a=na, b=nb)
    ├── u_or   : nor_or
    │   ├── u1 : nor2 (a=a, b=b) -> n
    │   └── u2 : nor_not (a=n)
    │       └── u1 : nor2 (a=n, b=n)
    └── u_xnor : nor_xnor
        ├── u1 : nor2 (a=a, b=b)   -> n1
        ├── u2 : nor2 (a=a, b=n1)  -> n2
        ├── u3 : nor2 (a=b, b=n1)  -> n3
        └── u4 : nor2 (a=n2, b=n3) -> y
```

## 8. Verilog Concepts Used

* Same structural, one-primitive-type hierarchy pattern as 027, applied to
  the dual gate.
* Reuse of a derived module (`nor_not`) inside two others (`nor_and`,
  `nor_or`).

## 9. Source Code Explanation

```verilog
// nor_not.v
nor2 u1 (.a(a), .b(a), .y(y));
```
Tying both NOR inputs to the same signal collapses `~(a | a)` to `~a`.

```verilog
// nor_or.v
wire n;
nor2    u1 (.a(a), .b(b), .y(n));
nor_not u2 (.a(n), .y(y));
```
`n` is the raw NOR result; inverting it recovers OR.

```verilog
// nor_and.v
wire na, nb;
nor_not u1 (.a(a), .y(na));
nor_not u2 (.a(b), .y(nb));
nor2    u3 (.a(na), .b(nb), .y(y));
```
De Morgan's theorem as a schematic: invert both inputs, then NOR them,
which equals `a & b`.

```verilog
// nor_xnor.v
wire n1, n2, n3;
nor2 u1 (.a(a),  .b(b),  .y(n1));
nor2 u2 (.a(a),  .b(n1), .y(n2));
nor2 u3 (.a(b),  .b(n1), .y(n3));
nor2 u4 (.a(n2), .b(n3), .y(y));
```
The same 4-gate topology used for NAND-based XOR in 027, with every NAND
replaced by NOR — the result is XNOR instead of XOR (see §2 for why).

## 10. Testbench Explanation

`tb_nor_universal_top` drives all 4 combinations of `a`, `b`, and for each
one checks all four derived outputs against Verilog's native operators:
`y_not_a !== ~a`, `y_and !== (a & b)`, `y_or !== (a | b)`,
`y_xnor !== ~(a ^ b)`. Each combination produces 4 checks (16 total); a
mismatch names the failing gate. The run ends with the standard pass/fail
line.

## 11. Test Cases and Expected Results

| `a` | `b` | `~a` | `a&b` | `a\|b` | `~(a^b)` |
|---|---|---|---|---|---|
| 0 | 0 | 1 | 0 | 0 | 1 |
| 0 | 1 | 1 | 0 | 1 | 0 |
| 1 | 0 | 0 | 0 | 1 | 0 |
| 1 | 1 | 0 | 1 | 1 | 1 |

All 4 input combinations, 4 functions each (16 checks), 100% of the input
space.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 028` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_nor_universal_top` — **PASS**

```text
a b | ~a  a&b  a|b  ~(a^b)
 0 0 |  1   0    0     1
 0 1 |  1   0    1     0
 1 0 |  0   0    1     0
 1 1 |  0   1    1     1
TEST PASSED: 16 checks
tb/tb_nor_universal_top.v:51: $finish called at 4000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* As in 027, this is a completeness proof, not an efficient
  implementation; synthesis would never choose this structure on its own.
* Purely combinational — no clock or reset anywhere in the hierarchy.

## 14. Common Mistakes

* Expecting the 4-NOR XOR-shaped network to produce XOR (like the NAND
  version) instead of XNOR — the duality inverts which one comes out;
  always re-derive by truth table rather than assuming the pattern
  transfers unchanged.
* Mixing up `nor_or`'s "NOR then invert" with `nor_and`'s "invert then
  NOR" — the order of inversion relative to the NOR is what distinguishes
  which De Morgan identity is being realized.

## 15. Possible Improvements

* Build the 5-gate NOR-only XOR (the dual construction that inverts the
  4-gate NOR-XNOR network's output) and compare gate counts.
* Cross-check 027 and 028: XOR-from-NAND should equal NOT(XNOR-from-NOR)
  for all inputs.

## 16. What This Program Teaches

* Functional completeness of NOR, proven by construction.
* De Morgan duality made concrete: the same topology, different gate,
  different resulting function.

## 17. Industry Relevance

NOR-based logic historically dominated early CMOS and is still the
textbook basis for the SR latch (085) and NOR flash memory cells; knowing
both NAND- and NOR-only construction is standard background for reading
and writing standard-cell netlists.

## 18. How to Run

```bash
python3 scripts/run.py 028
cd 01-basic-gates/028-nor-universal-gate && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_nor_universal_top.v
vvp build/sim.vvp +vcd
```
