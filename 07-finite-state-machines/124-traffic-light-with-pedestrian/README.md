# 124 — Traffic Light With Pedestrian Request

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `traffic_controller` | `src/timer.v`, `src/pedestrian_request.v`, `src/traffic_controller.v` | `tb/tb_traffic_controller.v` |

## 1. Objective

Extend program 123's timed traffic light into a small hierarchical
design: a reusable `timer` module, a request-latching `pedestrian_request`
module, and a top-level `traffic_controller` FSM that coordinates both —
demonstrating request latching and start/done handshakes between a
controller and its sub-modules.

## 2. What the Design Does

The vehicle light always completes a full GREEN -> YELLOW -> RED cycle.
If a pedestrian pressed the (momentary) request button at any point since
the request was last serviced, the RED dwell is followed by a WALK phase
(vehicles still held red) before GREEN resumes; if no request is
pending, RED goes straight back to GREEN. A request pressed while WALK
is already active is redundant (the pedestrian is already crossing) and
does not queue a second WALK.

## 3. Why It Is Useful

This is the first program in the category built from independently
testable, reusable sub-modules rather than one monolithic FSM — the
`timer`'s start/duration/done handshake and the `pedestrian_request`
latch-and-clear pattern both reappear, in spirit, throughout the rest of
this repository's more complex controllers (washing machine, elevator,
microwave).

## 4. Interface

**`traffic_controller`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `req_btn` | input | 1 | momentary pedestrian request pulse |
| `red`, `yellow`, `green` | output | 1 each | vehicle light (red also holds during `walk`) |
| `walk` | output | 1 | pedestrian walk signal |

Parameters: `WIDTH` (8), `RED_TIME` (6), `GREEN_TIME` (6),
`YELLOW_TIME` (3), `WALK_TIME` (5) — all in clock cycles.

**`timer`**: `clk`, `rst_n`, `start` (in), `duration[WIDTH-1:0]` (in),
`done` (out, one-cycle registered pulse `duration` cycles after `start`).

**`pedestrian_request`**: `clk`, `rst_n`, `req_btn` (in), `clear` (in),
`req_pending` (out, latched until `clear`).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 3 | `S_INIT`, `S_GREEN`, `S_YELLOW`, `S_RED`, `S_WALK` |
| `timer_duration` | `WIDTH` | duration fed to `timer`, selected by `state_next` |
| `req_pending` | 1 | latched pedestrian request (from `pedestrian_request`) |
| `req_clear` | 1 | pulsed to service/clear the request at the end of WALK |

## 6. Architecture

```
                 timer_done                timer_done
 S_INIT --*--> S_GREEN -----------> S_YELLOW -----------> S_RED
  (unconditional)  ^                                        |  timer_done
                    |                                        v
                    |                          req_pending? S_WALK : S_GREEN
                    '------------------- timer_done (from S_WALK) --------'
```
`timer.start` is driven combinationally by `state_next != state`, so the
timer reloads and begins counting on the exact clock edge the FSM enters
a new phase; `timer.duration` is selected combinationally from
`state_next` so the correct duration is already presented at that edge.

## 7. Module Hierarchy and Connections

```
traffic_controller
├── timer               (u_timer)  -- start = (state_next != state), duration = f(state_next)
└── pedestrian_request  (u_req)    -- req_btn -> latched -> req_pending; cleared by req_clear
```

## 8. Verilog Concepts Used

* Start/duration/done handshake between an FSM and a reusable timer
  sub-module, with `start` derived combinationally from the next-state
  logic rather than a separate pulse generator.
* A request-latch sub-module with clear-priority-over-set semantics
  (`if (clear) ... else if (req_btn) ...`), a common real-world pattern
  for "sticky until acknowledged" status/request bits.
* An unconditional `S_INIT` -> `S_GREEN` unconditional transition used
  specifically to give the timer a normal (non-reset-driven) transition
  to react to on power-up, avoiding a bootstrapping special case.

## 9. Source Code Explanation

```verilog
timer #(.WIDTH(WIDTH)) u_timer (
    .clk(clk), .rst_n(rst_n),
    .start(state_next != state),
    .duration(timer_duration),
    .done(timer_done)
);
```
`start` is purely combinational — true only on the single clock edge
where the FSM's own state register is also about to change — so the
timer and the FSM's state always stay in lock-step without any extra
handshake logic.

