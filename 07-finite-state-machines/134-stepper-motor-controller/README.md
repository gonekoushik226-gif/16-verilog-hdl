# 134 — Stepper Motor Controller

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Intermediate | `stepper_controller` | `src/stepper_controller.v` | `tb/tb_stepper_controller.v` |

## 1. Objective

Drive a 4-coil stepper motor through its standard 8-position sequence
table, supporting full-step and half-step modes, both directions, and a
runtime-independent speed divider — closing out category 07 with a
sequencer whose "state" is directly physical (coil energization
patterns) rather than abstract.

## 2. What the Design Does

`stepper_controller` steps through an 8-entry half-step sequence table
using a 3-bit index. In half-step mode the index advances by 1 each
step (visiting all 8 table entries); in full-step mode it advances by 2
(visiting only the table's 4 single-coil-energized entries). `dir`
selects increment or decrement. A `SPEED_DIV`-cycle prescaler paces how
often a step actually advances. `enable=0` holds the current coil
pattern and keeps the prescaler at 0, so re-enabling always starts a
fresh full `SPEED_DIV`-cycle period before the next step.

## 3. Why It Is Useful

Stepper motor sequencing is a common real embedded-systems task, and
this program shows a specific, reusable design trick: encoding both
full-step and half-step modes as different *strides* through the same
table, instead of maintaining two separate sequence tables.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | input | 1 each | clock, asynchronous active-low reset |
| `enable` | input | 1 | motor stepping enabled; `0` holds the current coil pattern |
| `dir` | input | 1 | `1`=forward (increment), `0`=reverse (decrement) |
| `half_step` | input | 1 | `1`=8-position half-step, `0`=4-position full-step |
| `coil` | output | 4 | current coil energization pattern |

Parameters: `SPEED_DIV` (4, clock cycles between successive steps).

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `presc_cnt` | `$clog2(SPEED_DIV)` | prescaler counting toward the next step |
| `idx` | 3 | current position in the 8-entry sequence table |

## 6. Architecture

```
Table (idx -> coil):
0:1000  1:1100  2:0100  3:0110  4:0010  5:0011  6:0001  7:1001  (wraps to 0)

half_step=1: idx <= dir ? idx+1 : idx-1   (visits all 8 entries)
half_step=0: idx <= dir ? idx+2 : idx-2   (visits only 0,2,4,6 -- single-coil entries)
```
3-bit wraparound arithmetic (`idx-1` at `idx=0` naturally becomes `7`)
handles both directions and both strides with no explicit modulo logic.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* A single lookup table walked at two different strides to implement two
  related sequencing modes, instead of duplicating the table.
* Natural unsigned wraparound arithmetic on a 3-bit index for
  cyclic forward/reverse stepping in both stride modes.
* An `enable`-gated prescaler that resets (not merely pauses) while
  disabled, so re-enabling always begins a fresh, full-length step
  period rather than resuming a partially-elapsed one.

## 9. Source Code Explanation

```verilog
if (half_step) idx <= dir ? (idx + 3'd1) : (idx - 3'd1);
else           idx <= dir ? (idx + 3'd2) : (idx - 3'd2);
```
The entire mode/direction logic is these two lines. Because the table's
4 single-coil entries sit at every other index (0, 2, 4, 6), striding by
2 automatically skips the two-coil "half-step" entries without needing
a second table or an explicit index remap.

```verilog
end else if (!enable) begin
    presc_cnt <= {PRESC_W{1'b0}};
```
Resetting (not freezing) the prescaler while disabled is a deliberate
choice: a stepper that has been idle for an arbitrary time should not
"remember" a partial period and step almost immediately upon
re-enabling — each enable starts a clean `SPEED_DIV`-cycle wait.

## 10. Testbench Explanation

`tb_stepper_controller` resets before each mode/direction scenario (so
the sequence always starts deterministically at `idx=0`), then
`collect`s every *distinct* coil value seen over a run, along with the
cycle index of each change. `check_sequence` compares the resulting
list against the expected full-step/half-step, forward/reverse pattern
**and** checks that every step is held for exactly `SPEED_DIV` cycles
before advancing. A final scenario disables the motor mid-sequence and
confirms the coil pattern is held completely stable for several
`SPEED_DIV` periods.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | full-step forward | `dir=1, half_step=0` | `1000,0100,0010,0001,1000` |
| 2 | full-step reverse | `dir=0, half_step=0` | `1000,0001,0010,0100,1000` |
| 3 | half-step forward | `dir=1, half_step=1` | all 8 table entries, in order |
| 4 | half-step reverse | `dir=0, half_step=1` | all 8 table entries, reverse order |
| 5 | disable holds pattern | `enable=0` mid-sequence | `coil` unchanged for `3*SPEED_DIV` cycles |

Every scenario's step spacing is also checked to be exactly `SPEED_DIV`
cycles.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 134` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_stepper_controller` — **PASS**

```text
TEST PASSED: 68 checks
tb/tb_stepper_controller.v:141: $finish called at 1456000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 34 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Full-step mode here always uses the *single-coil* entries (more
  common for lower power draw); the alternative "two-coil full step"
  (more torque) would instead stride through indices 1, 3, 5, 7 starting
  from a different table offset — a straightforward variant not
  implemented here.
* `SPEED_DIV` is a compile-time parameter; program 117's runtime-
  reconfigurable `prescaler` shows the pattern for making step rate
  adjustable at runtime instead, if needed.

## 14. Common Mistakes

* Using two separate lookup tables for full-step and half-step modes
  instead of one table walked at different strides — works, but
  duplicates state that must be kept consistent by hand if the sequence
  is ever revised.
* Freezing (rather than resetting) the prescaler while `enable` is low —
  this can cause a much shorter-than-`SPEED_DIV` step immediately after
  re-enabling, since the count resumes from wherever it happened to
  stop instead of a fresh period.

## 15. Possible Improvements

* Add microstepping (PWM-modulated intermediate coil currents) as a
  further mode beyond half-step.
* Add a `step_count` output for closed-loop position tracking.

## 16. What This Program Teaches

* Encoding related sequencing modes as different strides through one
  table.
* Cyclic index arithmetic using natural register wraparound.
* An enable-gated prescaler design choice (reset vs. freeze) and its
  concrete behavioral consequence.

## 17. Industry Relevance

Table-driven coil sequencing with a speed-controlling prescaler is
exactly how real stepper motor driver ICs and microcontroller firmware
implement full/half/micro-stepping — this program's single-table,
variable-stride technique is a direct, practical simplification real
drivers use.

## 18. How to Run

```bash
python3 scripts/run.py 134            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/134-stepper-motor-controller && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/stepper_controller.v tb/tb_stepper_controller.v
vvp build/sim.vvp +vcd
```
