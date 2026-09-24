# 086 — D Latch

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `d_latch` | `src/d_latch.v` | `tb/tb_d_latch.v` |

## 1. Objective

Build a level-sensitive D latch and see the deliberate Verilog idiom
(an `if` with no `else`) that correctly describes — and correctly
synthesizes to — a hardware latch.

## 2. What the Design Does

`d_latch` is transparent while `en=1` (`q` follows `d` continuously,
with no clock edge involved) and holds its last value while `en=0`
(`d` is ignored entirely).

## 3. Why It Is Useful

Latches are simpler and smaller than edge-triggered flip-flops (program
087) and appear as building blocks inside real flip-flops (program 093's
master-slave construction uses two of them). They also are the classic
example of an *unintentional* latch bug when an `if` without an `else`
appears somewhere it shouldn't — this program shows the same
construct used deliberately and correctly.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `d` | input | 1 | data input |
| `en` | input | 1 | enable — 1 = transparent, 0 = hold |
| `q` | output | 1 | latch state |

## 5. Internal Signals

None — `q` is both the output and the only state element.

## 6. Architecture

```
en=1: q = d           (transparent)
en=0: q = q (unchanged)  (hold)
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* `always @(*)` with an `if` and **no `else`** — this repository's
  coding standard (`CLAUDE.md` §4) normally requires a default
  assignment to avoid unintended latches; this program is the deliberate
  exception, since a level-sensitive latch is exactly "hold when the
  condition is false," which is what the missing `else` describes.
* `program.conf`'s `ALLOW_LATCH=yes`, telling this repository's
  synthesis check that the inferred latch here is intentional, not a bug
  to reject.

## 9. Source Code Explanation

```verilog
always @(*) begin
    if (en) q = d;
end
```
When `en=1`, `q` is continuously re-evaluated to follow `d` (the
`always @(*)` sensitivity list re-triggers on any change to `d` or
`en`). When `en=0`, the `if` condition is false and nothing assigns
`q`, so it keeps its previous value — precisely a latch's hold
behavior, and precisely what makes a synthesis tool infer a latch cell
rather than combinational logic.

## 10. Testbench Explanation

`tb_d_latch` drives `d` while `en=1` (transparent phase, checking `q`
tracks every change), then holds `en=0` while still changing `d` (hold
phase, checking `q` stays at whatever it last was), then re-enters and
re-exits the transparent phase to confirm the latch can be re-opened.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | transparent | en=1, d toggling | q tracks d immediately |
| 2 | hold | en=0, d toggling | q stays at its value from when en dropped |
| 3 | re-open | en=1 again | q resumes tracking d |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 086` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_d_latch` — **PASS**

```text
TEST PASSED: 9 checks
tb/tb_d_latch.v:55: $finish called at 18000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell (1 intentional latch(es))
Lint (Verilator 5.020 `--lint-only`): warnings — LATCH
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `q`'s initial value before the first `en=1` phase is undefined (no
  `initial` block, matching this repository's synthesizable-RTL
  convention of leaving power-up state to the target technology) —
  the testbench only checks `q` after the first transparent phase has
  driven it to a known value.
* Yosys reports 1 intentional latch cell, matching `ALLOW_LATCH=yes` in
  `program.conf`; Verilator correspondingly reports a `LATCH` warning
  (expected, not a bug — see §14).

## 14. Common Mistakes

* Writing this exact `if`-without-`else` pattern *accidentally*
  elsewhere in a design meant to be purely combinational — the single
  most common source of unintended-latch bugs, which is exactly why
  `CLAUDE.md`'s coding standard requires default assignments everywhere
  except here.
* Confusing "transparent" with "clocked" — a latch has no clock at all;
  `en` is a level, and `q` can change the instant `d` changes while
  `en=1`, not just at an edge.

## 15. Possible Improvements

* Add an asynchronous clear input, common on real latch cells.

## 16. What This Program Teaches

* The defining level-sensitive (not edge-sensitive) behavior of a latch.
* The Verilog idiom that correctly infers a latch, and why the same
  idiom is a bug everywhere else.

## 17. Industry Relevance

D latches appear inside real flip-flop cells (master-slave, program
093) and in latch-based (rather than flip-flop-based) design styles
sometimes used for their smaller area and lower power in
specific ASIC flows, though they require more careful timing analysis
than edge-triggered designs.

## 18. How to Run

```bash
python3 scripts/run.py 086            # compile, simulate, synthesize, lint
cd 05-sequential-logic/086-d-latch && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/d_latch.v tb/tb_d_latch.v
vvp build/sim.vvp +vcd
```
