# 087 — D Flip-Flop

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 05-sequential-logic | Beginner | `d_ff` | `src/d_ff.v` | `tb/tb_d_ff.v` |

## 1. Objective

Build the edge-triggered counterpart to program 086's level-sensitive
latch, and see directly (by driving `d` between clock edges) that only
the clock's rising edge, not `d` changing, causes `q` to update.

## 2. What the Design Does

`d_ff` samples `d` on every rising edge of `clk` and holds that value in
`q` until the next rising edge. An asynchronous active-low `rst_n`
forces `q` to 0 immediately, independent of `clk`.

## 3. Why It Is Useful

Edge-triggered flip-flops are the standard storage element in
synchronous digital design — virtually every register, counter, and
state machine in this repository from here on is built from this exact
`always @(posedge clk or negedge rst_n)` template.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `d` | input | 1 | data input |
| `q` | output | 1 | registered output |

## 5. Internal Signals

None — `q` is the only state element.

## 6. Architecture

```
posedge clk or negedge rst_n:
    if (!rst_n) q <= 0
    else        q <= d
```

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* This repository's default reset template (`CLAUDE.md` §4):
  `always @(posedge clk or negedge rst_n)`, non-blocking assignment
  (`<=`) only.
* Contrast with program 086: the sensitivity list here is edge-based
  (`posedge`/`negedge`), not level-based (`*`), which is exactly what
  makes `d` changes between edges invisible to `q`.

## 9. Source Code Explanation

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= 1'b0;
    else        q <= d;
end
```
The sensitivity list only re-triggers this block on a rising `clk` edge
or a falling `rst_n` edge — never merely because `d` changed. Inside,
`rst_n` is checked first (so it always wins over normal operation), and
the non-blocking assignment `<=` schedules the update rather than
applying it immediately, the correct idiom for sequential logic.

## 10. Testbench Explanation

`tb_d_ff` asserts reset and confirms `q` holds at 0 even with `d=1`,
then releases reset and drives `d` in two ways: aligned with clock edges
(normal sampling) and changed *between* edges (to directly demonstrate
`q` does not react until the next `posedge clk`), plus an asynchronous
reset pulse asserted mid-cycle.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reset holds | rst_n=0, d=1 | q=0 |
| 2 | normal sampling | d set before each posedge | q follows d at each edge |
| 3 | d changes between edges | d toggled mid-cycle | q unchanged until the next posedge |
| 4 | async reset mid-cycle | rst_n pulsed low between edges | q drops to 0 immediately |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 087` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_d_ff` — **PASS**

```text
TEST PASSED: 8 checks
tb/tb_d_ff.v:56: $finish called at 56000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 1 cell
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* This is this repository's canonical flip-flop template; nearly every
  later sequential program's individual flip-flops follow this exact
  shape.

## 14. Common Mistakes

* Using blocking assignment (`=`) instead of non-blocking (`<=`) inside
  a clocked `always` block — works "by accident" for a single flip-flop
  in simulation but breaks the moment flip-flops are chained (see
  program 010's blocking-vs-nonblocking demonstration).
* Forgetting `rst_n` in the sensitivity list when it must be
  asynchronous — without `or negedge rst_n`, the reset would only take
  effect at the next clock edge, silently becoming synchronous (see
  program 088 for a direct comparison of all three styles).

## 15. Possible Improvements

* Add a synchronous reset or clock-enable variant (programs 088, 089).

## 16. What This Program Teaches

* The canonical Verilog D flip-flop template used throughout the rest of
  this repository.
* The concrete difference between edge-triggered and level-sensitive
  storage.

## 17. Industry Relevance

This is, without exaggeration, the single most-used sequential primitive
in digital design — every register, pipeline stage, and state machine
element in real hardware is built from cells functionally identical to
this one.

## 18. How to Run

```bash
python3 scripts/run.py 087            # compile, simulate, synthesize, lint
cd 05-sequential-logic/087-d-flip-flop && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/d_ff.v tb/tb_d_ff.v
vvp build/sim.vvp +vcd
```
