# 069 — 4-bit Carry-Lookahead Adder

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 04-arithmetic-circuits | Intermediate | `cla4` | `src/cla4.v` | `tb/tb_cla4.v` |

## 1. Objective

Replace program 064's rippled carry chain with carry equations computed
directly from generate/propagate signals, so every carry bit is available
without waiting for the bits below it.

## 2. What the Design Does

`cla4` adds two 4-bit numbers `a`, `b` and `cin`. For each bit it first
computes propagate `p[i] = a[i] ^ b[i]` and generate `g[i] = a[i] &
b[i]`, then expands each internal carry `c1..c4` as a flattened
sum-of-products of these signals and `cin` — no carry bit is defined in
terms of another carry bit, only in terms of `p`, `g`, and `cin`.

## 3. Why It Is Useful

A ripple-carry adder's delay grows linearly with width because each bit
must wait for the previous bit's carry. Carry-lookahead breaks that
dependency by expanding the carry recursion into flat equations, trading
gate fan-in/count for lower depth — the standard technique behind fast
adders in real datapaths.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 4 | first operand |
| `b` | input | 4 | second operand |
| `cin` | input | 1 | carry in |
| `sum` | output | 4 | `a + b + cin`, low 4 bits |
| `carry_out` | output | 1 | carry out of bit 3 |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `p[3:0]` | 4 | bit propagate (`a[i] ^ b[i]`) |
| `g[3:0]` | 4 | bit generate (`a[i] & b[i]`) |
| `c0..c4` | 1 each | carries into/out of each bit, each a flat function of `p`, `g`, `cin` |

## 6. Architecture

```
p[i] = a[i] ^ b[i]     g[i] = a[i] & b[i]

c0 = cin
c1 = g0 + p0.c0
c2 = g1 + p1.g0 + p1.p0.c0
c3 = g2 + p2.g1 + p2.p1.g0 + p2.p1.p0.c0
c4 = g3 + p3.g2 + p3.p2.g1 + p3.p2.p1.g0 + p3.p2.p1.p0.c0

sum[i] = p[i] xor c[i]
carry_out = c4
```
Each `c[i]` expands purely in terms of `p`/`g`/`cin`: it says "a carry
appears at bit `i` if some bit at or below `i-1` generates one and every
bit between it and `i-1` propagates it through" — read directly off the
sum-of-products form, with no reference to any other carry signal.

## 7. Module Hierarchy and Connections

Single module, no instances (all logic is flat `assign` statements).

## 8. Verilog Concepts Used

* Flattened Boolean sum-of-products carry equations derived from a
  recursive definition (`c[i] = g[i-1] | (p[i-1] & c[i-1])`) expanded out
  by substitution so no carry signal depends on another carry signal.
* Vector `p`/`g` computed with one `assign` each over 4-bit operands.

## 9. Source Code Explanation

```verilog
wire [3:0] p = a ^ b;
wire [3:0] g = a & b;
wire c1 = g[0] | (p[0] & c0);
wire c2 = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c0);
...
assign sum = p ^ {c3, c2, c1, c0};
```
`p` and `g` are computed once for all four bits. Each `c[i]` is written
out as the fully expanded sum-of-products (not `c[i-1]` referenced
recursively), which is what makes this "lookahead": every carry is a
direct function of primary inputs, computable in parallel with the others
rather than in sequence.

## 10. Testbench Explanation

`tb_cla4` is deliberately identical in method to program 064's `tb_rca4`
— exhaustive over all 512 `(a,b,cin)` combinations, checked against a
5-bit reference `a+b+cin` — so the two adder architectures can be
directly compared for correctness with the same test methodology.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | exhaustive | all 512 `(a,b,cin)` combinations | `{carry_out,sum} == a+b+cin` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 069` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_cla4` — **PASS**

```text
TEST PASSED: 512 checks
tb/tb_cla4.v:49: $finish called at 512000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 40 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The carry equations grow one AND-term per bit of width, so this direct
  expansion does not scale past roughly 4 bits before gate fan-in becomes
  impractical — program 070 shows the hierarchical fix (group P/G,
  second-level lookahead) used at 16 bits and beyond.
* Purely combinational; no reset/clock.

## 14. Common Mistakes

* Writing `c[i]` recursively in terms of `c[i-1]` in the RTL text while
  believing it is "lookahead" — that is just ripple-carry rewritten; true
  lookahead requires the *fully expanded* sum-of-products form shown here.
* Dropping the `p[i-1] & p[i-2] & ... & c0` term for higher carries —
  every carry equation must account for a carry rippling all the way from
  `cin` if every intermediate bit propagates.

## 15. Possible Improvements

* Expose group propagate/generate (`P`, `G`) outputs so several `cla4`
  blocks could themselves be combined with a second lookahead level —
  program 070 implements this as a fully separate, self-contained design.

## 16. What This Program Teaches

* The generate/propagate formulation of binary addition.
* Why flattening a recursive carry definition removes the ripple-carry
  bottleneck, and what it costs in gate complexity.

## 17. Industry Relevance

Carry-lookahead (and its hierarchical extensions) is one of the classic
fast-adder architectures taught in every computer arithmetic course and
historically used in high-performance ALUs; modern synthesis tools often
derive an equivalent structure automatically from a plain `+`, but
understanding the manual construction explains what that optimization is
actually doing.

## 18. How to Run

```bash
python3 scripts/run.py 069            # compile, simulate, synthesize, lint
cd 04-arithmetic-circuits/069-carry-lookahead-adder-4bit && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/cla4.v tb/tb_cla4.v
vvp build/sim.vvp +vcd
```