```verilog
always @(*) begin
    req_clear = (state == S_WALK) && timer_done;
end
```
The request is cleared on the exact cycle WALK's timer completes,
*regardless of when during that WALK phase the (possibly redundant) most
recent press arrived* — see §13 for why this is the correct behavior,
not a bug.

## 10. Testbench Explanation

`tb_traffic_controller` drives the fully **integrated** top-level design
(not the sub-modules in isolation). A `phase_code` function decodes
`{green,yellow,red,walk}` into one of GREEN/YELLOW/RED/WALK or `-1`
(invalid combination), checked every single sampled cycle via
`expect_valid_combo`. A generic `wait_phase_change` task (with a 200-cycle
watchdog) waits for the next phase transition and reports elapsed
cycles. Scenarios: (A) no request — RED goes straight to GREEN; (B)
press during GREEN — WALK follows RED; (C) the next cycle after a
serviced WALK has no request — no WALK; (D) press during YELLOW; (E)
press during RED itself; (F) a redundant press *during* WALK does not
queue a second WALK. Every timer-gated phase's measured duration is also
checked against `TIME + 1` cycles (see §13).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | no request | full cycle, no press | RED -> GREEN directly, correct durations |
| 2 | press during GREEN | 1-cycle `req_btn` pulse | WALK inserted after RED |
| 3 | request cleared | (following scenario 2) | next RED -> GREEN, no repeat WALK |
| 4 | press during YELLOW | 1-cycle pulse | WALK inserted after RED |
| 5 | press during RED | 1-cycle pulse | WALK inserted after that same RED |
| 6 | press during WALK | 1-cycle pulse mid-WALK | redundant, no second WALK queued |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 124` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_traffic_controller` — **PASS**

```text
TEST PASSED: 169 checks
tb/tb_traffic_controller.v:196: $finish called at 1526000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 149 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* **Every timer-gated phase measures `TIME + 1` cycles, not `TIME`.**
  `timer.done` is a *registered* pulse (like program 116/117's `tick`):
  it becomes visible one cycle after the count actually reaches
  `duration-1`, and the FSM's next-state logic only reacts to it the
  cycle *after that*. This one extra cycle of latency from using a
  registered sub-module `done` signal instead of a combinational one is
  a genuine, worth-knowing consequence of this module decomposition —
  confirmed empirically by the testbench's exact `elapsed == TIME + 1`
  checks (every one passed unmodified).
* **A press during WALK is treated as already-serviced, not queued.**
  `req_clear` fires unconditionally at the end of every WALK phase, so
  any request latched *during* that same WALK (redundant — the
  pedestrian is already crossing) is cleared along with it. This matches
  real crosswalk behavior (re-pressing the button while your own WALK
  signal is lit does not schedule a second crossing) and is verified
  explicitly by testbench scenario F, not left as an unspecified corner
  case.

## 14. Common Mistakes

* Deriving `timer.start` from a registered "just entered this state"
  flag instead of the combinational `state_next != state` — that adds
  yet another cycle of latency and desynchronizes the timer from the
  FSM's actual state transition.
* Clearing the pedestrian request as soon as `S_WALK` is *entered*
  instead of when it *completes* — that would drop a legitimate request
  made partway through the WALK phase's own dwell instead of only the
  (intentionally dropped) truly redundant tail-end presses.

## 15. Possible Improvements

* Add a "walk flashing / don't walk" clearance phase between WALK and
  GREEN, as real pedestrian signals do.
* Make `timer.done` combinational (an XOR of `running` and the
  next-cycle predicate) to remove the extra latency cycle documented in
  §13, if tighter timing were required.

## 16. What This Program Teaches

* Decomposing a timed FSM into a reusable timer sub-module plus a
  request-latch sub-module, and the start/duration/done handshake that
  connects a controller to a sub-module it does not directly control the
  internals of.
* Why a registered `done`/`tick` signal from a sub-module costs the
  consumer an extra cycle of reaction latency, demonstrated with an
  exact, testbench-verified cycle count rather than left abstract.
* Making and testing an explicit design decision about a genuine corner
  case (request-during-WALK) instead of leaving it unspecified.

## 17. Industry Relevance

Hierarchical controller + reusable-timer + latched-request-input designs
are the standard shape of real embedded peripheral controllers (traffic
controllers, industrial sequencers, appliance controllers) — this
program's three-module structure is a direct, if simplified,
architectural analog.

## 18. How to Run

```bash
python3 scripts/run.py 124            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/124-traffic-light-with-pedestrian && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_traffic_controller.v
vvp build/sim.vvp +vcd
```
