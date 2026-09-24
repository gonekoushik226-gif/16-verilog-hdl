# 126 — Elevator Controller

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Advanced | `elevator_controller` | `src/request_register.v`, `src/door_timer.v`, `src/elevator_controller.v` | `tb/tb_elevator_controller.v` |

## 1. Objective

Build a simplified SCAN-algorithm elevator: a 4-state FSM over a small
datapath (current floor, direction, move/door timers) that services
multiple pending floor requests in the correct order instead of the
order they were pressed in.

## 2. What the Design Does

`elevator_controller` tracks a request bit per floor (`request_register`)
and moves one floor at a time (`MOVE_TIME` cycles per floor) toward the
nearest pending request in its current direction of travel. It keeps
moving that way, stopping at every pending floor along the route, until
no more requests remain ahead — only then does it reverse direction (the
standard elevator/disk-scheduling SCAN algorithm). At each stop it opens
the door (`door_timer`, `OPEN_TIME` cycles) and clears that floor's
request.

## 3. Why It Is Useful

This is the category's most complete example of a controller with a
genuinely stateful *dispatch policy* (not just a fixed sequence or a
single accumulator) driving a small datapath — closely related to the
same SCAN idea used for real disk/elevator scheduling, and a natural
capstone for everything category 07 built up to: multi-module hierarchy
(124), a datapath-influenced FSM (125), and now a policy that reacts
differently depending on the *set* of pending requests, not just the
next single event.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `request_in` | input | `FLOORS` | one-hot-or-more, one-cycle floor-request pulses |
| `current_floor` | output | `$clog2(FLOORS)` | current floor index |
| `moving_up`, `moving_down` | output | 1 each | direction of travel |
| `door_open` | output | 1 | door currently open |
| `pending_out` | output | `FLOORS` | current pending-request bitmap (observability) |

Parameters: `FLOORS` (4), `MOVE_TIME` (3, cycles/floor), `OPEN_TIME` (4,
cycles door stays open).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 2 | `S_IDLE`, `S_MOVE_UP`, `S_MOVE_DOWN`, `S_DOOR_OPEN` |
| `floor_r`, `floor_next` | `$clog2(FLOORS)` | current floor |
| `move_cnt` | `$clog2(MOVE_TIME+1)` | cycles elapsed traveling to the next floor |
| `direction_r` | 1 | last/current SCAN direction (1=up, 0=down) |
| `pending` | `FLOORS` | from `request_register` |
| `clear_mask`, `door_start` | `FLOORS`, 1 | pulsed to `request_register` / `door_timer` |

## 6. Architecture

```
                    pending[floor]?           timer done
   S_IDLE ────────────────────────► S_DOOR_OPEN ──────────► S_IDLE
     │  direction & has_above/below
     ├────────────► S_MOVE_UP ──arrive, more above──► (stays MOVE_UP)
     │                        └─arrive, none above───► S_IDLE
     └────────────► S_MOVE_DOWN (symmetric)
```
`has_above`/`has_below` (elaboration-time-unrolled `function`s over the
small `FLOORS`-bit `pending` vector) decide, at every floor arrival,
whether to keep going in the same direction, stop, or (from `S_IDLE`)
which direction to start in — the SCAN policy in its entirety.

## 7. Module Hierarchy and Connections

```
elevator_controller
├── request_register  (u_req)   -- request_in -> pending; clear_mask clears serviced floor
└── door_timer         (u_door)  -- door_start -> done (OPEN_TIME cycles later)
```

## 8. Verilog Concepts Used

* `function automatic` used for a genuine runtime (not just
  elaboration-time) combinational computation (`has_above`/`has_below`
  scan the pending vector every cycle), demonstrating functions as
  reusable combinational logic blocks, not only parameter-sizing helpers.
* A direction-persistent register (`direction_r`) used to implement a
  stateful *dispatch policy* — the next-state logic's decision depends
  on more than just the current state and a single input bit.
