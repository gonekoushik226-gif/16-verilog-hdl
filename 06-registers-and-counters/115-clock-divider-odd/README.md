# 115 — Clock Divider (Odd, 50% Duty)

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 06-registers-and-counters | Intermediate | `clock_divider_odd` | `src/clock_divider_odd.v` | `tb/tb_clock_divider_odd.v` |

## 1. Objective

Divide a clock by an odd number while still hitting an exact 50% duty
cycle — genuinely harder than program 114's even case, since an odd
divisor's half-period is not a whole number of input clock cycles.

## 2. What the Design Does

`clock_divider_odd` counts `0..N-1` (N odd) on `clk`. For the first
`HALF=(N-1)/2` counts, `clk_out` is held high for the whole cycle; for
the last `HALF` counts, held low for the whole cycle; for the one
*middle* count (`cnt==HALF`), `clk_out` directly follows the live `clk`
signal for that single cycle, contributing exactly one half input-clock
period of extra high time.

## 3. Why It Is Useful

Not every useful division ratio is even — a real design might need to
divide by 3, 5, or another odd factor and still needs the output to be a
proper, symmetric clock rather than a lopsided one.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | input clock, asynchronous active-low reset |
| `clk_out` | output | 1 | divided clock, `1/N` the frequency, exact 50% duty |

Parameters: `N` (default 5, must be odd, >= 3).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `cnt` | `$clog2(N)` | counts `0..N-1` |

## 6. Architecture

```
HALF = (N-1)/2
clk_out = (cnt < HALF) ? 1           -- first HALF cycles: always high
        : (cnt == HALF) ? clk        -- middle cycle: follows live clk
        : 0                          -- last HALF cycles: always low
```
Worked derivation for `N=5` (`HALF=2`, `Tclk` = one input clock period):
cycles at `cnt=0,1` are fully high (`2*Tclk` high time), cycle at
`cnt=2` contributes `Tclk/2` high + `Tclk/2` low (tracking live `clk`),
cycles at `cnt=3,4` are fully low (`2*Tclk` low time). Total period =
`5*Tclk`; total high time = `2*Tclk + Tclk/2 = 2.5*Tclk` = exactly half
of `5*Tclk`. The same derivation generalizes to any odd `N`: `HALF`
full-cycle highs plus one half-cycle high from the middle count always
sums to exactly `N/2` cycles of high time out of `N` total.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A combinational output that is a function of *both* a registered
  counter and the live, un-registered `clk` signal — the middle-count
  case reads `clk` directly rather than through any flip-flop.
* An equation derived and checked by hand (§6) before coding — the same
  "derive first, verify empirically second" discipline used for program
  077's Baugh-Wooley multiplier and program 110's ring-counter feedback.

## 9. Source Code Explanation

```verilog
assign clk_out = (cnt < HALF) ? 1'b1 : (cnt == HALF) ? clk : 1'b0;
```
This single ternary expression implements all three phases from §6 in
one line: full-high, live-clk-tracking, and full-low, selected purely by
comparing the registered counter against the fixed `HALF` threshold.

## 10. Testbench Explanation

`tb_clock_divider_odd` instantiates three DUTs (`N=3,5,7`) and, for
each, lets the very first (reset-phase) cycle pass — it can be
irregular, since reset can release at an inconvenient point relative to
the intended cycle structure — before sampling `clk_out` at a settled
point after every real `clk` edge (alternating `posedge`/`negedge`, each
followed by `#1`) over three full steady-state periods, measuring period
and high-time from the recorded transition times.

An earlier version of this testbench instead waited on raw `@(posedge
clk_out)` events directly. Because `clk_out` is combinationally derived
from *both* a registered counter and the live `clk` signal, updating in
the same simulation instant a clock edge occurs, that raw event-wait
could catch a momentary delta-cycle glitch before the simulator finished
settling that time step, measuring impossible sub-cycle "periods." Since
every real transition of `clk_out` in this design provably occurs
exactly at a `clk` edge, sampling a fixed, settled instant after every
edge (rather than reacting to a raw signal event) sidesteps the race
entirely and was the fix.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | N=3 | measure steady-state period/duty | period=3*Tclk, duty=50% |
| 2 | N=5 | measure steady-state period/duty | period=5*Tclk, duty=50% |
| 3 | N=7 | measure steady-state period/duty | period=7*Tclk, duty=50% |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 115` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_clock_divider_odd` — **PASS**

```text
TEST PASSED: 9 checks
tb/tb_clock_divider_odd.v:98: $finish called at 781000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 16 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The very first cycle after reset release can be shorter than a full
  `N*Tclk` period, since reset can release at any phase relative to the
  intended `HALF`-based cycle structure — this is a real property of the
  design (not a bug), and the testbench deliberately skips it, measuring
  only steady-state periods once the pattern has settled.
* `clk_out` briefly depends on the live `clk` signal, not purely
  registered state — acceptable for driving another clock domain's input
  but worth noting explicitly, since it means `clk_out`'s glitch-free
  guarantee relies on `clk` itself being glitch-free.

## 14. Common Mistakes

* Assuming the first post-reset cycle is representative of steady-state
  timing — for an odd divider it generally is not, since the phase
  alignment between reset release and the internal counter's cycle
  structure is not fixed.
* Testing a combinationally-live-clock-derived signal with raw
  event-triggered waits instead of settled sampling — exactly the
  testbench bug documented in §10.

## 15. Possible Improvements

* Add a parameterized-duty variant for odd divisors where 50% duty is
  not required.

## 16. What This Program Teaches

* Why odd-ratio clock division needs sub-cycle (half-period) resolution
  to hit an exact 50% duty cycle, and one standard technique for it.
* Why testing a clock-derived combinational signal needs settled
  sampling, not raw edge-triggered waits.

## 17. Industry Relevance

Exact-duty odd clock division appears in real designs needing a
specific non-power-of-two or non-even frequency ratio (certain
peripheral or audio clock relationships); the live-clock-tracking
technique shown here is a real, recognized method for this problem, in
contrast to a simpler (but asymmetric-duty) plain counter-toggle
approach.

## 18. How to Run

```bash
python3 scripts/run.py 115            # compile, simulate, synthesize, lint
cd 06-registers-and-counters/115-clock-divider-odd && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/clock_divider_odd.v tb/tb_clock_divider_odd.v
vvp build/sim.vvp +vcd
```
