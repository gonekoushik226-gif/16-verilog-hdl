# 131 — GCD FSMD

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `gcd_top` | `src/gcd_datapath.v`, `src/gcd_controller.v`, `src/gcd_top.v` | `tb/tb_gcd_top.v` |

## 1. Objective

Build this repository's first explicit **FSMD** (finite state machine
with datapath): a controller that makes a data-dependent decision every
cycle (subtract which register from which) based on status flags from a
separate arithmetic datapath, implementing the subtraction-based
Euclidean GCD algorithm.

## 2. What the Design Does

`gcd_top` computes `gcd(a_in, b_in)` by repeated subtraction: each cycle
while running, it subtracts the smaller of its two internal registers
from the larger, until they become equal (the GCD) — one subtraction
per clock cycle, taking a data-dependent number of cycles to complete.
`start` begins a computation (also usable directly from a completed
`done` state, no separate reset needed between runs); `busy`/`done`
report progress.

## 3. Why It Is Useful

An FSMD is the fundamental structure behind every iterative hardware
algorithm that does not fit in a single combinational expression: a
datapath holds and manipulates values, a controller sequences *which*
datapath operation happens each cycle based on the datapath's own
status. GCD-by-subtraction is a small, complete, easy-to-verify example
of this pattern before category 12's larger FSMD-based multipliers and
dividers.

## 4. Interface

**`gcd_top`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `start` | input | 1 | begin computing `gcd(a_in,b_in)` |
| `a_in`, `b_in` | input | `WIDTH` each | operands (sampled when `start` is accepted) |
| `busy` | output | 1 | computation in progress |
| `done` | output | 1 | result is valid; stays high until a new `start` |
| `result` | output | `WIDTH` | `gcd(a_in,b_in)` once `done` |

Parameters: `WIDTH` (8).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `a_reg`, `b_reg` (datapath) | `WIDTH` each | the two working registers |
| `eq`, `a_gt_b`, `a_zero`, `b_zero` (datapath, combinational) | 1 each | status flags read by the controller |
| `state` (controller) | 2 | `S_IDLE`, `S_COMPUTE`, `S_DONE` |

## 6. Architecture

```
S_IDLE --start(+load)--> S_COMPUTE --eq|a_zero|b_zero--> S_DONE --start(+load)--> S_COMPUTE ...

S_COMPUTE each cycle (while not converged):
    a_gt_b ? sub_a (a_reg <= a_reg - b_reg) : sub_b (b_reg <= b_reg - a_reg)

result = a_zero ? b_reg : a_reg
```

## 7. Module Hierarchy and Connections

```
gcd_top
├── gcd_datapath   (u_dp)   -- a_reg/b_reg, status flags, result mux
└── gcd_controller (u_ctrl) -- load/sub_a/sub_b decisions, done/busy
```

## 8. Verilog Concepts Used

* Explicit controller/datapath split: `gcd_controller` never touches
  `a_reg`/`b_reg` directly, only the status flags and the `load`/
  `sub_a`/`sub_b` control lines — the textbook FSMD separation of
  concerns.
* A data-dependent, variable-length computation: unlike this category's
  fixed-cycle-count timed phases (123, 128), `S_COMPUTE`'s duration
  depends entirely on the operand values.
* A deliberate zero-operand fix (`converged = eq || a_zero || b_zero`)
  found necessary by reasoning about the algorithm, not merely by
  pattern-matching a textbook diagram — see §9 and §14.

## 9. Source Code Explanation

```verilog
wire converged = eq || a_zero || b_zero;
```
A pure `eq`-only termination condition (the textbook subtraction
algorithm as usually stated) hangs forever on `gcd(a,0)`: with `b_reg=0`,
`a_gt_b` is true (assuming `a_reg` nonzero) and `sub_a` fires every
cycle, but `a_reg - 0 = a_reg` is unchanged — `a_reg` and `b_reg` never
become equal. `a_zero`/`b_zero` catch this directly.

