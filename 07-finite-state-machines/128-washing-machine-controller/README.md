# 128 — Washing Machine Controller

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `washing_machine` | `src/phase_timer.v`, `src/washing_machine.v` | `tb/tb_washing_machine.v` |

## 1. Objective

Build a fixed-sequence, timed phase controller (FILL -> WASH -> RINSE ->
SPIN -> DONE) with two safety-relevant controls beyond program 123's
plain timed sequencing: a **pause** input that suspends the active
phase's timer without losing progress, and a **cancel** input that
aborts the whole cycle immediately.

## 2. What the Design Does

`washing_machine` advances through its five phases automatically, timed
by a single shared `phase_timer` whose duration is re-selected for
whichever phase is current. While `lid_open` is asserted, the active
phase's timer freezes (neither advancing nor completing) until the lid
closes again — no elapsed pause time is lost or double-counted. Asserting
`cancel` during any running phase returns immediately to `S_IDLE`. From
`S_DONE`, pressing `start` again begins a fresh cycle.

## 3. Why It Is Useful

Pause-without-losing-progress is a genuinely different requirement from
simply stopping a counter — the design must distinguish "not counting
because idle" from "not counting because safely suspended mid-phase,"
and resume from exactly where it left off. This exact requirement (a
safety interlock suspending, not resetting, an in-progress timed
operation) recurs in real industrial and appliance controllers far
beyond washing machines.

## 4. Interface

**`washing_machine`** (top level):

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `start` | input | 1 | begin a cycle from `IDLE`, or a new one from `DONE` |
| `cancel` | input | 1 | abort the current cycle back to `IDLE` |
| `lid_open` | input | 1 | pauses the active phase's timer while asserted |
| `filling`, `washing`, `rinsing`, `spinning`, `done_light`, `idle` | output | 1 each | current phase (mutually exclusive) |

Parameters: `WIDTH` (8), `FILL_TIME` (4), `WASH_TIME` (8), `RINSE_TIME`
(5), `SPIN_TIME` (6) — all in clock cycles.

**`phase_timer`**: `clk`, `rst_n`, `start`, `pause` (in), `duration[WIDTH-1:0]`
(in), `done` (out, one-cycle registered pulse).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 3 | `S_IDLE`, `S_FILL`, `S_WASH`, `S_RINSE`, `S_SPIN`, `S_DONE` |
| `timer_duration` | `WIDTH` | duration fed to `phase_timer`, selected by `state_next` |
| `cnt`, `running` (in `phase_timer`) | `WIDTH`, 1 | elapsed count / counting-in-progress flag |

## 6. Architecture

```
S_IDLE --start--> S_FILL --done--> S_WASH --done--> S_RINSE --done--> S_SPIN --done--> S_DONE --start--> S_FILL ...
                     |                |                 |                |
                     '--- cancel ---- '--- cancel -------'--- cancel -----'---------> S_IDLE
```
`phase_timer.pause = lid_open` unconditionally — harmless when the timer
is not running, and freezing exactly the active phase when it is.

## 7. Module Hierarchy and Connections

```
washing_machine
└── phase_timer  (u_timer) -- start = (state_next != state) && is_timed_next
                               pause = lid_open
                               duration = f(state_next)
```

## 8. Verilog Concepts Used

* A single shared timer sub-module reused across four different phases
  by re-selecting its `duration` combinationally from `state_next` —
  the same start/duration/done handshake pattern established in
  programs 124 and 126, now extended with a `pause` input.
* `pause`, unlike `start`, only takes effect while the timer is actively
  `running` — the sub-module's own guard (`running && !pause`) keeps
  pause from having any effect on an idle timer, so the controller does
  not need to gate it itself.

## 9. Source Code Explanation

```verilog
end else if (running && !pause) begin
    if (cnt == duration - 1'b1) begin
        done    <= 1'b1;
        running <= 1'b0;
    end else begin
        cnt <= cnt + 1'b1;
    end
end
// running && pause: hold cnt and running unchanged (frozen)
```
The critical property is what happens when `pause` is asserted: neither
branch of the `if` executes, so `cnt` (and `running`, and `done`, via
the unconditional `done <= 1'b0` at the top of the block) simply hold
their values across every paused cycle — genuinely frozen, not merely
"still counting but ignored."

