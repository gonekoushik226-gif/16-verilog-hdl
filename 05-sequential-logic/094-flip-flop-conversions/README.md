# 094 — Flip-Flop Conversions (Excitation Tables)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Elementary | (none — three independent modules) | `src/d_ff.v`, `src/jk_from_d.v`, `src/t_from_d.v`, `src/d_from_jk.v` | `tb/tb_ff_conversions.v` |

## 1. Objective

Show that any flip-flop type can be built from any other by solving for
the right *excitation* equation — the combinational logic that turns
"what input do I have" into "what D value would reproduce that
behavior" — using only program 087's plain D flip-flop as the storage
primitive.

## 2. What the Design Does

`jk_from_d` reproduces JK behavior; `t_from_d` reproduces T (toggle)
behavior; `d_from_jk` computes the JK excitation for a *given* `d` input
and feeds it back through the same JK-style update, which this
program's derivation shows must reduce to plain D behavior again.

## 3. Why It Is Useful

Real synthesis tools, and Verilog RTL in general, are almost always
written in terms of D flip-flops. Understanding excitation tables is
what lets a designer reason about (or convert between) any other flip-
flop type described in a textbook, a legacy schematic, or a JK-based
TTL part, entirely in terms of the D-flip-flop template used throughout
this repository.

## 4. Interface

**`jk_from_d`**: `clk`, `rst_n`, `j`, `k` in; `q` out.
**`t_from_d`**: `clk`, `rst_n`, `t` in; `q` out.
**`d_from_jk`**: `clk`, `rst_n`, `d` in; `q` out.
**`d_ff`**: `clk`, `rst_n`, `d` in; `q` out (program 087's design, reused).

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| (jk_from_d) `d_excitation` | `J.~Q + ~K.Q`, the JK-to-D excitation |
| (t_from_d) `d_excitation` | `T XOR Q`, the T-to-D excitation |
| (d_from_jk) `j`, `k` | the D-to-JK excitation (`j=d`, `k=~d`), fed into the same JK-to-D equation |

## 6. Architecture

```
jk_from_d:  D = J.~Q + ~K.Q          -> d_ff -> Q
t_from_d:   D = T XOR Q              -> d_ff -> Q
d_from_jk:  J = D, K = ~D  (D-to-JK excitation)
            D_internal = J.~Q + ~K.Q = D.~Q + D.Q = D   (algebraic identity)
                                      -> d_ff -> Q
```
`d_from_jk`'s round trip is the interesting case: substituting its own
`j=d, k=~d` into the JK-to-D formula gives `d.~q + d.q = d.(~q+q) = d`
— the excitation equations are proven exact inverses of each other, so
`d_from_jk` is provably identical to a plain `d_ff`, which the testbench
verifies directly against a behavioral reference.

## 7. Module Hierarchy and Connections

```
jk_from_d  ├── core : d_ff (d_excitation) -> q
t_from_d   ├── core : d_ff (d_excitation) -> q
d_from_jk  ├── core : d_ff (d_excitation) -> q
```
Three independent top-level designs, each wrapping one `d_ff` instance
with different combinational excitation logic ahead of it.

## 8. Verilog Concepts Used

* Deriving and directly encoding a Boolean excitation equation as a
  `wire` expression feeding a reused, previously-verified module.
* Algebraic verification of a round-trip identity (D→JK→D), checked both
  by hand in source comments and empirically in the testbench.

## 9. Source Code Explanation

Each conversion module is one `wire` assignment (the excitation
equation) feeding `d_ff`'s `d` input; see §6 for each equation's
derivation and §5 for what each named signal represents.

## 10. Testbench Explanation

`tb_ff_conversions` checks `jk_from_d` exhaustively against the JK
characteristic table from both starting states of `q` (same methodology
as program 090's own testbench), `t_from_d` against hold/toggle
behavior including a clean divide-by-2 sequence (same methodology as
program 091), and `d_from_jk` against a plain behavioral `posedge`
D flip-flop reference driven with 12 random `d` values — directly
confirming the round-trip identity derived in §6.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | jk_from_d, exhaustive | all 4 (j,k) from both q states | matches JK characteristic table |
| 2 | t_from_d, hold/toggle | t=0 then t=1 x8 | hold, then clean divide-by-2 |
| 3 | d_from_jk vs behavioral reference | 12 random d values | q matches reference every cycle |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 094` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_ff_conversions` — **PASS**

```text
TEST PASSED: 42 checks
tb/tb_ff_conversions.v:127: $finish called at 366000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 10 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* All three conversions share the exact same underlying storage element
  (`d_ff`) — only the combinational logic ahead of it differs, making
  the excitation-table technique's generality concrete.

## 14. Common Mistakes

* Deriving an excitation equation from the wrong direction (e.g. mixing
  up "what D reproduces JK" with "what JK reproduces D") — the two are
  different equations that happen to compose to an identity only when
  applied in the correct order.
* Forgetting that toggle (`T=1`) genuinely depends on the current state
  — `t_from_d`'s excitation (`T XOR Q`) is not a constant, unlike a
  simple set/reset excitation.

## 15. Possible Improvements

* Add an SR-to-D conversion, completing the full set of classic
  excitation-table conversions.

## 16. What This Program Teaches

* The general excitation-table technique for converting between flip-
  flop types.
* Verifying an algebraic derivation both symbolically (in comments) and
  empirically (in a testbench against an independent reference).

## 17. Industry Relevance

Modern RTL is written almost exclusively in terms of D flip-flops, but
excitation-table reasoning remains directly useful whenever integrating
with legacy JK-based designs, textbook state-machine derivations, or
any hardware description expressed in another flip-flop type.

## 18. How to Run

```bash
python3 scripts/run.py 094            # compile, simulate, synthesize, lint
cd 05-sequential-logic/094-flip-flop-conversions && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/d_ff.v src/jk_from_d.v src/t_from_d.v src/d_from_jk.v tb/tb_ff_conversions.v
vvp build/sim.vvp +vcd
```
