# 133 — Hierarchical FSM: Microwave Controller

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Advanced | `microwave_controller` | `src/countdown_timer.v`, `src/door_monitor.v`, `src/microwave_controller.v` | `tb/tb_microwave_controller.v` |

## 1. Objective

Build a main controller FSM that coordinates two independent sub-module
FSMs (a countdown timer and a door sensor monitor), with a safety
interlock (cannot start cooking with the door open) and an immediate,
low-latency pause when the door opens mid-cook.

## 2. What the Design Does

`microwave_controller` cycles `S_IDLE -> S_COOKING -> S_DONE`, with a
`S_PAUSED` detour whenever the door opens during `S_COOKING`. The
`countdown_timer`'s `pause` input is driven directly by the registered
door state (not by the main FSM's own `S_PAUSED` state), so heating
stops as soon as the door is detected open, one cycle *before* the main
FSM's own `S_PAUSED` status becomes visible — see §13 for the exact,
testbench-confirmed latency chain. `cancel` returns to `S_IDLE`
immediately from `S_COOKING` or `S_PAUSED`. Pressing `start` again from
`S_DONE` begins a fresh cook (loading a new `cook_time`), same as from
`S_IDLE`.

## 3. Why It Is Useful

This is the category's clearest example of true FSM hierarchy: the main
controller does not duplicate door-sensing or countdown logic — it only
reacts to `door_open` and `timer_done`, exactly like a real system
integrator combining independently designed and testable sub-blocks.
The safety interlock (no start with the door open) and the immediate
pause are also genuine safety requirements a microwave must get right.

## 4. Interface

**`microwave_controller`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `start` | input | 1 | begin cooking from `IDLE` or `DONE` |
| `cancel` | input | 1 | abort back to `IDLE` from `COOKING` or `PAUSED` |
| `door_open_raw` | input | 1 | raw door sensor |
| `cook_time` | input | `WIDTH` | cook duration, sampled when a cook begins |
| `cooking`, `paused`, `done_beep`, `idle` | output | 1 each | current phase (mutually exclusive) |

Parameters: `WIDTH` (8).

**`countdown_timer`**: `clk`, `rst_n`, `start`, `pause`,
`duration[WIDTH-1:0]` (in), `done` (out). **`door_monitor`**: `clk`,
`rst_n`, `door_open_raw` (in), `door_open` (out, registered).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state` | 2 | `S_IDLE`, `S_COOKING`, `S_PAUSED`, `S_DONE` |
| `door_open` | 1 | registered door state, from `door_monitor` |
| `timer_start` | 1 | combinational: fires only on a fresh `IDLE`/`DONE` -> `COOKING` entry |

## 6. Architecture

```
S_IDLE ---start & !door_open---> S_COOKING ---timer_done---> S_DONE
   ^                                 | door_open                |  start & !door_open
   |                                 v                          v
   '------------cancel------------ S_PAUSED <--- cancel --------'
                                     | !door_open (resume, no reload)
                                     '--> S_COOKING
```
`countdown_timer.pause = door_open` directly (not `state==S_PAUSED`) —
the timer freezes the moment the door is detected, independent of when
the main FSM's own display state catches up.

## 7. Module Hierarchy and Connections

```
microwave_controller
├── door_monitor     (u_door)  -- door_open_raw -> door_open (registered)
└── countdown_timer  (u_timer) -- start = fresh-cook entry only; pause = door_open
```

## 8. Verilog Concepts Used

* True module-level FSM hierarchy: the main controller's next-state
  logic depends only on two sub-module outputs (`door_open`,
  `timer_done`), never touching either sub-module's internal counters
  or registers directly.
* A control signal (`timer.pause`) deliberately wired to a *sub-module
  output* rather than the *main FSM's own state*, specifically to
  minimize reaction latency — a real, testbench-confirmed design choice,
  not an arbitrary wiring decision.
* Reusing the `S_IDLE`/`S_DONE` dual-entry pattern for `timer_start`
  (matching program 128's washing machine, where `S_DONE` also restarts
  directly into the first working phase on `start`).

## 9. Source Code Explanation

```verilog
wire timer_start = (state == S_IDLE || state == S_DONE) && start && !door_open;
...
countdown_timer #(.WIDTH(WIDTH)) u_timer (
    ...
    .start(timer_start), .pause(door_open),
    ...
);
```
`timer_start` only fires from `S_IDLE` or `S_DONE` — critically, **not**
from `S_PAUSED`, so resuming after a door-open pause continues the
existing countdown rather than restarting it with a freshly reloaded
`cook_time`.

```verilog
S_COOKING: begin
    if (cancel)          state <= S_IDLE;
    else if (door_open)  state <= S_PAUSED;
    else if (timer_done) state <= S_DONE;
