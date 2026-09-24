# 129 — Parking Lot Counter

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `parking_lot` | `src/car_direction_fsm.v`, `src/parking_lot.v` | `tb/tb_parking_lot.v` |

## 1. Objective

Build the classic two-beam-sensor direction detector: determine whether
a car is entering or exiting purely from the *order* two adjacent
sensors trigger, correctly handling a car that triggers one sensor and
then backs away without completing the crossing.

## 2. What the Design Does

`car_direction_fsm` watches `sensor_a` (outer/entrance side) and
`sensor_b` (inner/lot side). A car entering breaks `A`, then both
sensors (its body spans them), then `B` alone (as it clears `A`), then
neither — a `entry_pulse` fires the cycle both clear. A car exiting does
the mirror sequence (`B`, both, `A` alone, neither), firing
`exit_pulse`. A car that triggers only one sensor and withdraws without
ever reaching "both active" is an **aborted pass**: the FSM falls back
to idle and neither pulse fires. `parking_lot` wraps this with a
saturating occupancy counter and a `full` flag.

## 3. Why It Is Useful

Inferring direction from sensor firing order (rather than needing a
single, more expensive directional sensor) is a real, widely-used
technique — automatic doors, conveyor counters, and parking gates all
commonly use this exact two-beam trick. Correctly rejecting an aborted
pass (someone stepping on one sensor and stepping back) is the part
naive implementations often get wrong.

## 4. Interface

**`parking_lot`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `sensor_a`, `sensor_b` | input | 1 each | beam sensors, entrance/lot side |
| `occupancy` | output | `WIDTH` | current car count, saturating at `CAPACITY` |
| `full` | output | 1 | `occupancy >= CAPACITY` |

Parameters: `CAPACITY` (4), `WIDTH` (3, must fit `CAPACITY`).

**`car_direction_fsm`**: `clk`, `rst_n`, `sensor_a`, `sensor_b` (in);
`entry_pulse`, `exit_pulse` (out, one-cycle registered pulses).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state` (in `car_direction_fsm`) | 3 | `S_IDLE`, `S_A_START`, `S_B_START`, `S_BOTH_A`, `S_B_END_A`, `S_BOTH_B`, `S_A_END_B` |
| `occ` (in `parking_lot`) | `WIDTH` | current occupancy register |

## 6. Architecture

```
Entering: S_IDLE --a--> S_A_START --a&b--> S_BOTH_A --b only--> S_B_END_A --neither--> S_IDLE (entry_pulse)
Exiting:  S_IDLE --b--> S_B_START --a&b--> S_BOTH_B --a only--> S_A_END_B --neither--> S_IDLE (exit_pulse)
Aborted:  S_A_START --a withdraws before both--> S_IDLE (no pulse)
          S_B_START --b withdraws before both--> S_IDLE (no pulse)
```
Any sensor combination that does not match the expected next step of
either sequence falls back safely to `S_IDLE` without pulsing — a
deliberate simplification documented in §13.

## 7. Module Hierarchy and Connections

```
parking_lot
└── car_direction_fsm (u_fsm) -- entry_pulse/exit_pulse drive the occupancy counter
```

## 8. Verilog Concepts Used

* A 7-state FSM where state identity alone encodes *both* "how far
  through the crossing" and "which direction" — `S_B_END_A` and
  `S_A_END_B` look similar (one sensor active) but mean opposite things
  depending on which state led there, which is exactly why they must be
  distinct states rather than collapsed into one "one sensor active"
  state.
* A single combined `always @(posedge clk or negedge rst_n)` block for
  both state transitions and registered pulse outputs — the same style
  already used for this repository's timer-family modules
  (`timer`/`door_timer`/`phase_timer`), applied here to a genuine event
  detector instead of a counter.
* A saturating up/down counter (`parking_lot.occ`), guarding both
  overflow (entry while already at `CAPACITY`) and underflow (exit while
  already at 0).

## 9. Source Code Explanation

```verilog
S_BOTH_A: begin
    if (!sensor_a && sensor_b)      state <= S_B_END_A;  // normal progress
    else if (sensor_a && !sensor_b) state <= S_IDLE;      // abnormal: fall back safely
    else if (!sensor_a && !sensor_b) state <= S_IDLE;     // both cleared at once (glitch)
