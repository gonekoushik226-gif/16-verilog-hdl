# 016 — Testbench Fundamentals

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 00-foundations | Intermediate | `saturating_counter` | `src/saturating_counter.v` | `tb/tb_saturating_counter.v` |

## 1. Objective

Learn the structure of a complete self-checking testbench — clock and reset
generation, reference model, checker, directed and seeded-random stimulus,
watchdog and summary — using a small but non-trivial DUT.

## 2. What the Design Does

`saturating_counter` is an up/down counter (default 4 bits) that **stops** at
its limits instead of wrapping:

| Condition (priority order) | Next `count` |
|---|---|
| `rst_n = 0` (asynchronous) | 0 |
| `clear = 1` | 0 |
| `en = 1`, `up = 1`, not at max | `count + 1` |
| `en = 1`, `up = 0`, not at 0 | `count − 1` |
| otherwise | unchanged |

`at_max` and `at_min` flag the limits.

## 3. Why It Is Useful

The counter is simple enough to specify in one table but has enough behaviour
(two limits, a priority, a synchronous and an asynchronous reset) to need a
real testbench. Saturating counters are used for credit counters, FIFO
levels, branch predictors (250) and error counters.

## 4. Interface

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 4 | Counter width |

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Asynchronous active-low reset |
| `clear` | in | 1 | Synchronous clear (priority over `en`) |
| `en` | in | 1 | Count enable |
| `up` | in | 1 | Direction: 1 up, 0 down |
| `count` | out | `WIDTH` | Counter value |
| `at_max`, `at_min` | out | 1 | `count` is all ones / zero |

## 5. Internal Signals

| Signal | Purpose |
|---|---|
| `MAX` (localparam) | all-ones value `{WIDTH{1'b1}}` |

## 6. Architecture

```
            +---------------------------+
 up,en ────►| next-state logic          |
 clear ────►|  (clear > inc/dec > hold) |──► D  [count register] Q ──┬──► count
            |  uses at_max / at_min     |◄──────────────────────────┤
            +---------------------------+                            ├──► (count==MAX) at_max
                                                                     └──► (count==0)   at_min
```

## 7. Module Hierarchy and Connections

```
tb_saturating_counter
├── dut : saturating_counter #(.WIDTH(4))
├── reference model  (always block in the testbench)
└── checker          (always @(negedge clk) in the testbench)
```

## 8. Verilog Concepts Used

RTL: parameter-sized constants (`{WIDTH{1'b1}}`), priority `if/else` in a
clocked block, flags derived with continuous assignments.

Testbench: `localparam` bench settings, `always #(CLK_PERIOD/2)` clock,
tasks with `repeat` and event controls, `$random(seed)` with a seed variable,
`$value$plusargs` to read `+seed=N`, `$timeformat` and `%t`, watchdog
`initial` block, coverage-style counters (`hits_max`, `hits_min`).

## 9. Source Code Explanation

```verilog
localparam [WIDTH-1:0] MAX = {WIDTH{1'b1}};
assign at_max = (count == MAX);
assign at_min = (count == {WIDTH{1'b0}});
```
Limits for any width.

```verilog
else if (clear)
    count <= {WIDTH{1'b0}};
else if (en) begin
    if (up && !at_max)       count <= count + 1'b1;
    else if (!up && !at_min) count <= count - 1'b1;
end
```
`clear` is tested before `en`, which gives it priority. The saturation checks
use the flags, so the counter never wraps. When no branch assigns `count`,
the register simply keeps its value — in a clocked block that is a hold, not
a latch.

## 10. Testbench Explanation

The bench is written as a template with numbered sections:

1. **Parameters and signals** — `WIDTH`, `CLK_PERIOD`, `MAX` as localparams so
   the bench adapts if the DUT is re-parameterized.
2. **DUT** — named connections.
3. **Clock** — `always #(CLK_PERIOD/2) clk = ~clk;`.
4. **Reference model** — an `always @(posedge clk or negedge rst_n)` block
   using integer arithmetic with explicit `min/max` limits. It updates on the
   same edge as the DUT, so both can be compared later in the cycle.
5. **Checker** — on every falling edge (mid-cycle, when all values are
   stable) compares `count`, `at_max`, `at_min` with the model and counts how
   often each boundary was reached.
6. **Stimulus** — `reset_dut` and `drive(clear, en, up, n)` tasks change
   inputs on falling edges. Directed phases: count past MAX, hold, count past
   0, clear with `en` active. Then 2000 random cycles using
   `$random(seed)`: rare clears, 75 % enable, direction biased towards up and
   down in alternating 64-cycle windows so both limits are reached. Finally an
   asynchronous reset in the middle of a cycle.
7. **Watchdog and summary** — a separate `initial` block ends a hung
   simulation; the final line follows the repository's pass/fail contract. The
   bench also fails if the random phase never reached both limits
   (a simple coverage goal).

Running with `+seed=7` (`vvp build/sim.vvp +seed=7`) replays a different but
reproducible random sequence.

## 11. Test Cases and Expected Results

| # | Test | Expected |
|---|---|---|
| 1 | count up MAX+5 cycles | stops at 15, `at_max = 1` |
| 2 | hold (`en = 0`) | unchanged |
| 3 | count down MAX+5 cycles | stops at 0, `at_min = 1` |
| 4 | `clear` with `en = 1, up = 1` | 0 (clear wins) |
| 5 | 2000 random cycles | matches model every cycle; both limits hit |
| 6 | async reset mid-cycle | 0 immediately |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 016` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_saturating_counter` — **PASS**

```text
directed: count up past MAX, down past 0, clear, hold
  after counting up:   count=15 at_max=1
  after counting down: count=0 at_min=1
  after clear:         count=0
random: 2000 cycles with seed 1
cycles at MAX: 394, cycles at 0: 606 (both boundaries exercised)
TEST PASSED: 2058 checks
tb/tb_saturating_counter.v:134: $finish called at 20580000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 34 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Comparing on the opposite clock edge is the simplest race-free checking
  scheme for single-clock designs.
* The reference model must be written independently of the RTL (here:
  integers and explicit limit tests), otherwise it repeats the same bugs.
* Directed tests prove specific requirements; random tests find
  combinations nobody thought of; coverage counters prove the random test
  actually reached the interesting states.

## 14. Common Mistakes

* Checking outputs on the same edge that updates them (races).
* A reference model that is a copy of the RTL.
* No watchdog — a DUT that never asserts `done` hangs the regression.
* Unseeded or time-seeded randomness — failures cannot be reproduced.
* Declaring "pass" when no checks ran (always print the check count).

## 15. Possible Improvements

* Parameter sweep: run the same bench for `WIDTH = 1, 4, 8`.
* Functional coverage bins for every transition type (see 286).

## 16. What This Program Teaches

* A reusable self-checking testbench structure.
* Reference models, checkers, directed + seeded random stimulus.
* Reproducibility through seeds and plusargs.

## 17. Industry Relevance

This is a hand-written version of what UVM formalizes (sequences, driver,
monitor, scoreboard, reference model, coverage). The ideas — independent
models, reproducible seeds, coverage goals, watchdogs — are the same in every
professional verification environment.

## 18. How to Run

```bash
python3 scripts/run.py 016
cd 00-foundations/016-testbench-fundamentals && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/saturating_counter.v tb/tb_saturating_counter.v
vvp build/sim.vvp +seed=7 +vcd
```
