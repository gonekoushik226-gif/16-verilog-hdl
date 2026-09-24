# 119 — Mealy Sequence Detector

<!-- STATUS:BEGIN -->
**Status:** SIMULATION VERIFIED · SYNTHESIS VERIFIED (Yosys generic synthesis) · FPGA hardware: not tested
<!-- STATUS:END -->

| Category | Difficulty | Top module | Source files | Testbench |
|---|---|---|---|---|
| 07-finite-state-machines | Elementary | `seq_detector_mealy` | `src/seq_detector_mealy.v` | `tb/tb_seq_detector_mealy.v` |

## 1. Objective

Re-implement program 118's `1011` sequence detector as a Mealy machine
and show, on the same test streams, exactly how its output timing
differs from the Moore version.

## 2. What the Design Does

`seq_detector_mealy` scans a serial bit stream and asserts `detected`
combinationally on the very input bit that completes a `1011` match —
it does not wait for that bit to be clocked into a dedicated "matched"
state first. Overlapping matches are found, exactly as in program 118.

## 3. Why It Is Useful

Mealy machines react one cycle sooner than an equivalent Moore machine,
which matters when the detected condition must gate something in the
same cycle (e.g. an immediate downstream enable). The cost is that the
output is a combinational function of the input, so it can glitch if the
input is not glitch-free, and it needs careful static timing closure in
real designs.

## 4. Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | clock |
| `rst_n` | input | 1 | asynchronous active-low reset |
| `in_bit` | input | 1 | serial input bit |
| `detected` | output | 1 | Mealy output, combinational function of `(state, in_bit)` |

## 5. Internal Signals

| Signal | Width | Purpose |
|---|---|---|
| `state`, `state_next` | 2 | current / next FSM state (`S0`..`S3`) |

## 6. Architecture

```
S0 --1--> S1 --0--> S2 --1--> S3
 ^0        |1  ^--0--'         |0  '--> S2
 '---------'                   |1(out=1)--> S1
```
Only 4 states are needed (vs. 5 for the Moore version in 118): the match
condition is signalled on the `S3 --1--> S1` transition itself
(`detected = (state==S3) && in_bit`), rather than requiring a dedicated
"matched" state to be reached first.

## 7. Module Hierarchy and Connections

Single module, no instances.

## 8. Verilog Concepts Used

* Mealy-style output: a combinational function of both `state` and
  `in_bit`, contrasted directly against program 118's Moore output
  (function of `state` only).
* Same longest-matched-prefix next-state derivation as 118, showing that
  the state-transition graph structure is independent of the Moore/Mealy
  output choice — only how (and when) the output is computed differs.

## 9. Source Code Explanation

```verilog
always @(*) begin
    detected = (state == S3) && in_bit;
end
```
This is the entire behavioral difference from program 118: instead of
transitioning into a 5th state whose *identity* signals a match, the
4-state machine signals the match directly on the qualifying transition.
`state == S3` means "101" has just been matched; combined with
`in_bit == 1` in the same cycle, the full "1011" pattern is complete
*this* cycle, one cycle before `state` would even update to reflect it.

```verilog
S3: state_next = in_bit ? S1 : S2;
```
After signalling the match, the next state folds back to `S1` ("011"+1
-> longest matching suffix is "1") exactly as program 118's `S4` did —
overlap detection works the same way, just without a distinct
post-match state.

## 10. Testbench Explanation

Identical directed/random test streams to program 118 (isolated match,
back-to-back overlapping matches, reset-clears-partial-match, never-match
all-0/all-1, and four pseudo-random 60-bit streams), but `feed_bit`
samples `detected` combinationally right after the new input settles —
on a falling clock edge, before the following rising edge registers the
transition — matching the Mealy output's earlier timing. The reference
model is the same simple "last 4 bits equal 1011" check used in 118.

## 11. Test Cases and Expected Results

| # | Test | Stimulus | Expected result |
|---|---|---|---|
| 1 | isolated match | `0010110...` | `detected` pulses once |
| 2 | overlapping matches | `1011011011` | `detected` pulses 3 times |
| 3 | reset clears partial match | `101` then reset then `1` | no false detect |
| 4 | never matches | all-0 / all-1, 20 bits each | `detected` stays low |
| 5 | random streams | 4×60 pseudo-random bits | matches reference model exactly |

## 12. Actual Simulation Results

<!-- SIM-RESULTS:BEGIN -->
Command: `python3 scripts/run.py 119` (Icarus Verilog 12.0, `iverilog -g2005 -Wall`)

Testbench `tb_seq_detector_mealy` — **PASS**

```text
TEST PASSED: 310 checks
tb/tb_seq_detector_mealy.v:107: $finish called at 3305000 (1ps)
```

Synthesis (Yosys 0.33, generic `synth`): **PASS**, 14 cells
Lint (Verilator 5.020 `--lint-only`): **clean**
<!-- SIM-RESULTS:END -->

## 13. Design Considerations

* One fewer state than the Moore version (4 vs. 5) is a direct,
  demonstrable consequence of folding the "matched" signal into a
  transition instead of a state — smaller state register, same behavior.
* Because `detected` depends combinationally on `in_bit`, any glitch on
  `in_bit` before it is safely registered elsewhere can produce a glitch
  on `detected`; real designs typically register a Mealy output before
  using it downstream if glitch-free timing is required.

## 14. Common Mistakes

* Believing Mealy and Moore machines for the same pattern always need
  the same number of states — here Mealy needs one fewer because the
  match doesn't require its own state.
* Sampling a Mealy output at the wrong point in the clock cycle in a
  testbench (e.g. only after the following posedge) silently turns the
  comparison into a Moore-style check and hides real timing differences.

## 15. Possible Improvements

* Register `detected` with one extra flip-flop if a glitch-free,
  Moore-like timing is later required from this Mealy core.
* Parameterize the target pattern instead of hard-coding `1011`.

## 16. What This Program Teaches

* The practical difference between Moore and Mealy machine outputs:
  timing (one cycle earlier for Mealy) and state count (Mealy can need
  fewer states for the same recognized language).
* How to test a Mealy design's combinational output correctly against a
  reference model, sampling it at the right point in the clock cycle.

## 17. Industry Relevance

Mealy machines are common wherever an immediate combinational reaction to
an input is required — bus protocol decoders that must assert a ready/ack
signal in the same cycle a qualifying condition appears, for example —
traded off against the glitch and timing-closure considerations noted
above.

## 18. How to Run

```bash
python3 scripts/run.py 119            # compile, simulate, synthesize, lint
cd 07-finite-state-machines/119-mealy-sequence-detector && mkdir -p build
iverilog -g2005 -Wall -o build/sim.vvp src/seq_detector_mealy.v tb/tb_seq_detector_mealy.v
vvp build/sim.vvp +vcd
```
