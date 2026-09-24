# 036 — 1-to-4 Demultiplexer

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 02-multiplexers-encoders-decoders | Beginner | `demux1to4` | `src/demux1to4.v` | `tb/tb_demux1to4.v` |

## 1. Objective

Implement the inverse of a multiplexer: route one data input to exactly one
of four outputs, chosen by a select code, with every other output held at a
known inactive value.

## 2. What the Design Does

`demux1to4` copies `d` onto the output selected by `sel` and drives the
other three outputs to zero:

| `sel` | `y0` | `y1` | `y2` | `y3` |
|---|---|---|---|---|
| `00` | `d` | 0 | 0 | 0 |
| `01` | 0 | `d` | 0 | 0 |
| `10` | 0 | 0 | `d` | 0 |
| `11` | 0 | 0 | 0 | `d` |

Whenever `d = 0`, all four outputs are 0 regardless of `sel`; whenever
`d = 1`, exactly one output is 1.

## 3. Why It Is Useful

Demultiplexers route a single source to one of several destinations:
distributing a shared data line to individual peripheral registers, driving
one-hot write-enable signals from a single "write" pulse plus an address,
or splitting a serial data path into parallel lanes for further processing.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `sel` | input | 2 | Chooses which output receives `d` |
| `d` | input | `WIDTH` | Data to route |
| `y0`..`y3` | output | `WIDTH` | Outputs; only the one selected by `sel` carries `d`, the rest are 0 |

Parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | 1 | Bus width of `d` and every output |

## 5. Internal Signals

None — every output is a direct function of the inputs.

## 6. Architecture

```
              ┌── (sel==00) ? d : 0 ──► y0
              │
 d ───────────┼── (sel==01) ? d : 0 ──► y1
              │
 sel ─────────┼── (sel==10) ? d : 0 ──► y2
              │
              └── (sel==11) ? d : 0 ──► y3
```

Four independent comparators against `sel`, each gating the shared `d` onto
one output; there is no shared internal state.

## 7. Module Hierarchy and Connections

```
tb_demux1to4
├── dut1 : demux1to4 #(.WIDTH(1))
└── dut4 : demux1to4 #(.WIDTH(4))
```

The testbench instantiates two width configurations of the same module and
checks each independently.

## 8. Verilog Concepts Used

* Four independent `assign` statements sharing the same select logic — the
  mirror image of a mux's single output selected from several inputs.
* Equality comparison (`==`) against a 2-bit literal to build each output's
  enable condition.
* Bit concatenation (`{y0,y1,y2,y3}`) in the testbench to compare all four
  outputs against the expected pattern in one comparison.

## 9. Source Code Explanation

```verilog
assign y0 = (sel == 2'b00) ? d : {WIDTH{1'b0}};
assign y1 = (sel == 2'b01) ? d : {WIDTH{1'b0}};
assign y2 = (sel == 2'b10) ? d : {WIDTH{1'b0}};
assign y3 = (sel == 2'b11) ? d : {WIDTH{1'b0}};
```

* Each output has its own ternary: if `sel` matches that output's code, `d`
  passes through; otherwise the output is forced to `{WIDTH{1'b0}}` (a
  properly-sized zero, so `WIDTH` can be anything without a width mismatch
  warning).
* Because the four conditions (`sel==00/01/10/11`) are mutually exclusive
  and collectively exhaustive over all values of `sel`, exactly one output
  equals `d` and the other three are 0 for every `sel`, with no shared
  state needed between the four `assign`s.

## 10. Testbench Explanation

`tb_demux1to4` instantiates two configurations, both tested exhaustively
since the input space is small:

1. `dut1` (`WIDTH=1`): `{sel, d}` is swept over all 8 combinations; the
   bench computes the four expected outputs independently and compares
   them as one concatenated 4-bit value. It additionally checks the
   "exactly one active output" invariant whenever `d = 1`.
2. `dut4` (`WIDTH=4`): `{sel, d}` is swept over all 64 combinations
   (4 `sel` values x 16 `d` values), checking the full 4-bit data path on
   every output.

Every check increments `checks`; a mismatch increments `errors` and prints
an `ERROR:` line with time, inputs, expected and actual values. The final
line is `TEST PASSED: 72 checks` (8 + 64) or a `TEST FAILED` summary.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | Exhaustive `WIDTH=1` | `{sel,d}` = 0..7 | Matches the truth table; exactly one output set when `d=1` |
| 2 | Exhaustive `WIDTH=4` | `{sel,d}` = 0..63 | Selected output equals `d`, the other three are 0 |

All 8 states of the `WIDTH=1` instance and all 64 states of the `WIDTH=4`
instance (100% of both input spaces) are exercised.

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 036` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_demux1to4` — **PASS**

```text
WIDTH=1 exhaustive:
sel d | y0 y1 y2 y3
 00   0  |  0  0  0  0
 00   1  |  1  0  0  0
 01   0  |  0  0  0  0
 01   1  |  0  1  0  0
 10   0  |  0  0  0  0
 10   1  |  0  0  1  0
 11   0  |  0  0  0  0
 11   1  |  0  0  0  1
WIDTH=4 exhaustive (64 combinations):
done: 72 checks
TEST PASSED: 72 checks
tb/tb_demux1to4.v:79: $finish called at 72000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 8 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* Driving the unselected outputs to 0 (rather than leaving them undriven or
  `x`) gives downstream logic a well-defined idle value, which matters if
  any output feeds an OR-reduction or an accumulator that assumes 0 when
  inactive.
* At `WIDTH=1`, Yosys generic synthesis maps this to 8 cells (4 outputs x
  ~2 gates each for the equality-compare-and-gate); there is no timing or
  area concern at this scale.
* No reset or clock is needed — this remains pure combinational logic.

## 14. Common Mistakes

* Leaving unselected outputs undriven (e.g. only assigning inside an `if`
  without an `else`) — in an `always` block this would infer a latch; the
  `assign`/ternary style used here avoids the issue by construction.
* Confusing a demux with a decoder: a decoder (program 038) produces
  one-hot outputs from `sel` alone, while a demux additionally gates a data
  input through the selected output.

## 15. Possible Improvements

* Add an active-low or tri-state output variant to match real bus demux
  parts (74138-style enables).
* Generalize `sel` width and output count together as one parameter (the
  demux equivalent of program 035's `mux_n`, covered in program 037).

## 16. What This Program Teaches

* The demultiplexer as the structural inverse of a multiplexer.
* Building N independent, mutually-exclusive enable conditions from one
  select signal.
* Checking a multi-output invariant ("exactly one output active") in
  addition to per-output correctness.

## 17. Industry Relevance

Demultiplexed enables are how a single shared control or data line reaches
many destinations selectively — write-enable fan-out to register banks,
chip-select generation, and one-hot control signal generation in FSMs all
use this exact structure.

## 18. How to Run

```bash
python3 scripts/run.py 036            # compile, simulate, synthesize, lint
cd 02-multiplexers-encoders-decoders/036-demux-1to4 && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/demux1to4.v tb/tb_demux1to4.v
vvp build/sim.vvp +vcd
```