end
```
From "both active, arrived via A first," only `A` clearing while `B`
stays active is the expected next step of an entry; anything else
(sensors clearing in the wrong order, or simultaneously) is treated as
an abnormal event and safely discarded rather than guessed at — see
§13 for why.

```verilog
S_B_END_A: begin
    if (!sensor_a && !sensor_b) begin
        state       <= S_IDLE;
        entry_pulse <= 1'b1;                      // entry confirmed
    end else if (sensor_a && sensor_b) begin
        state <= S_BOTH_A;
    end
```
`entry_pulse` fires only once the car has cleared *both* sensors after
passing through in the correct order — the complete, unambiguous
signature of a finished entry, not merely "B was triggered second."

```verilog
end else if (entry_pulse && !exit_pulse) begin
    if (occ < CAPACITY[WIDTH-1:0]) occ <= occ + 1'b1;
end else if (exit_pulse && !entry_pulse) begin
    if (occ > {WIDTH{1'b0}}) occ <= occ - 1'b1;
end
```
Both directions are guarded independently — an entry while already at
`CAPACITY` is silently absorbed (occupancy cannot be trusted to exceed
the physical lot's capacity), and an exit while already at 0 cannot
underflow.

## 10. Testbench Explanation

`tb_parking_lot` drives the INTEGRATED design with realistic sensor
sequences via `do_entry`/`do_exit` (four-step clean crossings) and
`do_abort_a`/`do_abort_b` (one sensor triggers and withdraws), checking
`occupancy` and `full` after each event. Coverage: filling to
`CAPACITY` one clean entry at a time; one more entry while already full
(saturates, does not overflow); aborted passes on both sensors while
full and mid-occupancy (no change either time); draining fully to
empty; one more exit while already empty (does not underflow); and a
final mixed sequence interleaving entries, exits, and aborts.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | fill to capacity | `CAPACITY` clean entries | `occupancy` increments each time, `full` asserts at `CAPACITY` |
| 2 | overflow guard | one more entry while full | `occupancy` stays at `CAPACITY` |
| 3 | aborted passes | one-sensor-only, withdraw | `occupancy` unchanged |
| 4 | drain to empty | `CAPACITY` clean exits | `occupancy` decrements each time |
| 5 | underflow guard | one more exit while empty | `occupancy` stays 0 |
| 6 | mixed sequence | entries/exits/aborts interleaved | `occupancy` matches at every step |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 129` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_parking_lot` — **PASS**

```text
TEST PASSED: 42 checks
tb/tb_parking_lot.v:157: $finish called at 846000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 121 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Any sensor transition that does not match the expected next step of
  an in-progress crossing (e.g. both sensors clearing simultaneously, or
  the "wrong" sensor clearing first) falls back to `S_IDLE` without
  counting anything, rather than attempting to guess intent. This is a
  deliberate, safety-conservative simplification: it can occasionally
  fail to count a genuinely unusual crossing, but it can never
  miscount a car's direction.
* `occupancy` increments/decrements one cycle *after* `entry_pulse`/
  `exit_pulse` first appear (they are registered outputs of the
  sub-module, consumed synchronously by the counter's own register) —
  the testbench's `do_entry`/`do_exit` tasks include the extra cycle of
  settling time this requires.

## 14. Common Mistakes

* Collapsing `S_B_END_A` and `S_A_END_B` into a single "one sensor
  active" state — they represent opposite directions and must remain
  distinct, even though only one sensor is active in either case.
* Not guarding the occupancy counter against overflow/underflow —
  without the `occ < CAPACITY` / `occ > 0` guards, a car entering an
  already-full lot (or an extra exit pulse from a sensor glitch) would
  wrap the counter to a nonsensical value.

## 15. Possible Improvements

* Add a `gate_open` output that only permits entry while `!full`, tying
  the counter back into physical access control.
* Log aborted-pass events on a separate output for diagnostics, instead
  of silently discarding them.

## 16. What This Program Teaches

* Inferring event direction purely from sensor firing order, a common
  real embedded-sensing technique.
* Correctly rejecting an incomplete/aborted event sequence instead of
  only handling the "happy path."
* Saturating counter design (both overflow and underflow guards).

## 17. Industry Relevance

Two-beam direction sensing appears in automatic doors, people/vehicle
counters, conveyor systems, and parking gate controllers; the
saturating-counter-plus-full-flag pattern is standard in any
capacity-tracking peripheral.

## 18. How to Run

```bash
python3 scripts/run.py 129            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/129-parking-lot-counter && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_parking_lot.v
vvp build/sim.vvp +vcd
```
