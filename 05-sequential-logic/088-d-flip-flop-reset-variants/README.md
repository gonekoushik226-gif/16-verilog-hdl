# 088 — D Flip-Flop Reset Variants

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Elementary | (none — three independent modules) | `src/dff_async_reset.v`, `src/dff_sync_reset.v`, `src/dff_async_reset_n.v` | `tb/tb_dff_reset_variants.v` |

## 1. Objective

Compare all three common D flip-flop reset styles — asynchronous
active-high, synchronous active-high, and asynchronous active-low (this
repository's default) — side by side with identical stimulus, to make
their timing difference concrete rather than just described.

## 2. What the Design Does

Three flip-flops with the same `d`/`clk` behavior but different reset
semantics: `dff_async_reset` and `dff_async_reset_n` respond to their
reset the instant it asserts, regardless of `clk`; `dff_sync_reset`
only responds to its reset at the next rising `clk` edge.

## 3. Why It Is Useful

Reset style is a real design decision with real timing consequences —
asynchronous reset can clear a chip instantly but risks reset-release
timing hazards; synchronous reset is glitch-free but needs a running
clock to take effect. Seeing both react to the *same* stimulus in the
*same* testbench makes the difference unambiguous.

## 4. Interface

**`dff_async_reset`**: `clk`, `rst` (active-high, async), `d` in; `q` out.
**`dff_sync_reset`**: `clk`, `rst` (active-high, sync), `d` in; `q` out.
**`dff_async_reset_n`**: `clk`, `rst_n` (active-low, async), `d` in; `q` out.

## 5. Internal Signals

None — each module's `q` is its only state.

## 6. Architecture

```
dff_async_reset:    always @(posedge clk or posedge rst)  if(rst) q<=0; else q<=d;
dff_sync_reset:      always @(posedge clk)                 if(rst) q<=0; else q<=d;
dff_async_reset_n:  always @(posedge clk or negedge rst_n) if(!rst_n) q<=0; else q<=d;
```
The only structural difference between the async and sync variants is
whether the reset signal appears in the `always` block's sensitivity
list — that one difference is entirely responsible for the timing
difference this program demonstrates.

## 7. Module Hierarchy and Connections

Three independent single-module designs; the testbench instantiates all
three side by side with shared `clk`/`d` stimulus.

## 8. Verilog Concepts Used

* Direct comparison of `always @(posedge clk or posedge rst)` (or
  `negedge rst_n`) versus plain `always @(posedge clk)` — the defining
  syntactic difference between asynchronous and synchronous reset.
* This repository's default reset polarity (active-low, `dff_async_reset_n`)
  shown alongside two deliberately non-default styles (`CLAUDE.md` §4
  requires non-default reset styles to be stated explicitly, which each
  module's header comment does).

## 9. Source Code Explanation

Each module is a one-line variation on program 087's `d_ff` template;
see §6. The essential contrast is that `rst`/`rst_n` appears in the
sensitivity list for the two asynchronous variants (so any edge on
*either* signal re-triggers the block) but not for the synchronous
variant (so only a `clk` edge can ever change `q`, and `rst`'s value is
simply read like any other data input at that edge).

## 10. Testbench Explanation

`tb_dff_reset_variants` drives all three flip-flops together, first
confirming normal `d`-sampling behavior matches across all three, then
asserting every reset *between* clock edges and checking: the two
asynchronous variants react immediately (before the next clock edge
arrives), while the synchronous variant's output is still undefined
(matching real hardware — a synchronous reset does not affect state
until a clock edge occurs) until that next edge, at which point it also
resets.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | normal sampling | reset released, d driven at each edge | all three track d identically |
| 2 | reset asserted mid-cycle | reset pulsed between clock edges | async variants reset immediately, sync variant does not |
| 3 | next clock edge | (continuing from #2) | sync variant also resets |
| 4 | reset released | normal operation resumes | all three track d identically again |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 088` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_dff_reset_variants` — **PASS**

```text
TEST PASSED: 8 checks
tb/tb_dff_reset_variants.v:77: $finish called at 56000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 3 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `dff_sync_reset`'s `q` is genuinely undefined (`x` in simulation) until
  its first clock edge, since nothing initializes it and a synchronous
  reset cannot act without a clock — this is realistic (real synchronous
  flip-flops also power up in an unknown state) and the testbench checks
  it accordingly (not checking `q` until after the first edge for that
  module specifically).
* Asynchronous reset risks a subtle real-world hazard this simulation
  does not model: if reset *releases* too close to a clock edge, the
  flip-flop's setup/hold requirements on the reset signal itself can be
  violated, causing metastability — a reason some designs prefer
  asynchronous *assert*, synchronous *release* ("reset synchronizer",
  see program 229).

## 14. Common Mistakes

* Assuming synchronous and asynchronous reset are interchangeable in
  timing — they are not; a synchronous reset held for less than one full
  clock period may never actually take effect if it deasserts before the
  next edge.
* Forgetting to list the reset signal in the sensitivity list for an
  asynchronous design (silently turns it synchronous) or, conversely,
  accidentally including it for a design meant to be synchronous.

## 15. Possible Improvements

* Add a fourth variant demonstrating a reset synchronizer (asynchronous
  assert, synchronous release) as a preview of program 229.

## 16. What This Program Teaches

* The concrete timing difference between synchronous and asynchronous
  reset, driven by identical stimulus in one testbench.
* Why reset polarity and timing are real design decisions, not
  interchangeable style choices.

## 17. Industry Relevance

Real SoC designs mix reset styles deliberately: asynchronous reset for
fast, guaranteed chip-wide initialization, synchronous (or
asynchronous-assert/synchronous-release) reset within individual clock
domains to avoid reset-related timing hazards.

## 18. How to Run

```bash
python3 scripts/run.py 088            # compile, simulate, synthesize, lint
cd 05-sequential-logic/088-d-flip-flop-reset-variants && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/dff_async_reset.v src/dff_sync_reset.v src/dff_async_reset_n.v tb/tb_dff_reset_variants.v
vvp build/sim.vvp +vcd
```