```verilog
wire is_timed_next = (state_next == S_FILL)  || (state_next == S_WASH)
                   || (state_next == S_RINSE) || (state_next == S_SPIN);
```
Guards `timer.start` so it only pulses when actually entering a timed
phase — `S_IDLE` and `S_DONE` need no timer at all, and this keeps the
"start on transition" trick from programs 124/126 correct here too.

## 10. Testbench Explanation

`tb_washing_machine` runs a full cycle and checks each timed phase's
exact dwell (`TIME + 1` cycles, the same registered-timer latency
documented in programs 124/126), with one deliberate exception: during
`WASH`, `lid_open` is asserted for 5 cycles partway through, and the
test asserts the **total** `WASH` dwell equals `WASH_TIME + 1 + 5` —
proving the paused cycles are added on top, not merely tolerated. A
separate scenario asserts `cancel` mid-`SPIN` and checks the immediate
return to `IDLE`, followed by a fresh `start` confirming the machine is
still fully functional afterward. A final scenario runs a complete cycle
through `DONE` and confirms `start` from `DONE` begins a new cycle.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | FILL dwell | full cycle, no pause | exactly `FILL_TIME+1` cycles |
| 2 | WASH dwell with pause | 5-cycle `lid_open` mid-WASH | exactly `WASH_TIME+1+5` cycles |
| 3 | RINSE dwell | no pause | exactly `RINSE_TIME+1` cycles |
| 4 | cancel mid-SPIN | `cancel` pulse | immediate `IDLE` |
| 5 | restart after cancel | `start` from `IDLE` | begins a fresh cycle |
| 6 | full cycle to DONE, then restart | complete cycle, then `start` | `done_light` asserted, then a new `FILL` |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 128` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_washing_machine` — **PASS**

```text
TEST PASSED: 61 checks
tb/tb_washing_machine.v:177: $finish called at 616000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 168 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* The input port is named `cancel`, not `abort` — an earlier draft used
  `abort`, which Verilator flags (`SYMRSVDWORD`) as colliding with the
  C++ standard library's `abort()` function name in its generated model;
  renaming avoided the warning entirely rather than adding another
  accepted exception (see §14).
* `cancel` does not drain water or otherwise model physical
  consequences — it is a pure FSM-level abort, appropriate for this
  program's control-logic focus.

## 14. Common Mistakes

* **A genuine testbench measurement bug found during development:** an
  early version called `wait_until_phase(1, elapsed)` (wait for `FILL`)
  immediately after `pulse_start`, even though the state was *already*
  `FILL` at that exact instant (the `start` pulse's own clock edge is
  the `IDLE`->`FILL` transition edge). Because the wait loop always
  advances one clock edge *before* checking, this redundant call
  silently consumed one extra cycle waiting on a condition already
  true, shifting the start point of every subsequent elapsed-cycle
  measurement by one and producing a spurious `FILL dwell` mismatch.
  Fixed by starting the measurement immediately after `pulse_start`
  returns, with no intervening wait for a state already reached —
  documented in the testbench as a caution for any future scenario
  written the same way.
* **A genuine identifier-naming pitfall:** naming a signal `abort`
  triggers a real Verilator lint warning because it shadows a C++
  standard-library symbol in generated code; renaming the signal is
  simpler and more robust than suppressing the warning.

## 15. Possible Improvements

* Model water-level and temperature sensors feeding into the `FILL`/
  `WASH` phase transitions instead of pure elapsed-time timers.
* Add a `paused` status output so external displays can distinguish "no
  progress because paused" from "no progress because idle."

## 16. What This Program Teaches

* Implementing pause-without-losing-progress correctly: freezing every
  relevant piece of state, not just gating the visible output.
* Reusing one timer sub-module across several sequential phases via a
  combinationally re-selected duration.
* Diagnosing a subtle testbench off-by-one caused by an unnecessary
  wait on an already-satisfied condition — and why "wait, then check"
  loops must have their very first call's starting point reasoned about
  explicitly.

## 17. Industry Relevance

Pause/resume-in-place semantics for a timed operation, plus an immediate
abort path, are standard requirements in real appliance and industrial
sequencers (washing machines, dishwashers, process control steps) —
almost always tied to a physical safety interlock exactly like this
program's `lid_open`.

## 18. How to Run

```bash
python3 scripts/run.py 128            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/128-washing-machine-controller && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/*.v tb/tb_washing_machine.v
vvp build/sim.vvp +vcd
```
