# 010 — Blocking vs Non-Blocking Assignment

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Elementary | `shift_nonblocking`, `shift_blocking` (two independent modules) | `src/shift_nonblocking.v`, `src/shift_blocking.v` | `tb/tb_blocking_vs_nonblocking.v` |

## 1. Objective

See, in simulation and in synthesis, why sequential logic must use
non-blocking assignments (`<=`) and what goes wrong with blocking
assignments (`=`).

## 2. What the Design Does

Both modules contain the same three statements inside
`always @(posedge clk …)`:

```
q1 (=|<=) din;   q2 (=|<=) q1;   q3 (=|<=) q2;
```

* `shift_nonblocking` (`<=`) is a correct 3-stage shift register: `q3` is
  `din` delayed by three clock edges.
* `shift_blocking` (`=`) collapses: on each edge `q1`, `q2` and `q3` all take
  the value of `din`. **It is intentionally wrong** — it exists to show the
  bug.

## 3. Why It Is Useful

Using the wrong assignment type is the single most common cause of RTL that
simulates differently from the synthesized hardware, or that behaves
differently depending on statement order. The rule "`<=` in clocked blocks,
`=` in combinational blocks" prevents it.

## 4. Interface

Both modules:

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Asynchronous active-low reset |
| `din` | in | 1 | Serial input |
| `q1`, `q2`, `q3` | out | 1 each | Stage outputs |

## 5. Internal Signals

None; the stage registers are the outputs.

## 6. Architecture

```
shift_nonblocking:   din ─►[FF]─q1─►[FF]─q2─►[FF]─q3

shift_blocking:      din ─►[FF]─┬─ q1         (synthesis keeps ONE flip-flop;
                                ├─ q2          all three outputs are the same
                                └─ q3          signal)
```

Yosys confirms this: the pair synthesizes to **4** flip-flops — 3 for the
non-blocking version and 1 for the blocking version (its three identical
registers are merged).

## 7. Module Hierarchy and Connections

```
tb_blocking_vs_nonblocking
├── u_nb : shift_nonblocking
└── u_bl : shift_blocking      (same clk, rst_n, din)
```

## 8. Verilog Concepts Used

* **Blocking assignment `=`** — executes immediately; the next statement sees
  the new value.
* **Non-blocking assignment `<=`** — the right-hand side is evaluated now, the
  update is scheduled for the end of the time step (the NBA region). All
  registers in the design update "simultaneously", like real flip-flops.
* The Verilog event scheduler: active region → non-blocking update region.

## 9. Source Code Explanation

`shift_nonblocking.v`:

```verilog
q1 <= din;
q2 <= q1;
q3 <= q2;
```
At the clock edge all three right-hand sides are read first (old `din`,
old `q1`, old `q2`), then all three registers update. Statement order does not
matter — any permutation gives the same shift register.

`shift_blocking.v`:

```verilog
q1 = din;
q2 = q1;   // already equals din
q3 = q2;   // already equals din
```
Each line completes before the next. After line 1, `q1` already holds the new
`din`, so `q2` and `q3` copy it too. Reversing the order
(`q3 = q2; q2 = q1; q1 = din;`) would happen to work, but correctness would
then depend on statement order — fragile and easy to break during edits.

There is a second, subtler hazard: when two blocks triggered by the same edge
use blocking assignments and read each other's outputs, the result depends on
which block the simulator runs first (a **race**). Non-blocking assignments
remove the race because reads happen before any update.

## 10. Testbench Explanation

* Both modules receive the same clock, reset and serial pattern
  `1011_0010_0111_0001`.
* `din` changes on the **falling** edge; the check happens on the next falling
  edge, after exactly one rising edge has sampled `din`.
* The bench keeps `history`, the values sampled by the last three rising edges
  (recorded with its own non-blocking always block).
* Checks: `{q3,q2,q1}` of the non-blocking module must equal `history`;
  every stage of the blocking module must equal the newest sample
  (`{3{history[0]}}`), demonstrating the collapse.

## 11. Test Cases and Expected Results

| Cycle | din | nonblocking q1 q2 q3 | blocking q1 q2 q3 |
|---|---|---|---|
| 0 | 1 | 1 0 0 | 1 1 1 |
| 1 | 0 | 0 1 0 | 0 0 0 |
| 2 | 1 | 1 0 1 | 1 1 1 |
| … | … | shifted pattern | all equal to din |

16 cycles, two checks per cycle.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 010` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_blocking_vs_nonblocking` — **PASS**

```text
cycle din | nonblocking q1 q2 q3 | blocking q1 q2 q3
   0   1  |           1  0  0  |         1  1  1
   1   0  |           0  1  0  |         0  0  0
   2   1  |           1  0  1  |         1  1  1
   3   1  |           1  1  0  |         1  1  1
   4   0  |           0  1  1  |         0  0  0
   5   0  |           0  0  1  |         0  0  0
   6   1  |           1  0  0  |         1  1  1
   7   0  |           0  1  0  |         0  0  0
   8   0  |           0  0  1  |         0  0  0
   9   1  |           1  0  0  |         1  1  1
  10   1  |           1  1  0  |         1  1  1
  11   1  |           1  1  1  |         1  1  1
  12   0  |           0  1  1  |         0  0  0
  13   0  |           0  0  1  |         0  0  0
  14   0  |           0  0  0  |         0  0  0
  15   1  |           1  0  0  |         1  1  1
TEST PASSED: 32 checks
tb/tb_blocking_vs_nonblocking.v:56: $finish called at 180000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 4 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Clocked `always` blocks: only `<=`.
* Combinational `always @(*)` blocks: only `=` (non-blocking there creates
  extra delta cycles and can simulate with stale values).
* Never mix `=` and `<=` to the same variable, and never assign one variable
  from two `always` blocks.
* Temporary variables inside a clocked block written with `=` and consumed in
  the same block are legal but make the code harder to review; most coding
  guidelines forbid them.

## 14. Common Mistakes

* Writing a pipeline or shift register with `=` — stages collapse.
* Writing combinational logic with `<=` — usually still works, but can hide
  ordering problems and slows simulation.
* Believing statement order inside a clocked block matters (with `<=` it does
  not).
* Testbench stimulus changing on the active clock edge with `=`, racing the
  design.

## 15. Possible Improvements

* Add a register-swap example (`a <= b; b <= a;` swaps; with `=` both end up
  equal).
* Demonstrate an inter-block race between two blocking `always` blocks.

## 16. What This Program Teaches

* The semantics of `=` and `<=`.
* How the collapse shows up in simulation *and* in the synthesized netlist.
* Race-free testbench timing.

## 17. Industry Relevance

The "non-blocking for sequential, blocking for combinational" guideline
(Cummings, SNUG 2000) is part of practically every company's RTL coding
standard, and lint tools flag violations (Verilator's `BLKSEQ`, for example).

## 18. How to Run

```bash
python3 scripts/run.py 010
cd 00-foundations/010-blocking-vs-nonblocking && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_blocking_vs_nonblocking.v
vvp build/sim.vvp +vcd
```