end
```
The main FSM's own `S_PAUSED` transition is purely for external
observability (a `paused` status light); the actual heating-stop
decision already happened one cycle earlier, inside `countdown_timer`,
via its direct `door_open` connection.

## 10. Testbench Explanation

`tb_microwave_controller` drives the INTEGRATED design. It checks: (1)
a full cook cycle's exact dwell (`COOK_TIME + 1`, the familiar
registered-timer-done latency from programs 124/126/128); (2) that
`start` from `S_DONE` begins a fresh cook directly; (3) `cancel`
returns immediately to `IDLE` from both `S_COOKING` and `S_PAUSED`; (4)
a door-open pause mid-cook, asserting the *total* time to `done_beep`
grows by exactly `2 + pause_len` cycles beyond the normal dwell — the
`2` being the two stages of registered latency (door_monitor's own
registration, then the timer's pre-edge read of the now-registered
`door_open`) empirically traced and confirmed during development (see
§14); (5) the safety interlock rejecting `start` while the door is open.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full cook | door closed throughout | `done_beep` after `COOK_TIME+1` cycles |
| 2 | restart from DONE | `start` while `done_beep` | begins a fresh cook immediately |
| 3 | cancel mid-cook | `cancel` during `COOKING` | immediate `IDLE` |
| 4 | door-open pause | door opens mid-cook, closes later | total time grows by exactly `2+pause_len` |
| 5 | cancel while paused | `cancel` during `PAUSED` | immediate `IDLE` |
| 6 | start interlock | `start` while door open | stays `IDLE` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 133` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_microwave_controller` — **PASS**

```text
TEST PASSED: 40 checks
tb/tb_microwave_controller.v:186: $finish called at 476000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 115 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* `countdown_timer.pause` is wired to `door_open` (a sub-module output),
  not to `state == S_PAUSED` (the main FSM's own state) — a deliberate
  latency-minimizing choice: had `pause` instead depended on the main
  FSM reaching `S_PAUSED`, heating would continue for one additional
  cycle after the door was already known to be open.
* Even with this optimization, opening the door does not stop heating
  *instantaneously* — `door_monitor` itself introduces one cycle of
  registration latency before `door_open` reflects the raw sensor. This
  is an inherent, documented property of registering an input for
  glitch-free operation, not something eliminated by this design.

## 14. Common Mistakes

* **A genuine testbench-derivation bug found during development:** an
  initial version of the pause-dwell check assumed only one cycle of
  registered latency between asserting the raw door signal and the
  timer actually freezing, predicting a total of `(COOK_TIME+1)+1+
  pause_len`. Tracing the actual signal sequence (added temporarily as
  `$display` debug output, since read afterward) showed **two** distinct
  registered stages: `door_monitor` registering `door_open_raw` into
  `door_open`, and then `countdown_timer`'s own clocked block reading
  the *pre-edge* value of `door_open` on the edge that changed it (the
  same same-edge-multiple-always-blocks semantics responsible for
  several other cycle-accounting details throughout this repository) —
  meaning one additional cook cycle elapses before the freeze actually
  takes effect. The formula was corrected to `+2`, confirmed exactly by
  simulation.
* Wiring `timer_start` from a lookahead condition that also
  (incorrectly) fires on `S_PAUSED -> S_COOKING` resume would silently
  discard the remaining cook time on every door-open pause.

## 15. Possible Improvements

* Add a `light`/`turntable` output pair that follows `cooking` for a
  more complete peripheral model.
* Expose `remaining_time` by making the countdown value itself
  observable, not just its `done` pulse.

## 16. What This Program Teaches

* Structuring a main controller so it reacts only to sub-module status
  outputs, never their internals — real module-hierarchy FSM design.
* A deliberate low-latency design choice (driving `pause` from a
  sub-module output instead of the main FSM's own state) and verifying
  its exact effect via cycle-accurate testbench measurement.
* Tracing and correcting a cycle-accounting assumption using temporary
  debug instrumentation, then removing it once the real behavior is
  understood and encoded as the test's expected value.

## 17. Industry Relevance

Main-controller-plus-independent-sub-module-FSM hierarchy, safety
interlocks gating dangerous operation on a sensor status, and
minimizing reaction latency for safety-critical pauses are all standard
requirements in real appliance and industrial control firmware — not
unique to microwaves.

## 18. How to Run

```bash
python3 scripts/run.py 133            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/133-hierarchical-fsm-microwave && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_microwave_controller.v
vvp build/sim.vvp +vcd
```