* Reused, independently-developed sub-modules (`request_register` from
  this program, a `door_timer` cousin of program 124's `timer`)
  integrated into a genuinely more complex controller.

## 9. Source Code Explanation

```verilog
end else if (direction_r && has_above(pending, floor_r)) begin
    state_next    = S_MOVE_UP;
    move_cnt_next = {CNT_W{1'b0}};
end else if (!direction_r && has_below(pending, floor_r)) begin
    ...
end else if (has_above(pending, floor_r)) begin
    state_next     = S_MOVE_UP;
    ...
    direction_next = 1'b1;      // direction actually SWITCHES here
end else if (has_below(pending, floor_r)) begin
    ...
    direction_next = 1'b0;
```
The four-way priority chain is the SCAN policy: first try to continue
the *current* direction if it still has requests ahead; only if it does
not does the machine consider switching (and only then does
`direction_next` actually change).

```verilog
if (move_cnt == MOVE_TIME[CNT_W-1:0] - 1'b1) begin
    floor_next    = floor_r + 1'b1;
    ...
    if (pending[floor_r + 1'b1]) begin
        state_next = S_DOOR_OPEN; ...
    end else if (has_above(pending, floor_r + 1'b1)) begin
        state_next = S_MOVE_UP;              // keep going
    end else begin
        state_next = S_IDLE;                 // nothing left ahead
    end
```
Every floor arrival re-evaluates the *next* floor's own pending bit
(stop here?) and the *remaining* floors further ahead (keep going?) —
this is what makes the elevator stop at every requested floor along its
route rather than only its originally-dispatched target.

## 10. Testbench Explanation

`tb_elevator_controller` drives the fully integrated design and checks
the *sequence* of floors the elevator stops at (via `wait_door_open`,
which polls with a 500-cycle watchdog) against the expected SCAN order,
rather than hand-computed absolute cycle counts — appropriate for a
multi-request dispatch policy where the interesting property is *order*,
not raw timing. Scenarios: (A) a single request from idle; (B) two
simultaneous requests while starting to move — visited in floor order,
not press order; (C) a request for an intermediate floor added *while
already moving* toward a farther one; (D) two requests below the current
(top) floor, forcing a SCAN direction reversal, visited in descending
order; (E) a request for the floor the elevator already occupies —
opens immediately, no movement. Door dwell time is also checked once
against `OPEN_TIME + 1` (see §13).

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | single request | press floor 2 from floor 0 | stops at floor 2 |
| 2 | simultaneous requests | press floors 1 and 3 together | visits 1, then 3 |
| 3 | mid-transit request | press 3, then 1 while still moving | visits 1, then 3 |
| 4 | direction reversal | from floor 3, press 2 and 0 | visits 2, then 0 (descending) |
| 5 | same-floor request | press the current floor while idle | opens immediately, no move |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 126` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_elevator_controller` — **PASS**

```text
TEST PASSED: 10 checks
tb/tb_elevator_controller.v:168: $finish called at 996000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 210 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Door dwell measured exactly `OPEN_TIME + 1` cycles, the same
  registered-sub-module-`done` latency documented in program 124 —
  confirmed empirically here again rather than assumed.
* Hall calls and cabin calls are unified into a single per-floor request
  bit — a deliberate simplification. A real elevator distinguishes
  "going up from floor 2" vs. "going down from floor 2" hall calls,
  which this model does not.
* `direction_r` resets to "up" (`1'b1`) so a freshly-reset elevator at
  floor 0 prefers moving up first, matching realistic ground-floor
  start-up behavior.

## 14. Common Mistakes

* Reversing direction as soon as the *current* direction has no request
  at the *immediately next* floor, instead of checking whether ANY
  request remains further ahead — this breaks the SCAN property and
  causes needless direction thrashing.
* Forgetting to re-check the *new* floor's pending bit using the
  look-ahead `floor_r + 1` / `floor_r - 1` value at the exact arrival
  edge — checking the *old* `floor_r` instead would stop the elevator
  one floor early or late every time.

## 15. Possible Improvements

* Separate up-hall-call and down-hall-call request bits per floor for a
  more realistic dispatch policy.
* Add a `door_obstruction`/re-open input, and cabin-vs-hall call
  prioritization.

## 16. What This Program Teaches

* Implementing the SCAN dispatch algorithm as RTL: a direction-persistent
  decision combined with look-ahead pending checks at every floor.
* Testing a *policy* (visit order under multiple simultaneous and
  mid-transit requests) rather than only a fixed timing sequence.
* Composing multiple previously-designed sub-module patterns (a request
  latch, a start/done timer) into one more complex controller.

## 17. Industry Relevance

SCAN and its variants are textbook disk-scheduling and real elevator
dispatch algorithms; the RTL structure here — a direction-persistent FSM
plus look-ahead over a small pending-request vector — is a direct,
simplified analog of real elevator group-control firmware.

## 18. How to Run

```bash
python3 scripts/run.py 126            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/126-elevator-controller && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_elevator_controller.v
vvp build/sim.vvp +vcd
```
