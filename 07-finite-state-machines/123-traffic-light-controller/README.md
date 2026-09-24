# 123 — Traffic Light Controller

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Elementary | `traffic_light` | `src/traffic_light.v` | `tb/tb_traffic_light.v` |

## 1. Objective

Build a timed Moore FSM: one whose transitions are gated not by an
external event but by an internal cycle counter reaching a
parameterized dwell time — the standard structure behind traffic
lights, sequencers, and any fixed-duration phase controller.

## 2. What the Design Does

`traffic_light` cycles forever through RED -> GREEN -> YELLOW -> RED,
holding each phase for its own parameterized number of clock cycles
(`RED_TIME`, `GREEN_TIME`, `YELLOW_TIME`). Exactly one of `red`,
`yellow`, `green` is asserted at any time, decoded purely from `state`
(Moore).

## 3. Why It Is Useful

Nearly every real controller has phases that must last a specific,
predictable duration rather than react only to external inputs — timed
Moore FSMs like this one are the base pattern this program's later,
more complex controllers (124's pedestrian requests, 128's washing
machine phases, 134's stepper sequencing) all build on.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `red`, `yellow`, `green` | output | 1 each | mutually exclusive phase outputs |

Parameters: `RED_TIME` (default 4), `GREEN_TIME` (default 6),
`YELLOW_TIME` (default 3) — dwell time of each phase, in clock cycles.

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 2 | current / next phase (`S_RED`, `S_GREEN`, `S_YELLOW`) |
| `cnt`, `cnt_next` | `$clog2(max(RED_TIME,GREEN_TIME,YELLOW_TIME)+1)` | cycles elapsed in the current phase |

## 6. Architecture

```
        cnt==RED_TIME-1        cnt==GREEN_TIME-1       cnt==YELLOW_TIME-1
  S_RED --------------> S_GREEN --------------> S_YELLOW ----------------> S_RED (repeat)
  (red=1)                (green=1)                (yellow=1)
```
Each state increments `cnt` every cycle it stays there; on reaching
`duration-1` it transitions to the next phase and resets `cnt` to 0.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A `function` (`max3`) used purely at elaboration time to size the
  counter with `$clog2`, so the same RTL works correctly for any
  combination of the three duration parameters without manual width
  bookkeeping.
* Three-`always`-block FSM structure (state register / next-state /
  Moore output decode), with the timing condition (`cnt == TIME-1`)
  folded into the next-state logic rather than a separate module —
  appropriate for this "Elementary" single-file program; program 124
  contrasts this against a separate `timer` module.

## 9. Source Code Explanation

```verilog
localparam integer MAX_TIME = max3(RED_TIME, GREEN_TIME, YELLOW_TIME);
localparam integer CNT_W    = $clog2(MAX_TIME + 1);
```
The counter is sized from the *largest* of the three durations so it can
count up to `MAX_TIME - 1` regardless of which phase is active — the
`+1` inside `$clog2` accounts for needing to represent `MAX_TIME - 1`
itself (e.g. `MAX_TIME=6` needs values `0..5`, i.e. 3 bits, and
`$clog2(6+1)=$clog2(7)=3`).

```verilog
S_RED: if (cnt == RED_TIME[CNT_W-1:0]-1'b1)
           begin state_next = S_GREEN; cnt_next = {CNT_W{1'b0}}; end
```
`RED_TIME` (a `parameter`, default 32-bit) is sliced down to `CNT_W`
bits before comparing against `cnt`, avoiding a width-mismatch warning
while comparing a possibly-narrower counter against the full-width
parameter default. When the count reaches one less than the dwell time,
the *next* cycle's transition both changes `state` and clears `cnt` in
the same clock edge.

## 10. Testbench Explanation

`tb_traffic_light` checks two things every sampled cycle: that exactly
one of `red`/`green`/`yellow` matches the expected phase, and that each
phase lasts exactly its parameterized number of cycles. Because
`state` resets to RED *asynchronously* (not via a clock edge), the very
first RED phase is checked in two parts: an immediate post-reset,
pre-clock-edge sample, then `RED_TIME-1` further post-edge samples.
Every later phase (including every later RED phase, now entered via a
normal transition) is checked with a full `check_phase(duration, ...)`
call. Five complete RED->GREEN->YELLOW loops are run after the initial
partial cycle.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | reset phase | immediately after reset | `red=1`, others 0 |
| 2 | first RED dwell | `RED_TIME-1` more cycles | stays red |
| 3 | GREEN dwell | `GREEN_TIME` cycles | stays green |
| 4 | YELLOW dwell | `YELLOW_TIME` cycles | stays yellow |
| 5 | 5 full loops | repeated R/G/Y | every phase duration exact, mutually exclusive |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 123` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_traffic_light` — **PASS**

```text
TEST PASSED: 78 checks
tb/tb_traffic_light.v:94: $finish called at 786000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 53 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Durations are compile-time parameters, not runtime-configurable —
  appropriate for this elementary program; program 117 already showed
  the runtime-configurable equivalent (`prescaler`'s `reload_val`) if
  that flexibility were needed here instead.
* The Moore output decode always defaults every output to 0 first (per
  CLAUDE.md §4), preventing any accidental unintended latch even though
  the `case` here is already exhaustive by construction.

## 14. Common Mistakes

* Comparing `cnt` against `TIME` instead of `TIME - 1`, which makes
  every phase last one cycle longer than intended (an extremely common
  off-by-one in timed-FSM design).
* Forgetting to also reset `cnt` when transitioning to the next phase
  — without `cnt_next = 0` on the transition, the next phase's count
  starts wherever the previous phase's counter left off, corrupting all
  subsequent timing.

## 15. Possible Improvements

* Make the durations runtime-configurable registers (as program 117
  does for `reload_val`) instead of compile-time parameters.
* Add a pedestrian request input — this is exactly what program 124
  builds next, adding a separate timer module and request-latching logic
  on top of this same phase structure.

## 16. What This Program Teaches

* Building a timed Moore FSM where transitions are gated by an internal
  counter reaching a parameterized duration.
* Sizing a counter correctly for multiple, possibly different,
  parameterized durations using `$clog2` and an elaboration-time
  `function`.

## 17. Industry Relevance

Timed phase sequencers are everywhere in real control logic — not just
literal traffic lights, but any fixed-duration state machine (reset
sequencers, power-up sequencing, communication protocol timeouts) uses
this exact "counter reaches N, then transition" structure.

## 18. How to Run

```bash
python3 scripts/run.py 123            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/123-traffic-light-controller && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/traffic_light.v tb/tb_traffic_light.v
vvp build/sim.vvp +vcd
```