```verilog
assign result = a_zero ? b_reg : a_reg;
```
Normally (`gcd_ref(a,b)` for `a,b > 0`), `a_reg` never actually reaches
0 during a correct run — subtracting the smaller positive value from the
larger keeps both positive until they become equal. `a_reg` can only be
0 at the moment of convergence if `a_in` itself was 0, in which case the
correct answer is `b_reg`, not `a_reg`; the mux picks the right one.

```verilog
S_IDLE: load = start;
...
S_DONE: load = start;
```
`load` is driven directly from the *current* state and `start` (no
next-state lookahead needed, unlike the timer-triggering pattern in
124/126/128) because the datapath's load and the controller's state
transition both fire on the exact same clock edge from the same
condition.

## 10. Testbench Explanation

`tb_gcd_top` checks `result` against an **independently implemented**
reference (`gcd_ref`, the standard *modulo*-based Euclidean algorithm —
deliberately a different algorithm from the RTL's *subtraction*-based
one, so a shared conceptual bug is unlikely to hide in both). Directed
cases specifically cover `gcd(0,0)`, `gcd(0,b)`, `gcd(a,0)`, equal
operands, and a Fibonacci pair (`144,89`) — the classic worst case for
the subtraction method, exercising the longest realistic iteration
count. 80 randomized pairs (operands 1..150, fixed seed) follow, plus
back-to-back computations with no reset in between to confirm `S_DONE
-> S_COMPUTE` restart works.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | zero operands | `(0,0)`, `(0,17)`, `(17,0)` | `0`, `17`, `17` |
| 2 | equal operands | `(7,7)`, `(1,1)` | `7`, `1` |
| 3 | known GCDs | `(48,18)`, `(100,75)` | `6`, `25` |
| 4 | coprime | `(17,5)` | `1` |
| 5 | worst case | `(144,89)` (Fibonacci) | `1`, completes within watchdog |
| 6 | randomized | 80 pairs, 1..150 | matches `gcd_ref` exactly |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 131` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_gcd_top` — **PASS**

```text
TEST PASSED: 91 checks
tb/tb_gcd_top.v:115: $finish called at 16516000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 162 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Iteration count is data-dependent and, for the subtraction method, can
  be as large as `O(max(a,b))` (the Fibonacci-pair worst case) — far
  worse than a modulo/division-based implementation's `O(log(min(a,b)))`,
  a genuine, documented trade-off for this simpler datapath.
* `WIDTH=8` keeps the worst-case iteration count small enough for fast
  simulation; a wider `WIDTH` would still be functionally correct but
  slower to simulate exhaustively.

## 14. Common Mistakes

* **A genuine algorithmic edge case found and fixed during RTL
  development, not just testbench development:** implementing only the
  `eq` termination condition (matching a naive reading of "subtract
  until equal") hangs forever on any zero operand, since `a - 0 = a`
  never changes. This was caught by reasoning about the algorithm before
  writing the testbench, and fixed by adding `a_zero`/`b_zero` to the
  termination condition and a result mux — confirmed by the directed
  zero-operand test cases, which would otherwise time out.
* Reporting `result = a_reg` unconditionally (ignoring the
  `a_zero` case) silently returns 0 for `gcd(0,b)` instead of `b`.

## 15. Possible Improvements

* Replace the subtraction loop with a shift-subtract (binary GCD)
  algorithm for `O(log(max(a,b)))` worst-case latency.
* Add operand validity/overflow handling for `WIDTH` too small to hold
  either input (not currently checked).

## 16. What This Program Teaches

* The FSMD pattern: a controller driving data-dependent, variable-length
  computation via status flags from a separate datapath.
* Recognizing and fixing an algorithmic edge case (zero operand) that a
  literal textbook statement of an algorithm omits.
* Cross-checking an RTL implementation against a *differently
  implemented* reference algorithm for the same mathematical function.

## 17. Industry Relevance

FSMD-structured iterative datapaths (a controller sequencing
load/operate/store decisions based on datapath status) are the basis for
real sequential multipliers, dividers, and other multi-cycle arithmetic
units — exactly the structure category 12's later, larger FSMD programs
build on.

## 18. How to Run

```bash
python3 scripts/run.py 131            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/131-gcd-fsmd && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_gcd_top.v
vvp build/sim.vvp +vcd
```
